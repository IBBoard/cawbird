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
#include "CbMedia.h"



G_DEFINE_TYPE (CbMedia, cb_media, G_TYPE_OBJECT);

enum {
  PROGRESS,
  HIRES_PROGRESS,
  LAST_SIGNAL
};
static guint media_signals[LAST_SIGNAL] = { 0 };


static void
cb_media_finalize (GObject *object)
{
  CbMedia *media = CB_MEDIA (object);
  cairo_surface_destroy (media->surface);
  if (media->surface_hires != NULL) {
    cairo_surface_destroy (media->surface_hires);
  }
  g_free (media->thumb_url);
  g_free (media->target_url);
  g_free (media->url);
  g_free (media->alt_text);

  if (media->animation)
    g_object_unref (media->animation);

  G_OBJECT_CLASS (cb_media_parent_class)->finalize (object);
}

static void
cb_media_class_init (CbMediaClass *class)
{
  GObjectClass *gobject_class = G_OBJECT_CLASS (class);
  gobject_class->finalize = cb_media_finalize;

  media_signals[PROGRESS] = g_signal_new ("progress",
                                          G_OBJECT_CLASS_TYPE (gobject_class),
                                          G_SIGNAL_RUN_FIRST,
                                          0,
                                          NULL, NULL,
                                          NULL, G_TYPE_NONE, 0);

  media_signals[HIRES_PROGRESS] = g_signal_new ("hires-progress",
                                                G_OBJECT_CLASS_TYPE (gobject_class),
                                                G_SIGNAL_RUN_FIRST,
                                                0,
                                                NULL, NULL,
                                                NULL, G_TYPE_NONE, 0);
}

static void
cb_media_init (CbMedia *media)
{
  media->surface = NULL;
  media->animation = NULL;
  media->loading = FALSE;
  media->loaded  = FALSE;
  media->loading_hires = FALSE;
  media->loaded_hires = FALSE;
  media->invalid = FALSE;
  media->surface = NULL;
  media->surface_hires = NULL;
  media->url     = NULL;
  media->alt_text = NULL;
  media->percent_loaded = 0;
  media->percent_loaded_hires = 0;
  media->width = -1;
  media->height = -1;
  media->thumb_width = -1;
  media->thumb_height = -1;
}

CbMedia *
cb_media_new (void)
{
  return CB_MEDIA (g_object_new (CB_TYPE_MEDIA, NULL));
}

gboolean
cb_media_is_video (CbMedia *media)
{
  switch (media->type)
    {
      case CB_MEDIA_TYPE_ANIMATED_GIF:
      case CB_MEDIA_TYPE_TWITTER_VIDEO:
      case CB_MEDIA_TYPE_INSTAGRAM_VIDEO:
        return TRUE;

      default:
        return FALSE;
    }

  return FALSE;
}

static gboolean
emit_media_progress (gpointer data)
{
  CbMedia *media = data;

  g_return_val_if_fail (CB_IS_MEDIA (media), G_SOURCE_REMOVE);

  g_signal_emit (data, media_signals[PROGRESS], 0);

  return G_SOURCE_REMOVE;
}

void
cb_media_update_progress (CbMedia *media, double progress)
{
  g_return_if_fail (CB_IS_MEDIA (media));
  g_return_if_fail (progress >= 0);

  media->percent_loaded = progress;

  g_main_context_invoke (NULL,
                         emit_media_progress,
                         media);
}

void
cb_media_loading_finished (CbMedia *media)
{
  g_return_if_fail (CB_IS_MEDIA (media));

  if (media->invalid) {
    // Short-circuit for invalid media
    cb_media_update_progress (media, 1.0);
    return;
  }

  media->thumb_width   = cairo_image_surface_get_width(media->surface);
  media->thumb_height  = cairo_image_surface_get_height(media->surface);

  // Take these sizes as full size if full size isn't set.
  // This happens when loading third-party images which don't have
  // Twitter's scaling variants.
  if (media->width == -1) {
    media->width = media->thumb_width;
  }

  if (media->height == -1) {
    media->height = media->thumb_height;
  }

  media->invalid = FALSE;
  media->loaded = TRUE;
  media->loading = FALSE;

  if (media->height == media->thumb_height && media->width == media->thumb_width) {
    // There is no higher res to load so pretend we did.
    // The get_highest_res_surface() function then deals with what is available
    media->loaded_hires = TRUE;
  }
  else if (cb_media_is_video (media)) {
    // Video doesn't have a hires, it runs the URL through GStreamer, so pretend we loaded the hires image
    media->loaded_hires = TRUE;
  }

  cb_media_update_progress (media, 1.0);
}

CbMediaType
cb_media_type_from_url (const char *url)
{
  if (g_str_has_suffix (url, "/photo/1"))
    return CB_MEDIA_TYPE_ANIMATED_GIF;

  if (g_str_has_suffix (url, ".gif"))
    return CB_MEDIA_TYPE_GIF;

  return CB_MEDIA_TYPE_IMAGE;
}

static gboolean
emit_media_hires_progress (gpointer data)
{
  CbMedia *media = data;

  g_return_val_if_fail (CB_IS_MEDIA (media), G_SOURCE_REMOVE);

  g_signal_emit (data, media_signals[HIRES_PROGRESS], 0);

  return G_SOURCE_REMOVE;
}

void
cb_media_update_hires_progress (CbMedia *media, double progress)
{
  g_return_if_fail (CB_IS_MEDIA (media));
  g_return_if_fail (progress >= 0);

  media->percent_loaded_hires = progress;

  g_main_context_invoke (NULL,
                         emit_media_hires_progress,
                         media);
}

void
cb_media_loading_hires_finished (CbMedia *media)
{
  g_return_if_fail (CB_IS_MEDIA (media));

  media->loaded_hires = TRUE;
  media->loading_hires = FALSE;

  cb_media_update_hires_progress (media, 1.0);
}

cairo_surface_t *
cb_media_get_highest_res_surface (CbMedia *media)
{
  return media->surface_hires == NULL ? media->surface : media->surface_hires;
}