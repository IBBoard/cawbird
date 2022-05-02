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
  private unowned Gtk.Button send_button;
  [GtkChild]
  private unowned CompletionTextView text_view;
  [GtkChild]
  private unowned Gtk.ListBox messages_list;
  [GtkChild]
  private unowned ScrollWidget scroll_widget;
  [GtkChild]
  private unowned Gtk.Stack action_stack;
  [GtkChild]
  private unowned Gtk.Box reply_box;
  [GtkChild]
  private unowned Gtk.Button delete_button;
  [GtkChild]
  private unowned ComposeImageManager compose_image_manager;
  [GtkChild]
  private unowned Gtk.Button add_media_button;
  [GtkChild]
  private unowned FavImageView fav_image_view;
  [GtkChild]
  private unowned Gtk.Button fav_image_button;
  [GtkChild]
  private unowned Gtk.Box add_button_box;
  [GtkChild]
  private unowned Gtk.Label image_error_label;
  private Cb.EmojiChooser? emoji_chooser = null;
  private Gtk.Button? emoji_button = null;
  private GLib.Cancellable? cancellable;
  private DMPlaceholderBox placeholder_box = new DMPlaceholderBox ();
  
  private int64 first_dm_id;
  public int64 user_id;
  private string user_name;
  private string screen_name;
  private bool was_scrolled_down = false;
  private bool first_load = true;
  private uint update_time_delta_timeout = 0;
  private MediaUpload media_upload;

  public DMPage (int id, Account account) {
    this.id = id;
    this.account = account;
    this.cancellable = new GLib.Cancellable();
    send_button.sensitive = false;
    text_view.buffer.changed.connect (set_send_sensitive_state);
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
    scroll_widget.scrolled_to_start.connect((value) => {
      load_dms.begin();
    });
    compose_image_manager.max_images = 1;

    var upload_proxy = new Rest.OAuthProxy (account.proxy.consumer_key,
                                            account.proxy.consumer_secret,
                                            "https://upload.twitter.com/",
                                            false);
    upload_proxy.token = account.proxy.token;
    upload_proxy.token_secret = account.proxy.token_secret;
    compose_image_manager.proxy = upload_proxy;

    compose_image_manager.image_removed.connect ((uuid) => {
      media_upload = null;
      this.add_media_button.sensitive = true;
      this.fav_image_button.sensitive = true;
      this.compose_image_manager.hide ();
      set_send_sensitive_state();
    });
    compose_image_manager.image_reloaded.connect ((upload) => {
      if (upload.cancellable != null) {
        upload.cancellable.cancel();
      }
      TweetUtils.upload_media.begin (upload, account, null);
      set_send_sensitive_state();
    });

    text_view.paste_clipboard.connect(() => {
      var clipboard = get_clipboard(Gdk.SELECTION_CLIPBOARD);

      if (clipboard.wait_is_image_available ()) {
        process_image_clipboard(clipboard);
        Signal.stop_emission_by_name (text_view, "paste-clipboard");
      }
      else if (clipboard.wait_is_uris_available ()) {
        process_uri_clipboard(clipboard);
        Signal.stop_emission_by_name (text_view, "paste-clipboard");
      }
      // Else it is text and we can let it happen
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
    string? sender_user_name = yield Twitter.get ().get_user_name (account, sender_id);
    string? sender_screen_name = yield Twitter.get ().get_screen_name (account, sender_id);
    int64 timestamp = int64.parse(dm_obj.get_string_member ("created_timestamp")) / 1000;
    yield add_entry (dm_id, sender_id, text, sender_user_name, sender_screen_name, dm_msg_data, timestamp);
  }

  private async void add_entry (int64 dm_id, int64 sender_id, string text,
                          string sender_user_name, string sender_screen_name,
                          Json.Object? message_data,
                          int64 timestamp) {
    var new_msg = create_list_entry(dm_id, sender_id, text, sender_user_name, sender_screen_name, message_data, timestamp);
    messages_list.add (new_msg);

    if (dm_id < first_dm_id) {
      first_dm_id = dm_id;
    }

    if (scroll_widget.scrolled_down) {
      scroll_widget.scroll_down_next ();
    }
    else {
      scroll_widget.balance_next_upper_change (TOP);
    }
  }

  private DMListEntry create_list_entry(int64 dm_id, int64 sender_id, string text,
                                        string sender_user_name, string sender_screen_name,
                                        Json.Object? message_data,
                                        int64 timestamp) {
    Cb.TextEntity[] entities;
    Cb.Media? media = null;

    if (message_data != null && message_data.has_member ("entities")) {
      var entity_nodes = message_data.get_object_member ("entities");
      var url_nodes = entity_nodes.get_array_member ("urls");
      var hashtag_nodes = entity_nodes.get_array_member ("hashtags");
      var user_mention_nodes = entity_nodes.get_array_member("user_mentions");
      entities = new Cb.TextEntity[url_nodes.get_length () + hashtag_nodes.get_length() + user_mention_nodes.get_length()];
      url_nodes.foreach_element((arr, index, node) => {
        var url = node.get_object();
        string expanded_url = url.get_string_member("expanded_url");
        Json.Array indices = url.get_array_member ("indices");
        entities[index] = Cb.TextEntity() {
          from = (uint)indices.get_int_element (0),
          to   = (uint)indices.get_int_element (1) ,
          target = expanded_url.replace ("&", "&amp;"),
          original_text = url.get_string_member ("url"),
          tooltip_text = expanded_url,
          display_text = url.get_string_member ("display_url")
        };
      });
      var offset = url_nodes.get_length();      
      hashtag_nodes.foreach_element((arr, index, node) => {
        var hashtag = node.get_object();
        Json.Array indices = hashtag.get_array_member ("indices");
        var hashtag_text = "#%s".printf(hashtag.get_string_member("text"));
        entities[offset + index] = Cb.TextEntity() {
          from = (uint)indices.get_int_element (0),
          to   = (uint)indices.get_int_element (1) ,
          target = null,
          original_text = hashtag_text,
          tooltip_text = hashtag_text,
          display_text = hashtag_text
        };
      });
      offset += hashtag_nodes.get_length();      
      user_mention_nodes.foreach_element((arr, index, node) => {
        var user_mention = node.get_object();
        Json.Array indices = user_mention.get_array_member ("indices");
        var mention_screen_name = "@%s".printf(user_mention.get_string_member("screen_name"));
        var id_str = user_mention.get_string_member("id_str");
        entities[offset + index] = Cb.TextEntity() {
          from = (uint)indices.get_int_element (0),
          to   = (uint)indices.get_int_element (1) ,
          target = "@%s/%s".printf(id_str, mention_screen_name),
          original_text = mention_screen_name,
          tooltip_text = user_mention.get_string_member("name"),
          display_text = mention_screen_name
        };
      });

      if (entities.length > 1) {
        var swapped = false;

        do {
          swapped = false;
          for (int i = 0; i < entities.length - 1; i++) {
            int j = i + 1;
            if (entities[j].from < entities[i].from) {
              Cb.TextEntity tmp = entities[i];
              entities[i] = entities[j];
              entities[j] = tmp;
              swapped = true;
            }
          }
        } while (swapped);
      }
    }
    else {
      entities = new Cb.TextEntity[0];
    }
    
    if (message_data != null && message_data.has_member("attachment")) {
      var attachment = message_data.get_object_member("attachment");
      if (attachment.get_string_member("type") == "media") {
        var media_node = attachment.get_object_member("media");
        media = new Cb.Media();
        
        var media_type = media_node.get_string_member("type");
        var url = media_node.get_string_member("media_url_https");

        var sizes = media_node.get_object_member("sizes");

        var small_size = sizes.get_object_member("small");
        media.thumb_width = (int)small_size.get_int_member("w");
        media.thumb_height = (int)small_size.get_int_member("h");
        media.thumb_url = "%s:small".printf(url);

        var large_size = sizes.get_object_member("large");
        media.thumb_width = (int)large_size.get_int_member("w");
        media.thumb_height = (int)large_size.get_int_member("h");

        if (media_node.has_member("ext_alt_text")) {
          media.alt_text = media_node.get_string_member("ext_alt_text");
        }
        
        if (media_type == "photo") {
          media.target_url = "%s:orig".printf(url);
          media.url = "%s:large".printf(url);
          media.type = Cb.MediaType.IMAGE;
        }
        else if (media_type == "video" || media_type == "animated_gif") {
          if (media.alt_text == null && media_node.has_member("additional_media_info")) {
            var additional_media_info = media_node.get_object_member("additional_media_info");
            if (additional_media_info.has_member("title") && additional_media_info.has_member("description")) {
              media.alt_text = "%s\n\n%s".printf(additional_media_info.get_string_member("title"),
                                                 additional_media_info.get_string_member("description"))
                                         .strip();
            }
          }
          Json.Object? variant = null;
          Json.Array variants = media_node.get_object_member("video_info").get_array_member("variants");
          uint variant_count = variants.get_length();
          for (int i = 0; i < variant_count; i++) {
            var media_variant = variants.get_object_element(i);
            if (media_variant.get_string_member("content_type") == "application/x-mpegURL") {
              variant = media_variant;
              media.target_url = media_node.get_string_member("expanded_url");
              break;
            }
          }
          if (variant == null && variant_count > 0) {
            variant = variants.get_object_element(0);
          }
          if (variant != null) {
            media.url = variant.get_string_member("url");
            media.type = Cb.MediaType.TWITTER_VIDEO;
          }
          else {
            // It all went wrong, so trash the object
            media = null;
          }
        }
        else {
          media = null;
        }
      }

      if (media != null) {
        if (media.url.has_prefix("https://ton.twitter.com/")) {
          media.consumer_key = account.proxy.consumer_key;
          media.consumer_secret = account.proxy.consumer_secret;
          media.token = account.proxy.token;
          media.token_secret = account.proxy.token_secret;
        }
        Cb.MediaDownloader.get_default().load_async.begin (media);
      }
    }
    var new_msg = new DMListEntry ();
    new_msg.id = dm_id;
    new_msg.text = text;
    new_msg.name = sender_user_name;
    new_msg.screen_name = sender_screen_name;
    new_msg.timestamp = timestamp;
    new_msg.main_window = main_window;
    new_msg.user_id = sender_id;
    new_msg.media = media;
    new_msg.message_data = message_data;
    new_msg.set_entities(entities);
    new_msg.update_time_delta ();
    new_msg.avatar_clicked.connect(() => {
      if (has_checked_items()) {
        action_stack.visible_child = delete_button;
      }
      else {
        action_stack.visible_child = reply_box;
      }
    });
    Twitter.get ().get_avatar_url.begin (account, sender_id, (obj, res) => {
      new_msg.load_avatar (Twitter.get ().get_avatar_url.end(res));
    });
    return new_msg;
  }

  public void on_join (int page_id, Cb.Bundle? args) {
    int64 user_id = args.get_int64 (KEY_SENDER_ID);
    if (user_id == 0)
      return;

    if (first_load) {
      setup_emoji_chooser ();
      first_load = false;
    }

    media_upload = null;
    image_error_label.visible = false;
    first_dm_id = int64.MAX;
    this.user_id = user_id;
    if ((screen_name = args.get_string (KEY_SCREEN_NAME)) != null) {
      // If the screen name is set then it's a new conversation
      // So show the placeholder with name and avatar
      user_name = args.get_string (KEY_USER_NAME);
      placeholder_box.user_id = user_id;
      placeholder_box.screen_name = screen_name;
      placeholder_box.name = name;
      placeholder_box.avatar_url = args.get_string (KEY_AVATAR_URL);
      placeholder_box.load_avatar ();
    }

    messages_list.get_accessible().set_name(_("Direct messages with %s").printf(user_name));
    messages_list.get_accessible().set_description(_("Direct messages with %s").printf(user_name));

    text_view.set_account (this.account);

    // Clear list
    messages_list.foreach ((w) => {messages_list.remove (w);});

    // Update unread count
    DMThreadsPage threads_page = ((DMThreadsPage)main_window.get_page (Page.DM_THREADS));
    threads_page.adjust_unread_count_for_user_id (user_id);

    load_dms.begin((obj, res) => {
      load_dms.end(res);

      messages_list.get_accessible().set_name(_("Direct messages with %s").printf(user_name));
      messages_list.get_accessible().set_description(_("Direct messages with %s").printf(user_name));

      account.user_counter.user_seen (user_id, screen_name, user_name);

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
    });

    action_stack.visible_child = reply_box;
  }

  private async void load_dms() {
    // Load messages
    var query = account.db.select ("dms")
                           .cols ("from_id", "to_id", "text", "message_json",
                                  "from_name", "from_screen_name",
                                  "timestamp", "id");
    var dm_is_in_thread = "";
    if (user_id == account.id) {
      dm_is_in_thread = @"(`from_id`='$user_id' AND `to_id`='$user_id')";
    }
    else {
      dm_is_in_thread = @"(`from_id`='$user_id' OR `to_id`='$user_id')";
    }

    if (first_dm_id != int64.MAX) {
      query.where_lt("id", first_dm_id).and().where(dm_is_in_thread);
    }
    else {
      query.where(dm_is_in_thread);
    }

    string[,] values = new string[35,8];
    int row_num = 0;

    // We can't `yield` async methods in the callback
    // so load DMs in order by loading into memory and then parsing/adding
    query.order ("timestamp DESC")
         .limit (35)
         .run ((vals) => {
           for (int i = 0; i < vals.length; i++) {
             values[row_num,i] = vals[i];
            }
            row_num++;
           return true;
         });

    for (int i = 0; i < row_num; i++) {
      int64 id = int64.parse (values[i,7]);
      string json = values[i,3];

      if (json != "") {
        try {
          Json.Parser parser = new Json.Parser ();
          parser.load_from_data (json);
          Json.Node node = parser.get_root ();
          yield handle_dm(Cb.StreamMessageType.DIRECT_MESSAGE, node);
        } catch (Error e) {
          warning ("Unable to parse the DM json string: %s\n", e.message);
        }
      } else {
        yield add_entry (id, int64.parse (values[i,0]), values[i,2], values[i,4], values[i,5], null, int64.parse (values[i,6]));
      }
      if (user_name == null) {
        user_name = values[i,3];
      }
      if (screen_name == null) {
        screen_name = values[i,4];
      }
    }
  }

  public void on_leave () {
    if (this.update_time_delta_timeout != 0) {
      GLib.Source.remove(this.update_time_delta_timeout);
      this.update_time_delta_timeout = 0;
    }
  }

  [GtkCallback]
  private void send_button_clicked_cb () {
    if (text_view.buffer.text.length == 0 && compose_image_manager.n_images == 0)
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
    if (media_upload != null) {
      var attachment = new Json.Object();
      msg_data.set_object_member("attachment", attachment);      
      attachment.set_string_member("type", "media");
      var media = new Json.Object();
      attachment.set_object_member("media", media);
      media.set_int_member("id", media_upload.media_id);
    }
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
      compose_image_manager.clear();
      compose_image_manager.hide();
      media_upload = null;
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

  private void set_send_sensitive_state() {
    uint text_length = text_view.buffer.text.length;
    send_button.sensitive = (text_length > 0 && media_upload == null) || (media_upload != null && media_upload.is_uploaded());
  }

  private bool has_checked_items () {
    var dm_messages = messages_list.get_children();
    // Assume the user is deleting recent messages and keeping older content, so work from the bottom up
    dm_messages.reverse();
    foreach (Gtk.Widget widget in dm_messages) {
      if (widget is DMListEntry) {
        var dm_message_entry = (DMListEntry)widget;
        if (dm_message_entry.is_checked) {
          return true;
        }
      }
    }

    return false;
  }

  [GtkCallback]
  private void delete_button_clicked_cb (Gtk.Button button) {
    delete_button.sensitive = false;
    var deletable_widgets = new GLib.GenericArray<DMListEntry>();
    messages_list.foreach((widget) => {
      if (widget is DMListEntry) {
        var dm_message_entry = (DMListEntry)widget;
        if (dm_message_entry.is_checked) {
          deletable_widgets.add(dm_message_entry);
        }
      }
    });
    var collect_obj = new Collect(deletable_widgets.length);
    collect_obj.finished.connect((e) => {
      if (e != null) {
        Utils.show_error_dialog (e, this.main_window);
      }
      delete_button.sensitive = true;
      action_stack.visible_child = reply_box;
    });
    deletable_widgets.foreach((dm_message_entry) => {
      delete_dm(dm_message_entry, collect_obj);
    });
  }

  private void delete_dm(DMListEntry dm_message_entry, Collect collect_obj) {
    dm_message_entry.sensitive = false;
    var call = new OAuthProxyCallWithQueryString(account.proxy);
    call.set_function ("1.1/direct_messages/events/destroy.json");
    call.set_method ("DELETE");
    call.add_param("id", dm_message_entry.id.to_string());
    call.invoke_async.begin(null, (obj, res) => {
      try {
        call.invoke_async.end (res);
        collect_obj.emit();
        account.db.delete("dms").where_eqi("id", dm_message_entry.id).run();
        messages_list.remove(dm_message_entry);
      } catch (GLib.Error e) {
        var err = TweetUtils.failed_request_to_error (call, e);
        if (err.code == 34) {
          // Already deleted
          collect_obj.emit();
          account.db.delete("dms").where_eqi("id", dm_message_entry.id).run();
          messages_list.remove(dm_message_entry);
          return;
        }
        dm_message_entry.sensitive = true;
        dm_message_entry.is_checked = false;
        collect_obj.emit(err);
        return;
      }
    });
  }

  [GtkCallback]
  private void add_media_clicked_cb (Gtk.Button source) {
    var filechooser = new Gtk.FileChooserNative (_("Select Media"),
                                                 this.main_window,
                                                 Gtk.FileChooserAction.OPEN,
                                                 _("Open"),
                                                 _("Cancel"));

    var filter = new Gtk.FileFilter ();
    filter.add_mime_type ("image/png");
    filter.add_mime_type ("image/jpeg");
    filter.add_mime_type ("image/webp");
    filter.add_mime_type ("image/gif");

    if (compose_image_manager.n_images == 0) {
      filter.add_mime_type ("video/mpeg");
      filter.add_mime_type ("video/mp4");
    }

    filechooser.set_filter (filter);

    if (filechooser.run () == Gtk.ResponseType.ACCEPT) {
      var filename = filechooser.get_filename ();
      try {
        load_image_from_path(filename);
      }
      catch (GLib.Error e) {
        // TODO: Proper error checking/reporting
        // But it shouldn't happen because we only just picked it, so the file info
        // should just work
        warning ("%s (%s)", e.message, filename);
      }
    }
  }

  private void process_image_clipboard(Gtk.Clipboard clipboard) {
    var contents = clipboard.wait_for_image();
    if (contents == null) {
      Utils.show_error_dialog_with_message (_("Image disappeared from clipboard while pasting"), main_window);
      return;
    }
    if (this.compose_image_manager.full) {
      return;
    }

    try {
      load_image (Utils.pixbuf_to_temp_file (contents), true);
    }
    catch (GLib.Error e) {
      // TODO: Work out which errors we can distinguish and tell the user about
      error (e.message);
    }
  }

  private void process_uri_clipboard(Gtk.Clipboard clipboard) {
    string[] uris = clipboard.wait_for_uris ();
    // DMs can only take one item, and we only get here if there were URIs in the clipboard
    // So we can safely assume that item 0 exists
    try {
      load_image_from_uri (uris[0]);
    }
    catch (GLib.Error e) {
      // TODO: Work out which errors we can distinguish and tell the user about
      error (e.message);
    }
  }

  private void load_image_from_path (string filename) throws GLib.Error {
    debug ("Loading path %s", filename);

    var file = GLib.File.new_for_path (filename);
    load_image(file);
  }

  private void load_image_from_uri(string uri) throws GLib.Error {
    debug("Loading URI %s", uri);
    var file = GLib.File.new_for_uri (uri);
    load_image(file);
  }

  private void load_image (File file, bool is_temp_file = false) throws GLib.Error {
    GLib.FileInfo info = file.query_info (GLib.FileAttribute.STANDARD_TYPE + "," +
                                          GLib.FileAttribute.STANDARD_CONTENT_TYPE + "," +
                                          GLib.FileAttribute.STANDARD_SIZE, 0);
    var content_type = info.get_content_type();
#if MSWINDOWS
    // We can't trust Windows with mime types, it only understands extensions, so fudge something and hope for the best
    var fname = filename.down();
    var is_image = fname.has_suffix(".png") || fname.has_suffix(".gif") || fname.has_suffix(".jpg") || fname.has_suffix(".jpeg") || fname.has_suffix(".webp");
    var is_video = !is_image;
#else
    var is_video = content_type.has_prefix("video/");
    var is_image = content_type.has_prefix("image/");
#endif
    var is_animated_gif = is_image && Utils.is_animated_gif(file);
    var file_size = info.get_size();

    if (!is_image && !is_video) {
      image_error_label.label = _("Selected file is not an image or video.");
      image_error_label.visible = true;
    } else if (is_video && file_size > Twitter.MAX_BYTES_PER_VIDEO) {
      image_error_label.label = _("The selected video is too big. The maximum file size per video is %'d MB")
                                .printf (Twitter.MAX_BYTES_PER_VIDEO / 1024 / 1024);
                                image_error_label.visible = true;
    } else if (is_image && !is_animated_gif && file_size > Twitter.MAX_BYTES_PER_IMAGE) {
      image_error_label.label = _("The selected image is too big. The maximum file size per image is %'d MB")
                                .printf (Twitter.MAX_BYTES_PER_IMAGE / 1024 / 1024);
      image_error_label.visible = true;
    } else if (is_image && is_animated_gif && file_size > Twitter.MAX_BYTES_PER_GIF) {
      image_error_label.label = _("The selected GIF is too big. The maximum file size per GIF is %'d MB")
                                .printf (Twitter.MAX_BYTES_PER_GIF / 1024 / 1024);
      image_error_label.visible = true;
    } else {
      media_upload = new MediaUpload(file, true, is_temp_file);
      media_upload.progress_complete.connect((err) => {
        if (err != null) {
          Utils.show_error_dialog(err, this.main_window);
        }
        else {
          set_send_sensitive_state();
        }
      });
      this.compose_image_manager.show ();
      this.compose_image_manager.load_media (media_upload);
      TweetUtils.upload_media.begin (media_upload, account, cancellable);
      this.add_media_button.sensitive = false;
      this.fav_image_button.sensitive = false;
      image_error_label.visible = false;
    }
    set_send_sensitive_state();
  }

  [GtkCallback]
  public void fav_image_button_clicked_cb () {
    action_stack.visible_child_name = "fav-images";
    this.fav_image_view.load_images ();
  }

  [GtkCallback]
  public void favorite_image_selected_cb (string path) {
    try {
      load_image_from_path(path);
      action_stack.visible_child = reply_box;
    }
    catch (GLib.Error e) {
      // TODO: Proper error checking/reporting
      // But it shouldn't happen because we only just picked it from the fav list,
      // so the file info should just work
      warning ("%s (%s)", e.message, path);
    }
  }


  private void setup_emoji_chooser () {
    this.emoji_chooser = new Cb.EmojiChooser ();

    if (!emoji_chooser.try_init ()) {
      this.emoji_chooser = null;
      return;
    }

    emoji_chooser.emoji_picked.connect ((text) => {
      this.text_view.insert_at_cursor (text);
      action_stack.visible_child = reply_box;
      reply_box.grab_focus ();
    });
    emoji_chooser.show_all ();
    action_stack.add (emoji_chooser);

    this.emoji_button = new Gtk.Button.with_label ("😀");
    emoji_button.set_tooltip_text(_("Insert Emoji"));
    emoji_button.get_accessible().set_name(_("Insert Emoji"));
    emoji_button.clicked.connect (() => {
      this.emoji_chooser.populate ();
      action_stack.visible_child = this.emoji_chooser;
    });

    emoji_button.show_all ();
    add_button_box.add (emoji_button);
  }

  public string get_title () {
    return _("Direct Conversation");
  }

  public void create_radio_button (Gtk.RadioButton? group) {}
  public Gtk.RadioButton? get_radio_button() {return null;}
}
