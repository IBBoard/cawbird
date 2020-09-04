/*  This file is part of Cawbird, a Gtk+ linux Twitter client forked from Corebird.
 *  Copyright (C) 2013 Timm Bäder (Corebird)
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

public class DMManager : GLib.Object {
  private unowned Account account;
  private DMThreadsModel threads_model;
  public bool empty {
    get {
      return threads_model.get_n_items () == 0;
    }
  }

  public signal void message_received (DMThread thread, int64 message_id, string text);
  public signal void thread_changed (DMThread thread);

  public DMManager.for_account (Account account) {
    this.account = account;
    this.threads_model = new DMThreadsModel ();
  }

  public void load_cached_threads () {
    account.db.select ("dm_threads")
              .cols ("user_id", "screen_name", "name", "last_message",
                     "last_message_id")
              .order ("last_message_id")
              .run ((vals) => {
      DMThread thread = new DMThread ();
      thread.user.id = int64.parse (vals[0]);
      thread.user.screen_name = vals[1];
      thread.user.user_name = vals[2];
      thread.last_message_id = int64.parse (vals[4]);
      thread.last_message = vals[3];

      threads_model.add (thread);
      return true;
    });
  }

  public GLib.ListModel get_threads_model () {
    return this.threads_model;
  }

  public bool has_thread (int64 user_id) {
    return this.threads_model.has_thread (user_id);
  }

  public bool has_dm (int64 dm_id) {
    int64 id = account.db.select ("dms")
                          .cols ("id")
                          .where_eqi ("id", dm_id)
                          .once_i64 ();
    return id == dm_id;
  }

  private bool has_dm_json (int64 dm_id) {
    int64 id = account.db.select ("dms")
                          .cols ("id")
                          .where_eqi ("id", dm_id)
                          .and ().where_eq2 ("message_json", "")
                          .once_i64 ();
    return id == dm_id;
  }

  public int reset_unread_count (int64 user_id) {
    if (!threads_model.has_thread (user_id)) {
      debug ("No thread found for user id %s", user_id.to_string ());
      return 0;
    }

    int prev_count = threads_model.reset_unread_count (user_id);

    this.thread_changed (threads_model.get_thread (user_id));

    return prev_count;
  }

  public string? reset_notification_id (int64 user_id) {
    if (!threads_model.has_thread (user_id)) {
      debug ("No thread found for user id %s", user_id.to_string ());
      return null;
    }

    return threads_model.reset_notification_id (user_id);
  }

  public async void load_newest_dms () {
  }

  public void insert_message (Json.Object dm_obj) {
    update_thread.begin (dm_obj);
  }

  private async void update_thread (Json.Object dm_obj) {
    Json.Object dm_msg = dm_obj.get_object_member ("message_create");
    int64 message_id = int64.parse(dm_obj.get_string_member ("id"));
    bool _has_json = has_dm_json (message_id);
    bool _has_dm = has_dm (message_id);

    if (_has_dm && _has_json) {
      // The API now returns all recent DMs, and we can't say "since", so we have to
      // check whether the ID exists each time
      return;
    }

    Json.Generator generator = new Json.Generator ();
    Json.Node node = new Json.Node(Json.NodeType.OBJECT);
    node.set_object (dm_obj);
    generator.set_root (node);
    string json = generator.to_data (null);

    if (_has_dm && !_has_json) {
      account.db.update ("dms")
             .val ("message_json", json)
             .where_eqi ("id", message_id)
             .run();
      return;
    }
    // Else it is new

    int64 recipient_id = int64.parse(dm_msg.get_object_member ("target").get_string_member ("recipient_id"));
    int64 sender_id  = int64.parse(dm_msg.get_string_member ("sender_id"));
    Json.Object dm_msg_data = dm_msg.get_object_member ("message_data");
    string source_text = dm_msg_data.get_string_member ("text");
    var urls = dm_msg_data.get_object_member ("entities").get_array_member ("urls");
    var url_list = new Cb.TextEntity[urls.get_length ()];
    urls.foreach_element((arr, index, node) => {
      var url = node.get_object();
      string expanded_url = url.get_string_member("expanded_url");

      Json.Array indices = url.get_array_member ("indices");
      url_list[index] = Cb.TextEntity() {
        from = (uint)indices.get_int_element (0),
        to   = (uint)indices.get_int_element (1) ,
        original_text = url.get_string_member ("url"),
        display_text = url.get_string_member ("display_url"),
        target = expanded_url.replace ("&", "&amp;"),
        tooltip_text = expanded_url
      };
    });

    string text = Cb.TextTransform.text (source_text,
                                         url_list,
                                         Cb.TransformFlags.EXPAND_LINKS,
                                         0, 0);

    string? sender_user_name = yield Twitter.get ().get_user_name (account, sender_id);
    string? sender_screen_name = yield Twitter.get ().get_screen_name (account, sender_id);
    string? recipient_user_name = yield Twitter.get ().get_user_name (account, recipient_id);
    string? recipient_screen_name = yield Twitter.get ().get_screen_name (account, recipient_id);

    int64 thread_user_id = 0;
    string? thread_screen_name = null;
    string? thread_user_name = null;

    /* User  -> Other
       Other -> User
       User  -> User */
    if (sender_id == account.id) {
      thread_user_id = recipient_id;
      thread_user_name = recipient_user_name;
      thread_screen_name = recipient_screen_name;
    } else {
      thread_user_id = sender_id;
      thread_user_name = sender_user_name;
      thread_screen_name = sender_screen_name;
    }

    if (!threads_model.has_thread (thread_user_id)) {
      DMThread thread = new DMThread ();
      thread.user.id = thread_user_id;
      thread.user.screen_name = thread_screen_name;
      thread.user.user_name = thread_user_name;
      thread.last_message = text;
      thread.last_message_id = message_id;
      this.threads_model.add (thread);

      account.db.insert ("dm_threads")
             .vali64 ("user_id", thread_user_id)
             .val ("screen_name", thread_screen_name)
             .val ("name", thread_user_name)
             .val ("last_message", text)
             .vali64 ("last_message_id", message_id)
             .run ();
    } else if (sender_id != account.id || recipient_id == account.id) {
      DMThread thread = threads_model.get_thread (sender_id);
      if (message_id > thread.last_message_id) {
        this.threads_model.update_last_message (sender_id, message_id, text);
        account.db.update ("dm_threads").val ("last_message", text)
                                        .vali64 ("last_message_id", message_id)
                                        .where_eqi ("user_id", sender_id).run ();

        this.thread_changed (thread);
      }
    }

    account.user_counter.user_seen (thread_user_id, thread_screen_name, thread_user_name);

    account.db.insert ("dms").vali64 ("id", message_id)
              .vali64 ("from_id", sender_id)
              .vali64 ("to_id", recipient_id)
              .val ("from_screen_name", sender_screen_name)
              .val ("to_screen_name", recipient_screen_name)
              .val ("from_name", sender_user_name)
              .val ("to_name", recipient_user_name)
              // Note: We now get time stamps in milliseconds from the API!
              .vali64 ("timestamp", int64.parse(dm_obj.get_string_member ("created_timestamp")) / 1000)
              .val ("text", text)
              .val ("message_json", json)
              .run ();

    /* Update unread count for the thread */
    if (sender_id != account.id && threads_model.has_thread (sender_id)) {
      DMThread thread = threads_model.get_thread (sender_id);
      threads_model.increase_unread_count (sender_id);
      this.message_received (thread, message_id, text);
      this.thread_changed (thread);
    }
  }
}
