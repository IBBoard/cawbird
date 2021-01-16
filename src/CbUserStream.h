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

#ifndef __CB_USER_STREAM_H__
#define __CB_USER_STREAM_H__

#include <glib-object.h>
#include <rest/oauth-proxy.h>
#include <rest/rest-proxy.h>
#include "CbMessageReceiver.h"
#include "CbTypes.h"

G_BEGIN_DECLS

#define CB_TYPE_USER_STREAM (cb_user_stream_get_type ())
G_DECLARE_FINAL_TYPE (CbUserStream, cb_user_stream, CB, USER_STREAM, GObject);

struct _CbUserStream
{
  GObject parent_instance;

  GPtrArray *receivers;
  RestProxy *proxy;
  GNetworkMonitor *network_monitor;

  guint network_timeout_id;
  guint heartbeat_timeout_id;
  guint network_changed_id;

  gint64 last_home_id;
  guint timeline_timeout;
  GCancellable *home_cancellable;

  gint64 last_mentions_id;
  guint mentions_timeout;
  GCancellable *mentions_cancellable;

  gint64 last_favourited_id;
  guint favourited_timeout;
  GCancellable *favourited_cancellable;

  gint64 first_dm_id;
  gint64 last_dm_id;
  gint64 new_last_dm_id; // Placeholder for the next value of last_dm_id so that we can page back if lots of tweets came in
  unsigned char dm_recursions;
  guint dm_timeout;
  GCancellable *dm_cancellable;

  char *account_name;

  guint state;
  guint restarting : 1;
  guint proxy_data_set : 1;
  guint network_available: 1;
};
typedef struct _CbUserStream      CbUserStream;

CbUserStream * cb_user_stream_new            (const char *account_name,
                                              OAuthProxy *proxy);
void           cb_user_stream_set_proxy_data (CbUserStream *self,
                                              const char   *token,
                                              const char   *token_secret);
void           cb_user_stream_register       (CbUserStream      *self,
                                              CbMessageReceiver *receiver);
void           cb_user_stream_unregister     (CbUserStream      *self,
                                              CbMessageReceiver *receiver);
void           cb_user_stream_start          (CbUserStream *self);
void           cb_user_stream_stop           (CbUserStream *self);
void           cb_user_stream_push_data      (CbUserStream *self,
                                              const char   *data);
void           cb_user_stream_inject_tweet   (CbUserStream *self,
                                            CbStreamMessageType  message_type,
                                            const gchar *content)

G_END_DECLS;

#endif
