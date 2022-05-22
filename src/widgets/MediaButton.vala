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

private class MediaButton : Gtk.Bin {
  private Cb.Media? _media = null;
  private bool is_m3u8 {
    get {
      // Some URLs have query strings, so we can't just suffix
      return _media.url.contains(".m3u8");
    }
  }
  public Cb.Media? media {
    get {
      return _media;
    }
    set {
      if (_media != null) {
        _media.progress.disconnect (media_progress_cb);
      }
      _media = value;
      if (value != null) {
        if (!media.loaded) {
          _media.progress.connect (media_progress_cb);
        }
        set_save_as_sensitivity();
        if (!is_m3u8 && !_media.requires_authentication()) {
          menu_model.append (_("Copy URL"), "media.copy-url");
        }
      }
    }
  }
  private GLib.Menu menu_model;
  private Gtk.Menu? menu = null;
  private GLib.SimpleActionGroup actions;
  private const GLib.ActionEntry[] action_entries = {
    {"copy-url",        copy_url_activated},
    {"open-in-browser", open_in_browser_activated},
    {"save-as",         save_as_activated},
  };
  private Gtk.GestureMultiPress press_gesture;
  private bool restrict_height = false;
  private MediaButtonSurface button_surface;

  public signal void clicked (MediaButton source, double px, double py);

  construct {
    this.set_has_window (false);
  }

  ~MediaButton () {
    if (_media != null) {
      _media.progress.disconnect (media_progress_cb);
    }
  }

  public MediaButton (Cb.Media? media, bool restrict_height = false) {
    this.restrict_height = restrict_height;
    actions = new GLib.SimpleActionGroup ();
    actions.add_action_entries (action_entries, this);
    this.insert_action_group ("media", actions);

    this.menu_model = new GLib.Menu ();
    menu_model.append (_("Open in Browser"), "media.open-in-browser");
    menu_model.append (_("Save as…"), "media.save-as");

    this.media = media;
    button_surface = new MediaButtonSurface (this.media, restrict_height);
    button_surface.clicked.connect((surface, x, y) => {
      this.clicked(this, x, y);
    });
    this.add(button_surface);
    button_surface.show();

    this.press_gesture = new Gtk.GestureMultiPress (this);
    this.press_gesture.set_exclusive (true);
    this.press_gesture.set_button (0);
    this.press_gesture.set_propagation_phase (Gtk.PropagationPhase.CAPTURE);
    this.press_gesture.pressed.connect (gesture_pressed_cb);
    this.key_release_event.connect(button_pressed_cb);
  }

  private void reload_image() {
    Cb.MediaDownloader.get_default().reload_async.begin(media);
  }

  private void media_progress_cb () {
    if (this._media.loaded) {
      if (this._media.invalid && !this._media.permanent_invalid) {
        Gtk.Button reload_button = new Gtk.Button();
        reload_button.label = _("Reload image");
        reload_button.halign = Gtk.Align.CENTER;
        reload_button.valign = Gtk.Align.CENTER;
        reload_button.clicked.connect(reload_image);
        if (get_child() == button_surface) {
          remove(button_surface);
          add(reload_button);
        }
        reload_button.show();
      }
      else if (get_child() != button_surface) {
        remove(get_child());
        add(button_surface);
      }

      set_save_as_sensitivity();
      this.queue_resize ();
    }
  }

  private void copy_url_activated (GLib.SimpleAction a, GLib.Variant? v) {
    Gtk.Clipboard clipboard = Gtk.Clipboard.get_for_display (Gdk.Display.get_default (),
                                                             Gdk.SELECTION_CLIPBOARD);
    clipboard.set_text (media.url, -1);
  }

  private void open_in_browser_activated (GLib.SimpleAction a, GLib.Variant? v) {
    try {
      Gtk.show_uri_on_window ((Gtk.Window)get_toplevel(), media.target_url ?? media.url, Gtk.get_current_event_time ());
    } catch (GLib.Error e) {
      critical (e.message);
    }
  }

  private void save_as_activated (GLib.SimpleAction a, GLib.Variant? v) {
    string title;
    if (_media.is_video ())
      title = _("Save Video");
    else
      title = _("Save Image");

    var filechooser = new Gtk.FileChooserNative (title,
                                                 (Gtk.Window)get_toplevel(),
                                                 Gtk.FileChooserAction.SAVE,
                                                 _("Save"),
                                                 _("Cancel"));

    filechooser.set_current_name (Utils.get_media_display_name (_media));
    if (filechooser.run () == Gtk.ResponseType.ACCEPT) {
      var file = GLib.File.new_for_path (filechooser.get_filename ());
      // Download the file
      string url = _media.target_url ?? _media.url;
      debug ("Downloading %s to %s", url, filechooser.get_filename ());

      GLib.OutputStream? out_stream = null;
      try {
        out_stream = file.create (0, null);
      } catch (GLib.Error e) {
        Utils.show_error_dialog (e, (Gtk.Window)get_toplevel());
        warning (e.message);
      }

      if (out_stream != null) {
        Utils.download_file.begin (url, out_stream, () => {
          debug ("Download of %s finished", url);
        });
      }
    }
  }

  private void gesture_pressed_cb (int    n_press,
                                   double x,
                                   double y) {
    Gdk.EventSequence sequence = this.press_gesture.get_current_sequence ();
    Gdk.Event event = this.press_gesture.get_last_event (sequence);

    if (this._media == null)
      return;

    if (event.triggers_context_menu ()) {
      this.press_gesture.set_state (Gtk.EventSequenceState.CLAIMED);
      show_menu(event);
    }
  }

  private bool button_pressed_cb (Gdk.EventKey event_key) {
    uint keyval;
    event_key.get_keyval (out keyval);
    if (keyval == Gdk.Key.Menu) {
      show_menu();
      return Gdk.EVENT_STOP;
    }
    return Gdk.EVENT_PROPAGATE;
  }

  private void show_menu(Gdk.Event? event = null) {
    if (this.menu == null) {
      this.menu = new Gtk.Menu.from_model (menu_model);
      this.menu.attach_to_widget (this, null);
    }
    menu.show_all ();
    if (event != null) {
      menu.popup_at_pointer (event);
    }
    else {
      menu.popup_at_widget (this, Gdk.Gravity.CENTER, Gdk.Gravity.NORTH_WEST);
    }
  }

  private void set_save_as_sensitivity() {
    ((GLib.SimpleAction)actions.lookup_action ("save-as")).set_enabled (!_media.invalid && !is_m3u8);
  }

  public override Gtk.SizeRequestMode get_request_mode () {
    return Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH;
  }
}
