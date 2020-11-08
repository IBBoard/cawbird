/*  This file is part of Cawbird, a Gtk+ linux Twitter client forked from Corebird.
 *  Copyright (C) 2017 Timm Bäder (Corebird)
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

#include "cawbird.h"
#include "CbUserStream.h"
#include "CbUtils.h"
#include <rest/oauth-proxy.h>
#include <string.h>

#define short_url_length 23

G_DEFINE_TYPE (CbUserStream, cb_user_stream, G_TYPE_OBJECT);

gboolean load_timeline_tweets (gpointer user_data);
gboolean load_mentions_tweets (gpointer user_data);
gboolean load_favourited_tweets (gpointer user_data);
gboolean load_dm_tweets (gpointer user_data);

enum {
  INTERRUPTED,
  RESUMED,
  LAST_SIGNAL
};

enum {
  STATE_STOPPED,    /* Initial state */
  STATE_RUNNING,    /* Started and message received */
  STATE_STARTED,    /* Started, but no message/heartbeat received yet */
  STATE_STOPPING,   /* Stopping the stream */
};

static guint user_stream_signals[LAST_SIGNAL] = { 0 };

static void
cb_user_stream_finalize (GObject *o)
{
  CbUserStream *self = CB_USER_STREAM (o);

  cb_user_stream_stop (self);

  g_ptr_array_unref (self->receivers);
  g_free (self->account_name);

  if (self->network_changed_id != 0)
    {
      g_signal_handler_disconnect (self->network_monitor, self->network_changed_id);
    }

  G_OBJECT_CLASS (cb_user_stream_parent_class)->finalize (o);
}

static void
cb_user_stream_restart (CbUserStream *self)
{
  self->restarting = TRUE;
  cb_user_stream_stop (self);
  cb_user_stream_start (self);
}

static gboolean
network_cb (gpointer user_data)
{
  CbUserStream *self = user_data;
  gboolean available;

  if (self->state == STATE_RUNNING)
    {
      self->network_timeout_id = 0;
      return G_SOURCE_REMOVE;
    }

  available = g_network_monitor_get_network_available (self->network_monitor);

  if (available)
    {
      g_debug ("%u Restarting stream (reason: network available (timeout))", self->state);
      self->network_timeout_id = 0;
      cb_user_stream_restart (self);
      return G_SOURCE_REMOVE;
    }

  return G_SOURCE_CONTINUE;
}

static void
start_network_timeout (CbUserStream *self)
{
  if (self->network_timeout_id != 0)
    return;

  self->network_timeout_id = g_timeout_add (1 * 1000, network_cb, self);
}

static void
network_changed_cb (GNetworkMonitor *monitor,
                    gboolean         available,
                    gpointer         user_data)
{
  CbUserStream *self = user_data;

  if (available == self->network_available)
    return;

  self->network_available = available;

  if (available)
    {
      g_debug ("%u Restarting stream (reason: Network available (callback))", self->state);
      cb_user_stream_restart (self);
    }
  else
    {
      g_debug ("%u Connection lost (%s) Reason: network unavailable", self->state, self->account_name);
      g_signal_emit (self, user_stream_signals[INTERRUPTED], 0);
      cb_clear_source (&self->heartbeat_timeout_id);

      start_network_timeout (self);
    }
}

static void
cb_user_stream_init (CbUserStream *self)
{
  self->receivers = g_ptr_array_new ();
  self->restarting = FALSE;
  self->state = STATE_STOPPED;

  if (self->stresstest)
    {
      self->proxy = oauth_proxy_new ("Vf9torDW2ZOw32DfhUtI9csL8",
                                     "18BEr1mdDH46cJhw5mUMwHe2TiBExOopEDxFbPzfJrlnFuvZJ2",
                                     "https://api.twitter.com/",
                                     FALSE);
    }
  else
    {
      /* TODO: We should be getting these from the settings */
      self->proxy = oauth_proxy_new ("Vf9torDW2ZOw32DfhUtI9csL8",
                                     "18BEr1mdDH46cJhw5mUMwHe2TiBExOopEDxFbPzfJrlnFuvZJ2",
                                     "https://api.twitter.com/",
                                     FALSE);
    }
  self->proxy_data_set = FALSE;

  self->network_monitor = g_network_monitor_get_default ();
  self->network_available = g_network_monitor_get_network_available (self->network_monitor);
  self->network_changed_id = g_signal_connect (self->network_monitor,
                                               "network-changed",
                                               G_CALLBACK (network_changed_cb), self);

  if (!self->network_available)
    start_network_timeout (self);
}

static void
cb_user_stream_class_init (CbUserStreamClass *klass)
{
  GObjectClass *object_class = G_OBJECT_CLASS (klass);

  object_class->finalize = cb_user_stream_finalize;

  user_stream_signals[INTERRUPTED] = g_signal_new ("interrupted",
                                                   G_OBJECT_CLASS_TYPE (object_class),
                                                   G_SIGNAL_RUN_FIRST,
                                                   0,
                                                   NULL, NULL,
                                                   NULL, G_TYPE_NONE, 0);

  user_stream_signals[RESUMED] = g_signal_new ("resumed",
                                                G_OBJECT_CLASS_TYPE (object_class),
                                                G_SIGNAL_RUN_FIRST,
                                                0,
                                                NULL, NULL,
                                                NULL, G_TYPE_NONE, 0);
}

CbUserStream *
cb_user_stream_new (const char *account_name,
                    gboolean    stresstest)
{
  CbUserStream *self = CB_USER_STREAM (g_object_new (CB_TYPE_USER_STREAM, NULL));
  self->account_name = g_strdup (account_name);
  self->stresstest = stresstest;

  g_debug ("Creating stream for %s", account_name);

  return self;
}

void
stream_tweet (CbUserStream *self,
              CbStreamMessageType  message_type,
              JsonNode            *node) {
  guint i;

  if (message_type == CB_STREAM_MESSAGE_UNSUPPORTED) {
    g_debug ("Skipped unsupported message on stream @%s\n", self->account_name);
    return;
  }

#if DEBUG
  g_print ("Message with type %d on stream @%s\n", message_type, self->account_name);

  JsonGenerator *gen = json_generator_new ();
  json_generator_set_root (gen, node);
  json_generator_set_pretty (gen, TRUE);
  gchar *json_dump = json_generator_to_data (gen, NULL);
  g_print ("%s", json_dump);
#endif

  for (i = 0; i < self->receivers->len; i++) {
    cb_message_receiver_stream_message_received (g_ptr_array_index (self->receivers, i),
                                                  message_type,
                                                  node);
  }
}

void
cb_user_stream_inject_tweet (CbUserStream *self,
              CbStreamMessageType  message_type,
              const gchar *content) {
  JsonParser *parser;
  JsonNode *root_node;
  JsonObject *root_obj;
  GError *error = NULL;

  parser = json_parser_new ();
  json_parser_load_from_data (parser, content, -1, &error);
  if (error)
    {
      g_warning("Failed to parse %s", content);
      return;
    }
  root_node = json_parser_get_root (parser);
  root_obj = json_node_get_object (root_node);

  if (json_object_has_member (root_obj, "event"))
    {
      // We've got a single DM, which is wrapped, so unwrap it
      root_node = json_object_get_member (root_obj, "event");
    }
  else if (json_object_has_member (root_obj, "quoted_status_permalink"))
    {
      // Quote tweets don't include the quoted tweet URL in the returned text, but they do when they come in the timeline
      // So we need to fudge it here and add the URL entity and the text before we send it to the app
      JsonObject *entities;
      JsonArray *urls;
      JsonObject *permalink = json_object_get_object_member (root_obj, "quoted_status_permalink");
      const gchar *quoted_url = json_object_get_string_member (permalink, "url");
      entities      = json_object_get_object_member (root_obj, "entities");
      urls          = json_object_get_array_member (entities, "urls");
      gboolean url_found = FALSE;

      for (guint i  = 0, p = json_array_get_length (urls); i < p; i ++)
        {
          JsonObject *url_obj = json_node_get_object (json_array_get_element (urls, i));
          const char *url = json_object_get_string_member (url_obj, "url");

          if (!g_strcmp0 (url, quoted_url))
            {
              url_found = TRUE;
              break;
            }
        }

      if (!url_found)
        {
          // Get the old text length
          JsonArray *display_range = json_object_get_array_member (root_obj, "display_text_range");
          guint64 old_length = json_array_get_int_element (display_range, 1);

          // Create and set the new text
          gchar *new_full_text = g_strdup_printf ("%s %s", json_object_get_string_member (root_obj, "full_text"), quoted_url);
          json_object_set_string_member (root_obj, "full_text", new_full_text);
          guint64 old_length_with_space = old_length + 1;
          guint64 new_length = old_length_with_space + short_url_length;
          g_free (new_full_text);

          // Build the URL entity
          JsonObject *url_obj = json_object_new ();
          json_object_set_string_member (url_obj, "url", quoted_url);
          json_object_set_string_member (url_obj, "expanded_url", json_object_get_string_member (permalink, "expanded"));
          json_object_set_string_member (url_obj, "display_url", json_object_get_string_member (permalink, "display"));
          JsonArray *indicies = json_array_sized_new (2);
          json_array_add_int_element (indicies, old_length_with_space);
          json_array_add_int_element (indicies, new_length);
          json_object_set_array_member (url_obj, "indices", indicies);
          json_array_add_object_element (urls, url_obj);

          // Update the text length
          json_array_remove_element (display_range, 1);
          json_array_add_int_element (display_range, new_length);
        }
    }

  stream_tweet (self, message_type, root_node);
}

// TODO: Refactor a common "load_tweets_done" that parses, sets the last ID and sends the right message type
void
load_timeline_tweets_done  (GObject *source_object,
                        GAsyncResult *result,
                        gpointer user_data) {
  CbUserStream *self = user_data;
  GError *error = NULL;

  JsonNode *root_node;
  JsonArray *root_arr;
  guint len;

  root_node = cb_utils_load_threaded_finish (result, &error);

  if (error != NULL)
    {
      g_warning ("%s: %s (%s - %d)", __FUNCTION__, error->message, g_quark_to_string (error->domain), error->code);
      if (error->domain == REST_PROXY_ERROR && error->code == REST_PROXY_ERROR_SSL) {
        g_debug ("Reloading timeline on SSL failure");
        load_timeline_tweets (self);
      }
      return;
    }

  root_arr = json_node_get_array (root_node);
  len = json_array_get_length (root_arr);

  g_debug ("Got %d timeline tweets", len);
  gboolean first_load = self->last_home_id == 0;

  for (guint i = len; i > 0; i--) {
    JsonNode *node = json_array_get_element (root_arr, i - 1);
    JsonObject *obj = json_node_get_object (node);
    self->last_home_id = json_object_get_int_member (obj, "id");
    stream_tweet(self, CB_STREAM_MESSAGE_TWEET, node);
  }

  if (first_load) {
    stream_tweet (self, CB_STREAM_MESSAGE_TIMELINE_LOADED, json_node_new(JSON_NODE_NULL));
  }

  g_cancellable_cancel(self->home_cancellable);
  self->home_cancellable = NULL;
}

gboolean
load_timeline_tweets (gpointer user_data)
{
  CbUserStream *self = user_data;

  if (self->home_cancellable && ! g_cancellable_is_cancelled(self->home_cancellable)) {
    g_debug ("Cancelling existing timeline cancellable");
    g_cancellable_cancel(self->home_cancellable);
  }

  gboolean is_first_load = self->last_home_id == 0;
  char* requested_tweet_count = is_first_load ? "28" : "200";
  RestProxyCall *proxy_call = rest_proxy_new_call (self->proxy);
  g_debug("Loading timeline tweets");
  rest_proxy_call_set_function (proxy_call, "1.1/statuses/home_timeline.json");
  rest_proxy_call_set_method (proxy_call, "GET");
  rest_proxy_call_add_param (proxy_call, "count", requested_tweet_count);
  rest_proxy_call_add_param (proxy_call, "contributor_details", "true");
  rest_proxy_call_add_param (proxy_call, "include_my_retweet", "true");
  rest_proxy_call_add_param (proxy_call, "tweet_mode", "extended");
  rest_proxy_call_add_param (proxy_call, "include_ext_alt_text", "true");

  if (!is_first_load) {
    char since_id [20];
    // We may occasionally miss tweets (bug #147). This appears to be because of eventual consistency (tweets appear at the server
    // that we query *after* our last query but are timestamped *before* the 'since' ID for that query). So we need to try and overlap a bit.
    // Tweet IDs are "snowflakes" with 12 bits of sequence (lowest), 5 bits of worker ID, 5 bits of data centre, and then the timestamp.
    // https://github.com/twitter-archive/snowflake/blob/snowflake-2010/src/main/scala/com/twitter/service/snowflake/IdWorker.scala#L27-L36
    // The timestamp is to millisecond accuracy, so we want to ignore the last three base-10 digits. Plus more digits to give more than
    // one second of overlap. 10 bits is ~1s and every extra bit is double that.
    // We mask the ID with that value to see whether we get any missed tweets.
    // Note: this will result in at least the last tweet being reloaded each time.
    gint timestamp_shift = 5 + 5 + 12;
    gint overlap_shift = 13; // 13bits ~= 8 seconds
    sprintf(since_id, "%ld", self->last_home_id & (-1L << (timestamp_shift + overlap_shift)));
    rest_proxy_call_add_param(proxy_call, "since_id", since_id);
  }

  self->home_cancellable = g_cancellable_new();
  cb_utils_load_threaded_async (proxy_call, self->home_cancellable, load_timeline_tweets_done, self);
  return TRUE;
}

void
load_mentions_tweets_done  (GObject *source_object,
                        GAsyncResult *result,
                        gpointer user_data) {
  CbUserStream *self = user_data;
  GError *error = NULL;

  JsonNode *root_node;
  JsonArray *root_arr;
  guint len;

  root_node = cb_utils_load_threaded_finish (result, &error);

  if (error != NULL)
    {
      g_warning ("%s: %s (%s - %d)", __FUNCTION__, error->message, g_quark_to_string (error->domain), error->code);
      if (error->domain == REST_PROXY_ERROR && error->code == REST_PROXY_ERROR_SSL) {
        g_debug ("Reloading mentions on SSL failure");
        load_mentions_tweets (self);
      }
      return;
    }

  root_arr = json_node_get_array (root_node);
  len = json_array_get_length (root_arr);

  g_debug ("Got %d mention tweets", len);
  gboolean first_load = self->last_mentions_id == 0;

  for (guint i = len; i > 0; i--) {
    JsonNode *node = json_array_get_element (root_arr, i - 1);
    JsonObject *obj = json_node_get_object (node);
    self->last_mentions_id = json_object_get_int_member (obj, "id");
    stream_tweet(self, CB_STREAM_MESSAGE_MENTION, node);
  }

  if (first_load) {
    stream_tweet (self, CB_STREAM_MESSAGE_MENTIONS_LOADED, json_node_new(JSON_NODE_NULL));
  }

  g_cancellable_cancel(self->mentions_cancellable);
  self->mentions_cancellable = NULL;
}

gboolean
load_mentions_tweets (gpointer user_data)
{
  CbUserStream *self = user_data;

  if (self->mentions_cancellable && ! g_cancellable_is_cancelled(self->mentions_cancellable)) {
    g_debug ("Cancelling existing mentions cancellable");
    g_cancellable_cancel(self->mentions_cancellable);
  }

  gboolean is_first_load = self->last_mentions_id == 0;
  char* requested_tweet_count = is_first_load ? "28" : "200";
  RestProxyCall *proxy_call = rest_proxy_new_call (self->proxy);
  g_debug("Loading mention tweets");
  rest_proxy_call_set_function (proxy_call, "1.1/statuses/mentions_timeline.json");
  rest_proxy_call_set_method (proxy_call, "GET");
  rest_proxy_call_add_param (proxy_call, "count", requested_tweet_count);
  rest_proxy_call_add_param (proxy_call, "contributor_details", "true");
  rest_proxy_call_add_param (proxy_call, "include_my_retweet", "true");
  rest_proxy_call_add_param (proxy_call, "include_entities", "true");
  rest_proxy_call_add_param (proxy_call, "tweet_mode", "extended");
  rest_proxy_call_add_param (proxy_call, "include_ext_alt_text", "true");

  if (!is_first_load) {
    char since_id [20];
    sprintf(since_id, "%ld", self->last_mentions_id);
    rest_proxy_call_add_param(proxy_call, "since_id", since_id);
  }

  self->mentions_cancellable = g_cancellable_new();
  cb_utils_load_threaded_async (proxy_call, self->mentions_cancellable, load_mentions_tweets_done, self);
  return TRUE;
}

void
load_favourited_tweets_done  (GObject *source_object,
                        GAsyncResult *result,
                        gpointer user_data) {
  CbUserStream *self = user_data;
  GError *error = NULL;

  JsonNode *root_node;
  JsonArray *root_arr;
  guint len;

  root_node = cb_utils_load_threaded_finish (result, &error);

  if (error != NULL)
    {
      g_warning ("%s: %s (%s - %d)", __FUNCTION__, error->message, g_quark_to_string (error->domain), error->code);
      if (error->domain == REST_PROXY_ERROR && error->code == REST_PROXY_ERROR_SSL) {
        g_debug ("Reloading favorited on SSL failure");
        load_favourited_tweets (self);
      }
      return;
    }

  root_arr = json_node_get_array (root_node);
  len = json_array_get_length (root_arr);

  g_debug ("Got %d favourited tweets", len);
  gboolean first_load = self->last_favourited_id == 0;

  for (guint i = len; i > 0; i--) {
    JsonNode *node = json_array_get_element (root_arr, i - 1);
    JsonObject *obj = json_node_get_object (node);
    self->last_favourited_id = json_object_get_int_member (obj, "id");
    stream_tweet(self, CB_STREAM_MESSAGE_EVENT_FAVORITE, node);
  }

  if (first_load) {
    stream_tweet (self, CB_STREAM_MESSAGE_FAVORITES_LOADED, json_node_new(JSON_NODE_NULL));
  }

  g_cancellable_cancel(self->favourited_cancellable);
  self->favourited_cancellable = NULL;
}

gboolean
load_favourited_tweets (gpointer user_data)
{
  CbUserStream *self = user_data;

  if (self->favourited_cancellable && ! g_cancellable_is_cancelled(self->favourited_cancellable)) {
    g_debug ("Cancelling existing favourites cancellable");
    g_cancellable_cancel(self->favourited_cancellable);
  }

  gboolean is_first_load = self->last_favourited_id == 0;
  char* requested_tweet_count = is_first_load ? "28" : "200";
  RestProxyCall *proxy_call = rest_proxy_new_call (self->proxy);
  g_debug("Loading favourited tweets");
  rest_proxy_call_set_function (proxy_call, "1.1/favorites/list.json");
  rest_proxy_call_set_method (proxy_call, "GET");
  rest_proxy_call_add_param (proxy_call, "count", requested_tweet_count);
  rest_proxy_call_add_param (proxy_call, "contributor_details", "true");
  rest_proxy_call_add_param (proxy_call, "include_my_retweet", "true");
  rest_proxy_call_add_param (proxy_call, "include_entities", "true");
  rest_proxy_call_add_param (proxy_call, "tweet_mode", "extended");
  rest_proxy_call_add_param (proxy_call, "include_ext_alt_text", "true");

  if (!is_first_load) {
    char since_id [20];
    sprintf(since_id, "%ld", self->last_favourited_id);
    rest_proxy_call_add_param(proxy_call, "since_id", since_id);
  }

  self->favourited_cancellable = g_cancellable_new();
  cb_utils_load_threaded_async (proxy_call, self->favourited_cancellable, load_favourited_tweets_done, self);
  return TRUE;
}

// Fix a cyclic definition
void
load_dm_tweets_with_cursor (gpointer user_data, const gchar *cursor);

void
load_dm_tweets_done  (GObject *source_object,
                        GAsyncResult *result,
                        gpointer user_data) {
  CbUserStream *self = user_data;
  GError *error = NULL;

  JsonNode *root_node;
  JsonObject *root_obj;
  JsonArray *root_arr;
  guint len;

  root_node = cb_utils_load_threaded_finish (result, &error);

  if (error != NULL)
    {
      g_warning ("%s: %s (%s - %d)", __FUNCTION__, error->message, g_quark_to_string (error->domain), error->code);
      if (error->domain == REST_PROXY_ERROR && error->code == REST_PROXY_ERROR_SSL) {
        g_debug ("Reloading DMs on SSL failure");
        load_dm_tweets (self);
      }
      return;
    }

#if DEBUG
  g_print ("DMs on @%s\n", self->account_name);

  JsonGenerator *gen = json_generator_new ();
  json_generator_set_root (gen, root_node);
  json_generator_set_pretty (gen, TRUE);
  gchar *json_dump = json_generator_to_data (gen, NULL);
  g_print ("%s", json_dump);
  g_print("Done DMs");
#endif

  root_obj = json_node_get_object (root_node);
  root_arr = json_object_get_array_member(root_obj, "events");
  len = json_array_get_length (root_arr);

  // TODO: Look for a "next_cursor" and load older DMs
  // https://developer.twitter.com/en/docs/direct-messages/sending-and-receiving/api-reference/list-events

  g_debug ("Got %d DMs", len);

  gboolean all_newer = TRUE;
  gboolean all_older = TRUE;

  for (guint i = len; i > 0; i--) {
    JsonNode *node = json_array_get_element (root_arr, i - 1);
    JsonObject *obj = json_node_get_object (node);
    int message_type = CB_STREAM_MESSAGE_UNSUPPORTED;
    const gchar *type = json_object_get_string_member(obj, "type");

    if (strcmp(type, "message_create") == 0) {
      message_type = CB_STREAM_MESSAGE_DIRECT_MESSAGE;
    }

    gint64 id = strtol (json_object_get_string_member (obj, "id"), NULL, 10);

    if (id < self->first_dm_id) {
      self->first_dm_id = id;
      all_newer = FALSE;
    }
    else if (id <= self->last_dm_id) {
      all_older = FALSE;
      all_newer = FALSE;
      // DMs behave differently to other "timelines" so we need to ignore messages we've seen
      // And we assume we've seen it if it has an older ID. But we can't break because later
      // in the collection is newer and might be unseen.
      continue;
    }
    else {
      all_older = FALSE;
      if (id > self->new_last_dm_id) {
        self->new_last_dm_id = id;
      }
    }
    g_debug("New DM with type: %s", type);
    stream_tweet (self, message_type, node);
  }

  g_cancellable_cancel(self->dm_cancellable);
  self->dm_cancellable = NULL;
  
  gboolean first_load = self->last_dm_id == 0;
  // Limit fetches for throttling. 5 at first load lets us load ~300 old DMs from last 30 days.
  // 1 recursion when scheduled every 2 minutes runs right to the "15/15min" limit.
  // This *should* only cause throttling problems just when someone has a big backlog AND has
  // lots of tweets coming in every 2 minutes.
  unsigned char max_recursions = first_load ? 5 : 1;

  if ((all_newer || all_older) && self->dm_recursions < max_recursions && json_object_has_member(root_obj, "next_cursor")) {
    self->dm_recursions++;
    const gchar *cursor = json_object_get_string_member(root_obj, "next_cursor");
    load_dm_tweets_with_cursor(user_data, cursor);
  }
  else {
    if (first_load) {
      stream_tweet (self, CB_STREAM_MESSAGE_DIRECT_MESSAGES_LOADED, json_node_new(JSON_NODE_NULL));
    }

    self->last_dm_id = self->new_last_dm_id;
    self->dm_recursions = 0;
  }
}

void
load_dm_tweets_with_cursor (gpointer user_data, const gchar *cursor)
{
  CbUserStream *self = user_data;

  if (self->dm_cancellable && ! g_cancellable_is_cancelled(self->dm_cancellable)) {
    g_debug ("Cancelling existing cancellable");
    g_cancellable_cancel(self->dm_cancellable);
  }

  RestProxyCall *proxy_call = rest_proxy_new_call (self->proxy);
  rest_proxy_call_set_function (proxy_call, "1.1/direct_messages/events/list.json");
  rest_proxy_call_set_method (proxy_call, "GET");
  rest_proxy_call_add_param (proxy_call, "count", "50");
  if (cursor) {
    rest_proxy_call_add_param(proxy_call, "cursor", cursor);
  }
  g_debug("Loading DM tweets for cursor %s", cursor ? cursor : "none");

  self->dm_cancellable = g_cancellable_new();
  cb_utils_load_threaded_async (proxy_call, self->dm_cancellable, load_dm_tweets_done, self);
}

gboolean
load_dm_tweets (gpointer user_data)
{
  load_dm_tweets_with_cursor(user_data, NULL);
  return TRUE;
}

void
cb_user_stream_start (CbUserStream *self)
{
  g_debug("Loading timeline tweets on start");
  load_timeline_tweets (self);
  g_debug("Loading mention tweets on start");
  load_mentions_tweets (self);
  g_debug("Loading favourited tweets on start");
  load_favourited_tweets (self);
  g_debug("Loading DMs on start");
  load_dm_tweets (self);

  if (!self->timeline_timeout) {
    g_debug("Adding timeout for timeline");
    self->timeline_timeout = g_timeout_add_seconds_full (G_PRIORITY_DEFAULT, 60 * 2, load_timeline_tweets, self, NULL);
  }
  if (!self->mentions_timeout) {
    g_debug("Adding timeout for mentions");
    self->mentions_timeout = g_timeout_add_seconds_full (G_PRIORITY_DEFAULT, 60 * 2, load_mentions_tweets, self, NULL);
  }
  if (!self->favourited_timeout) {
    g_debug("Adding timeout for favourites");
    self->favourited_timeout = g_timeout_add_seconds_full (G_PRIORITY_DEFAULT, 60 * 2, load_favourited_tweets, self, NULL);
  }
  if (!self->dm_timeout) {
    g_debug("Adding timeout for DMs");
    self->dm_timeout = g_timeout_add_seconds_full (G_PRIORITY_DEFAULT, 60 * 2, load_dm_tweets, self, NULL);
  }
}

void cb_user_stream_stop (CbUserStream *self)
{
  if (self->timeline_timeout) {
    g_source_remove (self->timeline_timeout);
    self->timeline_timeout = 0;
  }
  if (self->mentions_timeout) {
    g_source_remove (self->mentions_timeout);
    self->mentions_timeout = 0;
  }
  if (self->favourited_timeout) {
    g_source_remove (self->favourited_timeout);
    self->favourited_timeout = 0;
  }
  if (self->dm_timeout) {
    g_source_remove (self->dm_timeout);
    self->dm_timeout = 0;
  }
}

void
cb_user_stream_set_proxy_data (CbUserStream *self,
                               const char   *token,
                               const char   *token_secret)
{
  oauth_proxy_set_token (OAUTH_PROXY (self->proxy), token);
  oauth_proxy_set_token_secret (OAUTH_PROXY (self->proxy), token_secret);

  self->proxy_data_set = TRUE;
}

void
cb_user_stream_register (CbUserStream      *self,
                         CbMessageReceiver *receiver)
{
  g_ptr_array_add (self->receivers, receiver);
}

void
cb_user_stream_unregister (CbUserStream      *self,
                           CbMessageReceiver *receiver)
{
  guint i;

  for (i = 0; i < self->receivers->len; i ++)
    {
      CbMessageReceiver *r = g_ptr_array_index (self->receivers, i);

      if (r == receiver)
        {
          g_ptr_array_remove_index_fast (self->receivers, i);
          break;
        }
    }
}

void
cb_user_stream_push_data (CbUserStream *self,
                          const char   *data)
{
#if DEBUG
  g_debug("Pushed data: %s", data);
#endif
}