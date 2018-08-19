/*  This file is part of corebird, a Gtk+ linux Twitter client.
 *  Copyright (C) 2017 Timm Bäder
 *
 *  corebird is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  corebird is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with corebird.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "CbUserStream.h"
#include "CbUtils.h"
#include "rest/rest/oauth-proxy.h"
#include <string.h>

G_DEFINE_TYPE (CbUserStream, cb_user_stream, G_TYPE_OBJECT);


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
      self->proxy = oauth_proxy_new ("0rvHLdbzRULZd5dz6X1TUA",
                                     "oGrvd6654nWLhzLcJywSW3pltUfkhP4BnraPPVNhHtY",
                                     "https://api.twitter.com/",
                                     FALSE);
    }
  else
    {
      /* TODO: We should be getting these from the settings */
      self->proxy = oauth_proxy_new ("0rvHLdbzRULZd5dz6X1TUA",
                                     "oGrvd6654nWLhzLcJywSW3pltUfkhP4BnraPPVNhHtY",
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
      g_warning ("%s: %s", __FUNCTION__, error->message);
      //g_warning ("\n%s\n", data);
      return;
    }

  root_arr = json_node_get_array (root_node);
  len = json_array_get_length (root_arr);

  g_debug ("Got %d timeline tweets", len);

  for (guint i = len; i > 0; i--) {
    JsonNode *node = json_array_get_element (root_arr, i - 1);
    JsonObject *obj = json_node_get_object (node);
    self->last_home_id = json_object_get_int_member (obj, "id");
    stream_tweet(self, CB_STREAM_MESSAGE_TWEET, node);
  }

  g_cancellable_cancel(self->home_cancellable);
  self->home_cancellable = NULL;
}

gboolean
load_timeline_tweets (gpointer user_data)
{
  CbUserStream *self = user_data;

  if (self->home_cancellable && ! g_cancellable_is_cancelled(self->home_cancellable)) {
    g_debug ("Cancelling existing cancellable");
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

  if (!is_first_load) {
    //g_debug("Calling %s?since_id=%lld", this.function, tweet_list.model.max_id);
    char since_id [20];
    sprintf(since_id, "%ld", self->last_home_id);
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
      g_warning ("%s: %s", __FUNCTION__, error->message);
      //g_warning ("\n%s\n", data);
      return;
    }

  root_arr = json_node_get_array (root_node);
  len = json_array_get_length (root_arr);

  g_debug ("Got %d mention tweets", len);

  for (guint i = len; i > 0; i--) {
    JsonNode *node = json_array_get_element (root_arr, i - 1);
    JsonObject *obj = json_node_get_object (node);
    self->last_mentions_id = json_object_get_int_member (obj, "id");
    stream_tweet(self, CB_STREAM_MESSAGE_MENTION, node);
  }

  g_cancellable_cancel(self->mentions_cancellable);
  self->mentions_cancellable = NULL;
}

gboolean
load_mentions_tweets (gpointer user_data)
{
  CbUserStream *self = user_data;

  if (self->mentions_cancellable && ! g_cancellable_is_cancelled(self->mentions_cancellable)) {
    g_debug ("Cancelling existing cancellable");
    g_cancellable_cancel(self->mentions_cancellable);
  }

  gboolean is_first_load = self->last_mentions_id == 0;
  char* requested_tweet_count = is_first_load ? "28" : "200";
  RestProxyCall *proxy_call = rest_proxy_new_call (self->proxy);
  g_debug("Loading mention tweets");
  rest_proxy_call_set_function (proxy_call, "1.1/statuses/mentions_timeline.json");
  rest_proxy_call_set_method (proxy_call, "GET");
  rest_proxy_call_add_param (proxy_call, "count", requested_tweet_count);
  rest_proxy_call_add_param (proxy_call, "include_entities", "true");

  if (!is_first_load) {
    //g_debug("Calling %s?since_id=%lld", this.function, tweet_list.model.max_id);
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
      g_warning ("%s: %s", __FUNCTION__, error->message);
      //g_warning ("\n%s\n", data);
      return;
    }

  root_arr = json_node_get_array (root_node);
  len = json_array_get_length (root_arr);

  g_debug ("Got %d favourited tweets", len);

  for (guint i = len; i > 0; i--) {
    JsonNode *node = json_array_get_element (root_arr, i - 1);
    JsonObject *obj = json_node_get_object (node);
    self->last_favourited_id = json_object_get_int_member (obj, "id");
    stream_tweet(self, CB_STREAM_MESSAGE_EVENT_FAVORITE, node);
  }

  g_cancellable_cancel(self->favourited_cancellable);
  self->favourited_cancellable = NULL;
}

gboolean
load_favourited_tweets (gpointer user_data)
{
  CbUserStream *self = user_data;

  if (self->favourited_cancellable && ! g_cancellable_is_cancelled(self->favourited_cancellable)) {
    g_debug ("Cancelling existing cancellable");
    g_cancellable_cancel(self->favourited_cancellable);
  }

  gboolean is_first_load = self->last_favourited_id == 0;
  char* requested_tweet_count = is_first_load ? "28" : "200";
  RestProxyCall *proxy_call = rest_proxy_new_call (self->proxy);
  g_debug("Loading mention tweets");
  rest_proxy_call_set_function (proxy_call, "1.1/favorites/list.json");
  rest_proxy_call_set_method (proxy_call, "GET");
  rest_proxy_call_add_param (proxy_call, "count", requested_tweet_count);
  rest_proxy_call_add_param (proxy_call, "include_entities", "true");

  if (!is_first_load) {
    //g_debug("Calling %s?since_id=%lld", this.function, tweet_list.model.max_id);
    char since_id [20];
    sprintf(since_id, "%ld", self->last_favourited_id);
    rest_proxy_call_add_param(proxy_call, "since_id", since_id);
  }

  self->favourited_cancellable = g_cancellable_new();
  cb_utils_load_threaded_async (proxy_call, self->favourited_cancellable, load_favourited_tweets_done, self);
  return TRUE;
}

void
cb_user_stream_start (CbUserStream *self)
{
  if (!self->timeline_timeout) {
    g_debug("Loading timeline tweets on start");
    load_timeline_tweets (self);
    g_debug("Adding timeout for timeline");
    self->timeline_timeout = g_timeout_add_seconds_full (G_PRIORITY_DEFAULT, 60 * 2, load_timeline_tweets, self, NULL);
  }
  if (!self->mentions_timeout) {
    g_debug("Loading mention tweets on start");
    load_mentions_tweets (self);
    g_debug("Adding timeout for mentions");
    self->mentions_timeout = g_timeout_add_seconds_full (G_PRIORITY_DEFAULT, 60 * 2, load_mentions_tweets, self, NULL);
  }
  if (!self->favourited_timeout) {
    g_debug("Loading mention tweets on start");
    load_favourited_tweets (self);
    g_debug("Adding timeout for mentions");
    self->favourited_timeout = g_timeout_add_seconds_full (G_PRIORITY_DEFAULT, 60 * 2, load_favourited_tweets, self, NULL);
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