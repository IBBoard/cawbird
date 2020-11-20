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

class DMListEntry : Gtk.ListBoxRow, Cb.TwitterItem {
  private Gtk.Grid grid;
  private AvatarWidget avatar_image;
  private Gtk.CheckButton delete_checkbutton;
  private Gtk.Label text_label;
  private Gtk.Label screen_name_label;
  private TextButton name_button;
  private Gtk.Label time_delta_label;
  private MediaButton media_button;
  private string _text;
  private Json.Object? _message_data;
  private Cb.Media? _media;
  private Cb.TextEntity[] _entities;

  public bool is_checked {
    get {
      return delete_checkbutton.active;
    }
    set {
      set_checked(value);
    }
  }

  public signal void avatar_clicked();

  public string text {
    set { 
      _text = value;
      if (_message_data == null) {
        text_label.label = value;
        text_label.visible = value != null && value != "";
      }
    }
  }

  public string screen_name {
    set {
      screen_name_label.label = "@" + value;
      screen_name_label.tooltip_text = "@" + value;
    }
  }

  public new string name {
    set {
      name_button.set_text (value);
      name_button.tooltip_text = value;
    }
  }

  public Cb.Media media {
    get { return _media; }
    set {
      _media = value;
      if (_media != null) {
        if (media_button == null) {
          media_button = new MediaButton(media);
          grid.attach (media_button, 1, 2, 3, 1);
          media_button.clicked.connect(media_clicked_cb);
          media_button.show();
        }
        else {
          media_button.media = _media;
        }
      }
    }
  }

  // A property would be nice, but Cb.TextEntity isn't a GLib.Object so we can't
  public void set_entities(Cb.TextEntity[] value) {
    _entities = value;
    set_dm_text();
  }

  public Json.Object? message_data {
    get { return _message_data; }
    set {
      _message_data = value;
      set_dm_text();
    }
  }

  public Cairo.Surface avatar {
    set { avatar_image.surface = value; }
  }

  public bool seen {
    get { return true; }
    set {}
  }

  private GLib.TimeSpan last_timediff;
  public int64 timestamp;
  public int64 id;
  public int64 user_id;
  public unowned MainWindow main_window;

  public DMListEntry () {
    this.set_activatable (false);
    this.get_style_context ().add_class ("tweet");

    grid = new Gtk.Grid ();
    grid.margin = 6;
    grid.show ();
    this.add (grid);

    this.avatar_image = new AvatarWidget ();
    avatar_image.size = 48;
    avatar_image.set_valign (Gtk.Align.START);
    avatar_image.show();
    delete_checkbutton = new Gtk.CheckButton();
    delete_checkbutton.halign = Gtk.Align.CENTER;
    delete_checkbutton.valign = Gtk.Align.CENTER;
    delete_checkbutton.button_release_event.connect(avatar_button_release_cb);
    delete_checkbutton.enter_notify_event.connect(Utils.set_pointer_on_mouseover);
    delete_checkbutton.leave_notify_event.connect(Utils.set_pointer_on_mouseover);
    var avatar_overlay = new Gtk.Overlay();
    avatar_overlay.add(avatar_image);
    avatar_overlay.add_overlay(delete_checkbutton);
    avatar_overlay.show();
    var event_box = new Gtk.EventBox();
    event_box.margin = 4;
    event_box.margin_end = 12;
    event_box.valign = Gtk.Align.START;
    event_box.add(avatar_overlay);
    event_box.button_release_event.connect(avatar_button_release_cb);
    event_box.enter_notify_event.connect(Utils.set_pointer_on_mouseover);
    event_box.leave_notify_event.connect(Utils.set_pointer_on_mouseover);
    event_box.show();
    grid.attach (event_box, 0, 0, 1, 3);

    this.name_button = new TextButton ();
    name_button.set_valign (Gtk.Align.BASELINE);
    name_button.show ();
    grid.attach (name_button, 1, 0, 1, 1);

    this.screen_name_label = new Gtk.Label (null);
    screen_name_label.set_margin_start (6);
    screen_name_label.set_margin_end (6);
    screen_name_label.set_valign (Gtk.Align.BASELINE);
    screen_name_label.get_style_context ().add_class ("dim-label");
    screen_name_label.show ();
    grid.attach (screen_name_label, 2, 0, 1, 1);

    this.time_delta_label = new Gtk.Label (null);
    time_delta_label.set_halign (Gtk.Align.END);
    time_delta_label.set_valign (Gtk.Align.BASELINE);
    time_delta_label.set_hexpand (true);
    time_delta_label.show ();
    time_delta_label.get_style_context ().add_class ("dim-label");
    grid.attach (time_delta_label, 3, 0, 1, 1);

    this.text_label = new Gtk.Label (null);
    text_label.set_margin_top (6);
    text_label.set_margin_end (6);
    text_label.set_margin_bottom (6);
    text_label.set_hexpand (true);
    text_label.set_vexpand (true);
    text_label.set_xalign (0.0f);
    text_label.set_line_wrap (true);
    text_label.set_line_wrap_mode (Pango.WrapMode.WORD_CHAR);
    text_label.set_use_markup (true);
    text_label.set_use_markup (true);
    text_label.set_selectable (true);
    text_label.show ();
    text_label.activate_link.connect((uri) => {
      this.grab_focus ();
      return TweetUtils.activate_link (uri, main_window);
    });
    grid.attach (text_label, 1, 1, 3, 1);

    name_button.clicked.connect (() => {
      var bundle = new Cb.Bundle ();
      bundle.put_int64 (ProfilePage.KEY_USER_ID, user_id);
      bundle.put_string (ProfilePage.KEY_SCREEN_NAME, screen_name_label.label.substring (1));
      main_window.main_widget.switch_page (Page.PROFILE, bundle);
    });

    this._entities = new Cb.TextEntity[0];

    this.key_release_event.connect(key_released_cb);
    Settings.get ().changed["text-transform-flags"].connect(set_dm_text);

    this.show ();
  }

  ~DMListEntry() {
    Settings.get ().changed["text-transform-flags"].disconnect(set_dm_text);
  }

  [GtkCallback]
  private bool key_released_cb (Gdk.EventKey evt) {
#if DEBUG
    switch(evt.keyval) {
      case Gdk.Key.k:
        if (_message_data != null) {
          var gen = new Json.Generator();
          var node = new Json.Node(Json.NodeType.OBJECT);
          node.set_object(_message_data);
          gen.set_root(node);
          gen.set_pretty(true);
          string json = gen.to_data(null);
          stderr.printf(json + "\n");
        }
        else {
          stderr.printf("Old format DM - no JSON\n");
        }
        return Gdk.EVENT_STOP;
    }
#endif
    return Gdk.EVENT_PROPAGATE;
  }

  private bool avatar_button_release_cb(Gtk.Widget widget, Gdk.EventButton event) {
    if (event.button == Gdk.BUTTON_PRIMARY) {
      set_checked(!is_checked);
      avatar_clicked();
      return Gdk.EVENT_STOP;
    }
    return Gdk.EVENT_PROPAGATE;

  }

  private void set_dm_text() {
    if (_message_data != null) {
      var msg = _message_data.get_string_member ("text");
      // Force removing media links, because they don't actually work for DMs
      var flags = Settings.get_text_transform_flags () | Cb.TransformFlags.REMOVE_MEDIA_LINKS;
      msg = Cb.TextTransform.text (msg, _entities, flags, 0, 0);
      text_label.label = msg;
      text_label.visible = msg != "";
    }
  }

  public void load_avatar (string avatar_url) {
    string url = avatar_url;
    if (this.get_scale_factor () == 2)
      url = url.replace ("_normal", "_bigger");

    Twitter.get ().get_avatar.begin (user_id, url, avatar_image, 48 * this.get_scale_factor ());
  }

  public int update_time_delta (GLib.DateTime? now = null) {
    GLib.DateTime cur_time;
    if (now == null)
      cur_time = new GLib.DateTime.now_local ();
    else
      cur_time = now;

    GLib.DateTime then = new GLib.DateTime.from_unix_local (timestamp);
    time_delta_label.label = Utils.get_time_delta (then, cur_time);
    return (int)(cur_time.difference (then) / 1000.0 / 1000.0);
  }

  public int64 get_sort_factor () {
    return timestamp;
  }

  public int64 get_timestamp () {
    return timestamp;
  }

  public GLib.TimeSpan get_last_set_timediff () {
    return this.last_timediff;
  }

  public void set_last_set_timediff (GLib.TimeSpan span) {
    this.last_timediff = span;
  }

  private void media_clicked_cb(MediaButton button, double px, double py) {
    TweetUtils.handle_media_click ({media}, this.main_window, 0);
  }

  private void set_checked(bool checked) {
    if (checked) {
      avatar_image.opacity = 0.5;
      delete_checkbutton.active = true;
      delete_checkbutton.show();
    }
    else {
      avatar_image.opacity = 1;
      delete_checkbutton.active = false;
      delete_checkbutton.hide();
    }
  }
}


