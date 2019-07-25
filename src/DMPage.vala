/*  This file is part of corebird, a Gtk+ linux Twitter client.
 *  Copyright (C) 2013 Timm Bäder
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

[GtkTemplate (ui = "/org/baedert/corebird/ui/dm-page.ui")]
class DMPage : IPage, Cb.MessageReceiver, Gtk.Box {
  public const int KEY_SENDER_ID   = 0;
  public const int KEY_SCREEN_NAME = 1;
  public const int KEY_USER_NAME   = 2;
  public const int KEY_AVATAR_URL  = 3;

  public int unread_count                   { get { return 0; } }
  private unowned MainWindow main_window;
  public unowned MainWindow window {
    set {
      main_window = value;
    }
  }
  public unowned Account account;
  public int id                             { get; set; }
  [GtkChild]
  private Gtk.Button send_button;
  [GtkChild]
  private CompletionTextView text_view;
  [GtkChild]
  private Gtk.ListBox messages_list;
  [GtkChild]
  private ScrollWidget scroll_widget;
  private DMPlaceholderBox placeholder_box = new DMPlaceholderBox ();

  public int64 user_id;
  private int64 lowest_id = int64.MAX;
  private int64 highest_id = int64.MIN;
  private bool was_scrolled_down = false;

  public DMPage (int id, Account account) {
    this.id = id;
    this.account = account;
    send_button.sensitive = false;
    text_view.buffer.changed.connect (recalc_length);
    messages_list.set_sort_func (twitter_item_sort_func_inv);
    placeholder_box.show ();
    messages_list.set_placeholder(placeholder_box);
    text_view.size_allocate.connect (() => {
      if (was_scrolled_down)
        scroll_widget.scroll_down_next (false, false);
    });
    scroll_widget.vadjustment.value_changed.connect (() => {
      if (scroll_widget.scrolled_down) {
        this.was_scrolled_down = true;
      } else {
        this.was_scrolled_down = false;
      }
    });
  }

  public void stream_message_received (Cb.StreamMessageType type, Json.Node root) {
    // FIXME: This won't work because of how we fake-stream rather than loading old messages
    /* Writing with ourselves, we have the message already */
    /*if (this.user_id == this.account.id) {
      debug("DM to self - ignoring");
      return;
    }*/

    if (type == Cb.StreamMessageType.DIRECT_MESSAGE) {
      handle_dm (type, root);
    }
  }

  private async void handle_dm (Cb.StreamMessageType type, Json.Node root) {
    Json.Object dm_obj = root.get_object ();
    int64 dm_id = int64.parse(dm_obj.get_string_member ("id"));

    if (dm_id <= highest_id) {
      // Already seen it
      return;
    }

    highest_id = dm_id;

    Json.Object dm_msg = dm_obj.get_object_member ("message_create");
    int64 sender_id  = int64.parse(dm_msg.get_string_member ("sender_id"));
    int64 recipient_id = int64.parse(dm_msg.get_object_member ("target").get_string_member ("recipient_id"));

    /* Only handle DMs for our current chat */
    if (sender_id != this.user_id && recipient_id != this.user_id)
      return;

    Json.Object dm_msg_data = dm_msg.get_object_member ("message_data");

    var text = dm_msg_data.get_string_member ("text");
    if (dm_msg_data.has_member ("entities")) {
      var urls = dm_msg_data.get_object_member ("entities").get_array_member ("urls");
      var url_list = new Cb.TextEntity[urls.get_length ()];
      urls.foreach_element((arr, index, node) => {
        var url = node.get_object();
        string expanded_url = url.get_string_member("expanded_url");

        Json.Array indices = url.get_array_member ("indices");
        url_list[index] = Cb.TextEntity() {
          from = (uint)indices.get_int_element (0),
          to   = (uint)indices.get_int_element (1) ,
          target = expanded_url.replace ("&", "&amp;"),
          tooltip_text = expanded_url,
          display_text = url.get_string_member ("display_url")
        };
      });
      text = Cb.TextTransform.text (text,
                                    url_list,
                                    0, 0, 0);
    }

    string? sender_user_name = yield Twitter.get ().get_user_name (account, sender_id);
    string? sender_screen_name = yield Twitter.get ().get_screen_name (account, sender_id);

    if (sender_id == account.id) {
      // Find the sent entry and fill in the missing details
      var entries = messages_list.get_children ();

      foreach (var entry in entries) {
        var e = (DMListEntry) entry;
        // XXX This assumes that we only have one "-1" ID, or that we always hit them in the right order
        // It is possible for a user to send multiple DMs before we poll, though.
        if (e.user_id == account.id && e.id == -1) {
          e.text = text;
          e.id = dm_id;
          break;
        }
      }

      return;
    }
    else {
      // Add a new entry
      var new_msg = new DMListEntry ();
      new_msg.id = dm_id;
      new_msg.text = text;
      new_msg.name = sender_user_name;
      new_msg.screen_name = sender_screen_name;
      new_msg.timestamp = int64.parse(dm_obj.get_string_member ("created_timestamp")) / 1000;
      new_msg.main_window = main_window;
      new_msg.user_id = sender_id;
      new_msg.update_time_delta ();
      new_msg.load_avatar (yield Twitter.get ().get_avatar_url (account, sender_id));
      messages_list.add (new_msg);
      if (scroll_widget.scrolled_down)
        scroll_widget.scroll_down_next ();
    }
  }

  public void on_join (int page_id, Cb.Bundle? args) {
    int64 user_id = args.get_int64 (KEY_SENDER_ID);
    if (user_id == 0)
      return;

    this.lowest_id = int64.MAX;
    this.user_id = user_id;
    string screen_name;
    string name = null;
    if ((screen_name = args.get_string (KEY_SCREEN_NAME)) != null) {
      name = args.get_string (KEY_USER_NAME);
      placeholder_box.user_id = user_id;
      placeholder_box.screen_name = screen_name;
      placeholder_box.name = name;
      placeholder_box.avatar_url = args.get_string (KEY_AVATAR_URL);
      placeholder_box.load_avatar ();
    }

    text_view.set_account (this.account);

    // Clear list
    messages_list.foreach ((w) => {messages_list.remove (w);});

    // Update unread count
    DMThreadsPage threads_page = ((DMThreadsPage)main_window.get_page (Page.DM_THREADS));
    threads_page.adjust_unread_count_for_user_id (user_id);

    var now = new GLib.DateTime.now_local ();
    // Load messages
    var query = account.db.select ("dms")
                           .cols ("from_id", "to_id", "text", "from_name", "from_screen_name",
                                  "timestamp", "id");
    if (user_id == account.id)
      query.where (@"`from_id`='$user_id' AND `to_id`='$user_id'");
    else
      query.where (@"`from_id`='$user_id' OR `to_id`='$user_id'");

    query.order ("timestamp DESC")
         .limit (35)
         .run ((vals) => {
      int64 id = int64.parse (vals[6]);
      if (id < lowest_id)
        lowest_id = id;

      var entry = new DMListEntry ();
      entry.id = id;
      entry.user_id = int64.parse (vals[0]);
      entry.timestamp = int64.parse (vals[5]);
      entry.text = vals[2];
      entry.name = vals[3];
      name = vals[3];
      entry.screen_name = vals[4];
      screen_name = vals[4];
      entry.main_window = main_window;
      entry.update_time_delta (now);
      Twitter.get ().load_avatar_for_user_id.begin (account,
                                                    entry.user_id,
                                                    48 * this.get_scale_factor (),
                                                    (obj, res) => {
        Cairo.Surface? s = Twitter.get ().load_avatar_for_user_id.end (res);
        entry.avatar = s;
      });
      messages_list.add (entry);
      return true;
    });

    account.user_counter.user_seen (user_id, screen_name, name);

    scroll_widget.scroll_down_next (false, true);

    // Focus the text entry
    text_view.grab_focus ();
  }

  public void on_leave () {}

  [GtkCallback]
  private void send_button_clicked_cb () {
    if (text_view.buffer.text.length == 0)
      return;

    // Withdraw the notification if there is one
    DMThreadsPage threads_page = ((DMThreadsPage)main_window.get_page (Page.DM_THREADS));
    string notification_id = threads_page.get_notification_id_for_user_id (this.user_id);
    if (notification_id != null)
      GLib.Application.get_default ().withdraw_notification (notification_id);


    // Just add the entry now
    DMListEntry entry = new DMListEntry ();
    entry.id = -1;
    entry.user_id = account.id;
    entry.screen_name = account.screen_name;
    entry.timestamp = new GLib.DateTime.now_local ().to_unix ();
    entry.text = GLib.Markup.escape_text (text_view.buffer.text);
    entry.main_window = main_window;
    entry.name = account.name;
    entry.avatar = account.avatar;
    entry.update_time_delta ();
    messages_list.add (entry);

    var gen = new Json.Generator();
    var root = new Json.Node(Json.NodeType.OBJECT);
    var object = new Json.Object();
    root.set_object(object);
    gen.set_root(root);
    var event = new Json.Object();
    object.set_object_member("event", event);
    event.set_string_member("type", "message_create");
    var msg_create = new Json.Object();
    event.set_object_member("message_create", msg_create);
    var target = new Json.Object();
    msg_create.set_object_member("target", target);
    target.set_string_member("recipient_id", user_id.to_string());
    var msg_data = new Json.Object();
    msg_create.set_object_member("message_data", msg_data);
    msg_data.set_string_member("text", text_view.buffer.text);
    string json_dump = gen.to_data (null);

    var call = new OAuthProxyCallWithBody(account.proxy, json_dump);
    call.set_function ("1.1/direct_messages/events/new.json");
    call.set_method ("POST");

    call.invoke_async.begin (null, (obj, res) => {
      try {
        call.invoke_async.end (res);
      } catch (GLib.Error e) {
        Utils.show_error_object (call.get_payload (), e.message,
                                 GLib.Log.LINE, GLib.Log.FILE, this.main_window);
        return;
      }
    });

    // clear the text entry
    text_view.buffer.text = "";

    // Scroll down
    if (scroll_widget.scrolled_down)
      scroll_widget.scroll_down_next ();
  }

  [GtkCallback]
  private bool text_view_key_press_cb (Gdk.EventKey evt) {
    if (evt.keyval == Gdk.Key.Return &&
        (evt.state & Gdk.ModifierType.CONTROL_MASK) == Gdk.ModifierType.CONTROL_MASK) {
      send_button_clicked_cb ();
      return Gdk.EVENT_STOP;
    }

    return Gdk.EVENT_PROPAGATE;
  }

  private void recalc_length () {
    uint text_length = text_view.buffer.text.length;
    // TODO: Re-enable send button when we have new API sending working!
    send_button.sensitive = text_length > 0;
  }


  public string get_title () {
    return _("Direct Conversation");
  }

  public void create_radio_button (Gtk.RadioButton? group) {}
  public Gtk.RadioButton? get_radio_button() {return null;}
}
