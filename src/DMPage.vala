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

[GtkTemplate (ui = "/uk/co/ibboard/cawbird/ui/dm-page.ui")]
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
  private bool was_scrolled_down = false;
  private uint update_time_delta_timeout = 0;

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
    if (type == Cb.StreamMessageType.DIRECT_MESSAGE) {
      handle_dm.begin (type, root);
    }
  }

  private bool has_dm (int64 dm_id) {
    bool found = false;
    List<weak Gtk.Widget> dm_entries = messages_list.get_children ();
    uint length = dm_entries.length ();
    unowned List<weak Gtk.Widget> current = dm_entries.last ();

    for (uint i = 0; i < length; i++) {
      if (((DMListEntry)current.data).id == dm_id) {
        found = true;
        break;
      }

      current = current.nth_prev (1);
    }

    return found;
  }

  private async void handle_dm (Cb.StreamMessageType type, Json.Node root) {
    Json.Object dm_obj = root.get_object ();
    int64 dm_id = int64.parse(dm_obj.get_string_member ("id"));

    if (has_dm (dm_id)) {
      return;
    }

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
          original_text = url.get_string_member ("url"),
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
    int64 timestamp = int64.parse(dm_obj.get_string_member ("created_timestamp")) / 1000;
    yield add_entry (dm_id, sender_id, recipient_id, text, sender_user_name, sender_screen_name, timestamp);
  }

  private async void add_entry (int64 dm_id, int64 sender_id, int64 recipient_id,
                          string text,
                          string sender_user_name, string sender_screen_name,
                          int64 timestamp) {
    var new_msg = new DMListEntry ();
    new_msg.id = dm_id;
    new_msg.text = text;
    new_msg.name = sender_user_name;
    new_msg.screen_name = sender_screen_name;
    new_msg.timestamp = timestamp;
    new_msg.main_window = main_window;
    new_msg.user_id = sender_id;
    new_msg.update_time_delta ();
    new_msg.load_avatar (yield Twitter.get ().get_avatar_url (account, sender_id));
    messages_list.add (new_msg);

    if (scroll_widget.scrolled_down)
      scroll_widget.scroll_down_next ();
  }

  public void on_join (int page_id, Cb.Bundle? args) {
    int64 user_id = args.get_int64 (KEY_SENDER_ID);
    if (user_id == 0)
      return;

    this.user_id = user_id;
    string screen_name;
    string name = null;
    if ((screen_name = args.get_string (KEY_SCREEN_NAME)) != null) {
      // If the screen name is set then it's a new conversation
      // So show the placeholder with name and avatar
      name = args.get_string (KEY_USER_NAME);
      placeholder_box.user_id = user_id;
      placeholder_box.screen_name = screen_name;
      placeholder_box.name = name;
      placeholder_box.avatar_url = args.get_string (KEY_AVATAR_URL);
      placeholder_box.load_avatar ();
    }

    messages_list.get_accessible().set_name(_("Direct messages with %s").printf(name));
    messages_list.get_accessible().set_description(_("Direct messages with %s").printf(name));

    text_view.set_account (this.account);

    // Clear list
    messages_list.foreach ((w) => {messages_list.remove (w);});

    // Update unread count
    DMThreadsPage threads_page = ((DMThreadsPage)main_window.get_page (Page.DM_THREADS));
    threads_page.adjust_unread_count_for_user_id (user_id);

    // Load messages
    var query = account.db.select ("dms")
                           .cols ("from_id", "to_id", "text", "message_json",
                                  "from_name", "from_screen_name",
                                  "timestamp", "id");
    if (user_id == account.id)
      query.where (@"`from_id`='$user_id' AND `to_id`='$user_id'");
    else
      query.where (@"`from_id`='$user_id' OR `to_id`='$user_id'");

    query.order ("timestamp DESC")
         .limit (35)
         .run ((vals) => {
      int64 id = int64.parse (vals[7]);      
      string json = vals[3];

      if (json != "") {
        try {
          Json.Parser parser = new Json.Parser ();
          parser.load_from_data (json);
          Json.Node node = parser.get_root ();
          debug("Adding DM from JSON");
          handle_dm.begin(Cb.StreamMessageType.DIRECT_MESSAGE, node);
        } catch (Error e) {
          warning ("Unable to parse the DM json string: %s\n", e.message);
        }
      } else {
        debug("Adding DM from text");
        add_entry.begin (id, int64.parse (vals[0]), int64.parse (vals[1]), vals[2], vals[4], vals[5], int64.parse (vals[6]));
      }
      name = vals[3];
      screen_name = vals[4];
      return true;
    });
    
    account.user_counter.user_seen (user_id, screen_name, name);

    scroll_widget.scroll_down_next (false, true);

    // Focus the text entry
    text_view.grab_focus ();

    if (this.update_time_delta_timeout != 0) {
      GLib.Source.remove(this.update_time_delta_timeout);
    }

    this.update_time_delta_timeout = GLib.Timeout.add(1000 * 60, () => { 
      messages_list.get_children().foreach((dm_list_entry) => {
        ((DMListEntry)dm_list_entry).update_time_delta();
      });
      return GLib.Source.CONTINUE;
    });
  }

  public void on_leave () {
    if (this.update_time_delta_timeout != 0) {
      GLib.Source.remove(this.update_time_delta_timeout);
      this.update_time_delta_timeout = 0;
    }
  }

  [GtkCallback]
  private void send_button_clicked_cb () {
    if (text_view.buffer.text.length == 0)
      return;

    send_button.sensitive = false;
    // Withdraw the notification if there is one
    DMThreadsPage threads_page = ((DMThreadsPage)main_window.get_page (Page.DM_THREADS));
    string notification_id = threads_page.get_notification_id_for_user_id (this.user_id);
    if (notification_id != null)
      GLib.Application.get_default ().withdraw_notification (notification_id);

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
        send_button.sensitive = true;
        call.invoke_async.end (res);
      } catch (GLib.Error e) {
        Utils.show_error_dialog (TweetUtils.failed_request_to_error (call, e), this.main_window);
        return;
      }

      unowned string back = call.get_payload();
      account.user_stream.inject_tweet (Cb.StreamMessageType.DIRECT_MESSAGE, back);
      text_view.buffer.text = "";
    });
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
