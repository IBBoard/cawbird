/*  This file is part of Cawbird, a Gtk+ linux Twitter client forked from Corebird.
 *  Copyright (C) 2016 Timm Bäder (Corebird)
 *
 *  Cawbird is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  Cawbird is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with cawbird.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "CbMediaDownloader.h"
#include <libsoup/soup.h>
#include <oauth.h>
#include <gdk/gdk.h>
#include <string.h>

G_DEFINE_TYPE (CbMediaDownloader, cb_media_downloader, G_TYPE_OBJECT);

typedef struct {
  CbMedia *media;
  SoupSession *soup_session;
} LoadingData;

static void
loading_data_free (LoadingData *data)
{
  g_object_unref (data->media);
  g_object_unref (data->soup_session);
  g_free (data);
}

CbMediaDownloader *
cb_media_downloader_get_default (void)
{
  static CbMediaDownloader *d = NULL;

  if (G_UNLIKELY (d == NULL))
    {
      d = CB_MEDIA_DOWNLOADER (g_object_new (CB_TYPE_MEDIA_DOWNLOADER, NULL));
    }

  return d;
}

static void
mark_invalid (CbMedia *media)
{
  media->invalid = TRUE;
  media->loaded  = TRUE;
  media->loading = FALSE;
  media->loaded_hires = TRUE;
  media->loading_hires = FALSE;
  cb_media_loading_finished (media);
  cb_media_loading_hires_finished (media);
}

static const char *
canonicalize_url (const char *url)
{
  int ret = 0;

  if (g_str_has_prefix (url,"http://"))
    ret += 7;
  else if (g_str_has_prefix (url, "https://"))
    ret += 8;

  if (g_str_has_prefix(url + ret, "www."))
    ret += 4;

  return url + ret;
}

static void
load_animation (GInputStream *input_stream,
                cairo_surface_t **target_surface,
                GdkPixbufAnimation **target_animation,
                GCancellable *cancellable,
                GError **error)
{
  GdkPixbufAnimation *animation;
  GdkPixbuf *frame;
  cairo_surface_t *surface;
  cairo_t *ct;
  gboolean has_alpha;

  animation = gdk_pixbuf_animation_new_from_stream (input_stream, NULL, error);
  if (*error)
    {
      return;
    }

  frame = gdk_pixbuf_animation_get_static_image (animation);

  if (g_cancellable_is_cancelled (cancellable))
    {
      g_object_unref (animation);
      return;
    }

  if (!gdk_pixbuf_animation_is_static_image (animation))
    *target_animation = animation; /* Takes ref */
  else
    *target_animation = NULL;

  has_alpha = gdk_pixbuf_get_has_alpha (frame);
  surface = cairo_image_surface_create (has_alpha ? CAIRO_FORMAT_ARGB32 : CAIRO_FORMAT_RGB24,
                                        gdk_pixbuf_get_width (frame),
                                        gdk_pixbuf_get_height (frame));

  ct = cairo_create (surface);
  gdk_cairo_set_source_pixbuf (ct, frame, 0.0, 0.0);
  cairo_paint (ct);
  cairo_destroy (ct);
  
  *target_surface = surface;

  if (*target_animation == NULL) {
    g_object_unref (animation);
  }
}

static void
load_media_url (const char *url, LoadingData *task_data,
                cairo_surface_t **surface,
                GdkPixbufAnimation **animation,
                gchar *consumer_key,
                gchar *consumer_secret,
                gchar *token,
                gchar *token_secret,
                GCallback progress_callback,
                GCancellable *cancellable,
                GError **error,
                gpointer data) {
  SoupMessage *msg;
  GInputStream *input_stream;

  msg = soup_message_new ("GET", url);
  if (msg == NULL)
    {
      g_set_error (error, CB_MEDIA_DOWNLOADER_ERROR, CB_MEDIA_DOWNLOADER_ERROR_SOUP_MESSAGE_NEW, "soup_message_new failed for URI '%s'", url);
      return;
    }

  if (consumer_key && consumer_secret && token && token_secret) {
    gchar *oauth_authorization_parameters;
    gchar **url_parameters = NULL;
    int url_parameters_length;
    gchar *authorization_text;
    url_parameters_length = oauth_split_url_parameters (url, &url_parameters);
    oauth_sign_array2_process (&url_parameters_length, &url_parameters,
                                NULL, OA_HMAC, msg->method,
                                consumer_key, consumer_secret, token, token_secret);
    oauth_authorization_parameters = oauth_serialize_url_sep (url_parameters_length, 1, url_parameters, ", ", 6);
    authorization_text = g_strdup_printf ("OAuth realm=\"\", %s", oauth_authorization_parameters);
    soup_message_headers_append (msg->request_headers, "Authorization", authorization_text);

    oauth_free_array (&url_parameters_length, &url_parameters);
    free (oauth_authorization_parameters);
  }

  if (progress_callback != NULL) {
    g_signal_connect (msg, "got-chunk", progress_callback, data);
  }
  soup_session_send_message (task_data->soup_session, msg);

  if (msg->status_code != SOUP_STATUS_OK)
    {
      g_set_error (error, CB_MEDIA_DOWNLOADER_ERROR, msg->status_code, "Request on '%s' returned status '%s'", url, soup_status_get_phrase (msg->status_code));
      g_object_unref (msg);
      return;
    }

  if (g_cancellable_is_cancelled (cancellable))
    return;

  input_stream = g_memory_input_stream_new_from_data (msg->response_body->data,
                                                      msg->response_body->length,
                                                      NULL);
  load_animation (input_stream, surface, animation, cancellable, error);
  g_input_stream_close (input_stream, NULL, NULL);
  g_object_unref (input_stream);
  g_object_unref (msg);
}

static void
cb_media_downloader_get_instagram_url (CbMediaDownloader *downloader,
                                       LoadingData       *task_data)
{
  CbMedia     *media = task_data->media;
  SoupMessage *msg = soup_message_new ("GET", media->url);
  GRegex      *medium_regex;
  GRegex      *url_regex;
  GMatchInfo  *match_info;


  soup_session_send_message (task_data->soup_session, msg);
  if (msg->status_code != SOUP_STATUS_OK)
    {
      g_object_unref (msg);
      media->url = NULL;
      return;
    }

  medium_regex = g_regex_new ("<meta name=\"medium\" content=\"video\" />", 0, 0, NULL);
  g_regex_match (medium_regex, (const char *)msg->response_body->data, 0, &match_info);

  if (g_match_info_get_match_count (match_info) > 0)
    {
      g_match_info_free (match_info);

      /* Video! */
      url_regex = g_regex_new ("<meta property=\"og:video\" content=\"(.*?)\"", 0, 0, NULL);
      g_regex_match (url_regex, (const char *)msg->response_body->data, 0, &match_info);
      media->url = g_match_info_fetch (match_info, 1);
      g_regex_unref (url_regex);

      media->type = CB_MEDIA_TYPE_INSTAGRAM_VIDEO;
    }

  g_match_info_free (match_info);

  url_regex = g_regex_new ("<meta property=\"og:image\" content=\"(.*?)\"", 0, 0, NULL);
  g_regex_match (url_regex, (const char*)msg->response_body->data, 0, &match_info);

  media->thumb_url = g_match_info_fetch (match_info, 1);
  g_free (media->target_url);
  media->target_url = g_strdup (media->thumb_url);

  g_regex_unref (url_regex);
  g_regex_unref (medium_regex);
  g_match_info_free (match_info);
  g_object_unref (msg);
}

static void
cb_media_downloader_load_twitter_video (CbMediaDownloader *downloader,
                                        LoadingData       *task_data)
{
  CbMedia     *media = task_data->media;
  SoupMessage *msg = soup_message_new ("GET", media->url);
  GRegex      *regex;
  GMatchInfo  *match_info;

  soup_session_send_message (task_data->soup_session, msg);
  if (msg->status_code != SOUP_STATUS_OK)
    {
      mark_invalid (media);
      g_object_unref (msg);
      return;
    }

  regex = g_regex_new ("<img src=\"(.*?)\" class=\"animated-gif-thumbnail", 0, 0, NULL);
  g_regex_match (regex, (const char *)msg->response_body->data, 0, &match_info);

  if (g_match_info_get_match_count (match_info) > 0)
    {
      g_assert (media->type == CB_MEDIA_TYPE_ANIMATED_GIF);
      media->url = g_match_info_fetch (match_info, 1);

      g_regex_unref (regex);
      g_match_info_free (match_info);
      g_object_unref (msg);
      return;
    }
  else
    {
      g_regex_unref (regex);
      g_match_info_free (match_info);

      regex = g_regex_new ("<source video-src=\"(.*?)\"", 0, 0, NULL);
      g_regex_match (regex, (const char *)msg->response_body->data, 0, &match_info);
      media->url = g_match_info_fetch (match_info, 1);
      media->type = CB_MEDIA_TYPE_TWITTER_VIDEO;
    }

  g_regex_unref (regex);
  g_match_info_free (match_info);

  regex = g_regex_new ("poster=\"(.*?)\"", 0, 0, NULL);
  g_regex_match (regex, (const char *)msg->response_body->data, 0, &match_info);
  media->thumb_url = g_match_info_fetch (match_info, 1);

  g_regex_unref (regex);
  g_match_info_free (match_info);
  g_object_unref (msg);
}

static void
cb_media_downloader_load_real_url (CbMediaDownloader *downloader,
                                   LoadingData       *task_data,
                                   const char        *regex_str1,
                                   int                match_index1)
{
  CbMedia *media = task_data->media;
  SoupMessage *msg = soup_message_new ("GET", media->url);
  GRegex *regex;
  GMatchInfo *match_info;

  soup_session_send_message (task_data->soup_session, msg);
  if (msg->status_code != SOUP_STATUS_OK)
    {
      /* Will mark it invalid later */
      media->url = NULL;
      g_object_unref (msg);
      return;
    }

  regex = g_regex_new (regex_str1, 0, 0, NULL);
  g_regex_match (regex, (const char *)msg->response_body->data, 0, &match_info);
  media->thumb_url = g_match_info_fetch (match_info, match_index1);

  g_regex_unref (regex);
  g_match_info_free (match_info);
  g_object_unref (msg);
}

static void
update_media_progress (SoupMessage *msg,
                       SoupBuffer  *chunk,
                       gpointer     user_data)
{
  CbMedia *media = user_data;

  if (msg->response_headers == NULL) return;

  double chunk_percent = chunk->length / (double)soup_message_headers_get_content_length (msg->response_headers);

  cb_media_update_progress (media, media->percent_loaded + chunk_percent);
}

static void
cb_media_downloader_load_threaded (CbMediaDownloader *downloader,
                                   LoadingData       *task_data,
                                   GCancellable      *cancellable)
{
  const char *url;
  CbMedia *media;

  g_return_if_fail (CB_IS_MEDIA_DOWNLOADER (downloader));

  media = task_data->media;

  url = canonicalize_url (media->url);

  if (g_cancellable_is_cancelled (cancellable))
    return;


  /* For these, we first need to download some html and get the real
     URL of the image we want to display */
  if (g_str_has_prefix (url, "instagr.am") ||
      g_str_has_prefix (url, "instagram.com/p/"))
    {
      cb_media_downloader_get_instagram_url (downloader, task_data);
    }
  else if (g_str_has_prefix (url, "ow.ly/i/") ||
           g_str_has_prefix (url, "flickr.com/photos/") ||
           g_str_has_prefix (url, "flic.kr/p/") ||
           g_str_has_prefix (url, "flic.kr/s/"))
    {
      cb_media_downloader_load_real_url (downloader, task_data,
                                         "<meta property=\"og:image\" content=\"(.*?)\"", 1);
    }
  else if (g_str_has_prefix (url, "twitpic.com/"))
    {
      cb_media_downloader_load_real_url (downloader, task_data,
                                         "<meta name=\"twitter:image\" value=\"(.*?)\"", 1);
    }
  else if (g_str_has_suffix (url, "/photo/1"))
    {
      cb_media_downloader_load_twitter_video (downloader, task_data);
    }
  else if (g_str_has_prefix (url, "d.pr/i/"))
    {
      cb_media_downloader_load_real_url (downloader, task_data,
                                         "<meta property=\"og:image\"\\s+content=\"(.*?)\"", 1);
    }

  if (media->url == NULL)
    {
      g_warning ("Media is invalid. (url %s)", url);
      mark_invalid (media);
      return;
    }

  if (g_cancellable_is_cancelled (cancellable))
    return;

  char *download_url = media->thumb_url ? media->thumb_url : media->url;
  GError *error = NULL;
  load_media_url (download_url, task_data, &media->surface, &media->animation,
                  media->consumer_key, media->consumer_secret, media->token, media->token_secret,
                  G_CALLBACK(update_media_progress), cancellable, &error, media);  

  if (error) {
    g_warning ("Couldn't load pixbuf: %s (%s)", error->message, download_url);
    mark_invalid (media);
    g_error_free (error);
    return;
  }

  cb_media_loading_finished (media);
}

void
load_in_thread (GTask        *task,
                gpointer      source_object,
                gpointer      task_data,
                GCancellable *cancellable)
{
  CbMediaDownloader *downloader = source_object;
  LoadingData *data = task_data;

  cb_media_downloader_load_threaded (downloader, data, cancellable);

  g_task_return_boolean (task, TRUE);
  g_object_unref (task);
}

void
cb_media_downloader_load_async (CbMediaDownloader   *downloader,
                                CbMedia             *media,
                                GAsyncReadyCallback  callback,
                                gpointer             user_data)
{
  GTask *task;
  LoadingData *data;

  g_return_if_fail (CB_IS_MEDIA_DOWNLOADER (downloader));
  g_return_if_fail (CB_IS_MEDIA (media));
  g_return_if_fail (!media->loaded);
  g_return_if_fail (!media->loading);
  g_return_if_fail (media->surface == NULL);

  media->loading = TRUE;
  task = g_task_new (downloader, downloader->cancellable, callback, user_data);
  data = g_new0 (LoadingData, 1);
  data->media = g_object_ref (media);
  data->soup_session = soup_session_new ();
  g_task_set_task_data (task, data, (GDestroyNotify)loading_data_free);

  g_task_run_in_thread (task, load_in_thread);
}

static void
update_media_hires_progress (SoupMessage *msg,
                       SoupBuffer  *chunk,
                       gpointer     user_data)
{
  CbMedia *media = user_data;

  if (msg->response_headers == NULL) return;

  double chunk_percent = chunk->length / (double)soup_message_headers_get_content_length (msg->response_headers);

  cb_media_update_hires_progress (media, media->percent_loaded_hires + chunk_percent);
}

static void
cb_media_downloader_load_hires_threaded (CbMediaDownloader *downloader,
                                         LoadingData       *task_data,
                                         GCancellable      *cancellable)
{
  CbMedia *media;

  g_return_if_fail (CB_IS_MEDIA_DOWNLOADER (downloader));

  media = task_data->media;

  GError *error = NULL;
  load_media_url (media->url, task_data, &media->surface_hires, &media->animation,
                  media->consumer_key, media->consumer_secret, media->token, media->token_secret,
                  G_CALLBACK(update_media_hires_progress), cancellable, &error, media);  

  if (error) {
    g_warning ("Couldn't load hires pixbuf: %s (%s)", error->message, media->url);
    g_error_free (error);
    return;
  }

  media->width = cairo_image_surface_get_width(media->surface_hires);
  media->height = cairo_image_surface_get_height(media->surface_hires);

  cb_media_loading_hires_finished (media);
}

void
load_hires_in_thread (GTask        *task,
                gpointer      source_object,
                gpointer      task_data,
                GCancellable *cancellable)
{
  CbMediaDownloader *downloader = source_object;
  LoadingData *data = task_data;

  cb_media_downloader_load_hires_threaded (downloader, data, cancellable);

  g_task_return_boolean (task, TRUE);
  g_object_unref (task);
}

void
cb_media_downloader_load_hires_async (CbMediaDownloader   *downloader,
                                      CbMedia             *media,
                                      GAsyncReadyCallback  callback,
                                      gpointer             user_data)
{
  GTask *task;
  LoadingData *data;

  g_return_if_fail (CB_IS_MEDIA_DOWNLOADER (downloader));
  g_return_if_fail (CB_IS_MEDIA (media));
  g_return_if_fail (media->surface_hires == NULL);

  if (media->loading_hires || media->loaded_hires) {
    return;
  }

  media->loading_hires = TRUE;
  task = g_task_new (downloader, downloader->cancellable, callback, user_data);
  data = g_new0 (LoadingData, 1);
  data->media = g_object_ref (media);
  data->soup_session = soup_session_new ();
  g_task_set_task_data (task, data, (GDestroyNotify)loading_data_free);

  g_task_run_in_thread (task, load_hires_in_thread);
}

gboolean
cb_media_downloader_load_finish (CbMediaDownloader  *downloader,
                                 GAsyncResult       *result,
                                 GError            **error)
{
  g_return_val_if_fail (g_task_is_valid (result, downloader), FALSE);

  return g_task_propagate_boolean (G_TASK (result), error);
}

void
cb_media_downloader_load_all (CbMediaDownloader  *downloader,
                              CbMiniTweet        *t)
{
  guint i;
  g_return_if_fail (CB_IS_MEDIA_DOWNLOADER (downloader));

  if (downloader->disabled)
    return;

  for (i = 0; i < t->n_medias; i ++)
    cb_media_downloader_load_async (downloader, t->medias[i], NULL, NULL);
}

void
cb_media_downloader_disable (CbMediaDownloader *downloader)
{
  g_return_if_fail (CB_IS_MEDIA_DOWNLOADER (downloader));

  downloader->disabled = TRUE;
}

void
cb_media_downloader_shutdown (CbMediaDownloader *downloader)
{
  g_debug ("MediaDownloader shutdown");

  g_cancellable_cancel (downloader->cancellable);
  g_object_unref (downloader->cancellable);

  // XXX OK?
  g_object_unref (downloader);
}

gboolean
is_media_candidate (const char *url)
{
  url = canonicalize_url (url);

  return g_str_has_prefix (url, "instagr.am") ||
         g_str_has_prefix (url, "instagram.com/p/") ||
        (g_str_has_prefix (url, "i.imgur.com") && !g_str_has_suffix (url, "gifv")) ||
         g_str_has_prefix (url, "d.pr/i/") ||
         g_str_has_prefix (url, "ow.ly/i/") ||
         g_str_has_prefix (url, "flickr.com/photos/") ||
         g_str_has_prefix (url, "flic.kr/p/") ||
         g_str_has_prefix (url, "flic.kr/s/") ||
#ifdef VIDEO
         g_str_has_suffix (url, "/photo/1/") ||
         g_str_has_prefix (url, "video.twimg.com/ext_tw_video") ||
#endif
         g_str_has_prefix (url, "pbs.twimg.com/media/") ||
         g_str_has_prefix (url, "twitpic.com")
   ;

}

gboolean
is_twitter_media_candidate (const char *url)
{
  url = canonicalize_url (url);

  return
#ifdef VIDEO
         g_str_has_prefix (url, "/photo/1/") ||
         g_str_has_prefix (url, "video.twimg.com/ext_tw_video") ||
         g_str_has_prefix (url, "video.twimg.com/amplify_video") ||
#endif
         g_str_has_prefix (url, "pbs.twimg.com/media/")
   ;

}

static void
cb_media_downloader_init (CbMediaDownloader *downloader)
{
  downloader->disabled    = FALSE;
  downloader->cancellable = g_cancellable_new ();
}

static void
cb_media_downloader_class_init (CbMediaDownloaderClass *class)
{
}

GQuark
cb_media_downloader_error_quark (void)
{
	static GQuark error;
	if (!error)
		error = g_quark_from_static_string ("cb_media_downloader_error_quark");
	return error;
}