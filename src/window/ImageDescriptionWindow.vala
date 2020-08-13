/*  This file is part of Cawbird, a Gtk+ linux Twitter client forked from Corebird.
 *  Copyright (C) 2020 IBBoard
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

[GtkTemplate (ui = "/uk/co/ibboard/cawbird/ui/image-description-window.ui")]
class ImageDescriptionWindow : Gtk.Window {
  const int DEFAULT_WIDTH = 450;
  const int MAX_DESCRIPTION_LENGTH = 1000;

  public signal void description_updated(int64 media_id, string description);

  [GtkChild]
  private Gtk.Image image;
  [GtkChild]
  private Gtk.TextView description_text;
  [GtkChild]
  private Gtk.Label length_label;
  [GtkChild]
  private Gtk.Button save_button;
  [GtkChild]
  private Gtk.Spinner title_spinner;
  [GtkChild]
  private Gtk.Label title_label;
  [GtkChild]
  private Gtk.Stack title_stack;
  
  private Rest.OAuthProxy proxy;
  private GLib.Cancellable? cancellable;
  private int64 media_id;
  private Cairo.ImageSurface image_surface;

  public ImageDescriptionWindow (Gtk.Window? parent, Rest.OAuthProxy proxy, int64 media_id, string description, Cairo.ImageSurface image_surface) {
    this.media_id = media_id;
    this.proxy = proxy;
    this.image_surface = image_surface;
    description_text.buffer.text = description;
    this.cancellable = new GLib.Cancellable ();

    image.size_allocate.connect((alloc) => {
      // FIXME: Window won't shrink again after the image gets bigger!
      Cairo.ImageSurface scaled_surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, alloc.width, alloc.height);
      Cairo.Context context = new Cairo.Context (scaled_surface);
      var w = image_surface.get_width () * 1.0;
      var h = image_surface.get_height () * 1.0;
      var scale = double.min(1.0, double.min(alloc.width / w, alloc.height / h));
      context.scale(scale, scale);
      context.set_source_surface (image_surface, (alloc.width - w * scale) / 2 / scale, (alloc.height - h * scale) / 2 / scale);
      context.paint ();
      image.set_from_surface(scaled_surface);
    });

    length_label.label = MAX_DESCRIPTION_LENGTH.to_string ();

    GLib.NetworkMonitor.get_default ().notify["network-available"].connect (update_save_button_sensitivity);

    description_text.buffer.changed.connect (() => {
      update_character_count();
      update_save_button_sensitivity();
    });

    if (parent != null) {
      this.set_transient_for (parent);
      this.set_modal (true);
    }

    /* Let the text view immediately grab the keyboard focus */
    description_text.grab_focus ();
    Gtk.AccelGroup ag = new Gtk.AccelGroup ();
    ag.connect (Gdk.Key.Escape, 0, Gtk.AccelFlags.LOCKED, escape_pressed_cb);
    ag.connect (Gdk.Key.Return, Gdk.ModifierType.CONTROL_MASK, Gtk.AccelFlags.LOCKED,
        () => {save_image_description_clicked (); return true;});

    this.add_accel_group (ag);

    this.set_default_size (DEFAULT_WIDTH, DEFAULT_WIDTH);
    this.update_character_count();
  }

  private void update_save_button_sensitivity () {
    int length = (int)Tl.count_weighted_characters (description_text.buffer.text);

    if (length <= MAX_DESCRIPTION_LENGTH) {
      save_button.sensitive = GLib.NetworkMonitor.get_default ().network_available;
    } else {
      save_button.sensitive = false;
    }
  }

  private void update_character_count () {
    var chars_remaining = MAX_DESCRIPTION_LENGTH - Tl.count_weighted_characters (description_text.buffer.text);
    length_label.label = chars_remaining.to_string();
    length_label.get_accessible().set_description(ngettext("%d character remaining", "%d characters remaining", chars_remaining).printf((int)chars_remaining));
  }

  private void set_sending_state (bool sending) {
    if (sending) {
      title_stack.visible_child = title_spinner;
      title_spinner.start ();
      save_button.sensitive = false;
    } else {
      title_stack.visible_child = title_label;
      title_spinner.stop ();
      update_save_button_sensitivity ();
    }

    description_text.sensitive = !sending;
  }

  [GtkCallback]
  private void save_image_description_clicked () {
    if (!save_button.sensitive)
      return;

    set_sending_state (true);
    this.set_image_description.begin((obj, res) => {
      bool success = false;
      try {
       this.set_image_description.end (res);
       success = true;
      } catch (GLib.Error e) {
        debug("Error setting description: %s", e.message);
        Utils.show_error_dialog (e, this);
        set_sending_state (false);
        return;
      }

      if (success) {
        debug("Image description set");
        description_updated(media_id, description_text.buffer.text);
        hide();
        debug("Hidden");
      } else {
        debug("Image description failed");
        set_sending_state (false);
      }
    });
  }

  private async void set_image_description() throws GLib.Error {
    debug("Creating JSON");
    var gen = new Json.Generator();
    var root = new Json.Node(Json.NodeType.OBJECT);
    var object = new Json.Object();
    root.set_object(object);
    gen.set_root(root);
    object.set_string_member("media_id", media_id.to_string());
    var alt_text = new Json.Object();
    object.set_object_member("alt_text", alt_text);
    alt_text.set_string_member("text", description_text.buffer.text);
    string json_dump = gen.to_data (null);
    debug("Sending %s", json_dump);

    var call = new OAuthProxyCallWithBody(proxy, json_dump);
    call.set_method ("POST");
    call.set_function( "1.1/media/metadata/create.json");
    GLib.Error? err = null;
    call.invoke_async.begin (null, (obj, res) => {
      try {
        debug("Call completed");
        call.invoke_async.end (res);
      } catch (GLib.Error e) {
        debug("ERROR! %s", e.message);
        err = e;
      }
      debug("Callback");
      set_image_description.callback();
    });

    debug("Yielding");
    yield;

    if (err != null) {
      throw err;
    }
  }

  [GtkCallback]
  private void cancel_clicked () {
      if (this.cancellable != null) {
        this.cancellable.cancel ();
      }
      hide();
  }

  private bool escape_pressed_cb () {
    this.cancel_clicked ();
    return Gdk.EVENT_STOP;
  }
}
