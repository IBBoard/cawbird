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

[GtkTemplate (ui = "/uk/co/ibboard/cawbird/ui/user-filter-entry.ui")]
class UserFilterEntry : Gtk.ListBoxRow, Cb.TwitterItem {
  [GtkChild]
  private Gtk.Label name_label;
  [GtkChild]
  private Gtk.Label screen_name_label;
  [GtkChild]
  private AvatarWidget avatar_image;
  [GtkChild]
  private Gtk.Stack stack;
  [GtkChild]
  private Gtk.Box delete_box;
  [GtkChild]
  private Gtk.Grid grid;
  [GtkChild]
  private Gtk.Revealer revealer;
  [GtkChild]
  private Gtk.Button delete_button;

  public new string name {
    set {
      name_label.label = value;
      name_label.set_tooltip_text(value);
    }
  }

  public string screen_name {
    set { screen_name_label.label = "@" + value; }
  }

  public string avatar_url {
    set { real_set_avatar (value); }
  }

  public bool seen {
    get { return true; }
    set {}
  }

  public int64 user_id;

  public signal void deleted (int64 id);

  private bool _muted = false;
  private bool _blocked = false;

  public bool muted {
    get { return _muted; }
    set {
      _muted = value;
      if (muted && !blocked) {
        delete_button.label = _("Unmute");
      }
      // Else the blocking takes priority
    }
  }
  public bool blocked {
    get { return _blocked; }
    set {
      _blocked = value;
      if (blocked) {
        delete_button.label = _("Unblock");
      }
    }
  }
  private GLib.TimeSpan last_timediff;

  private void real_set_avatar (string avatar_url) {
    Twitter.get ().get_avatar.begin (user_id, avatar_url, avatar_image, 48 * this.get_scale_factor ());
  }

  public int update_time_delta (GLib.DateTime? now = null) {return 0;}
  public int64 get_sort_factor () { return 2; }
  public int64 get_timestamp () { return 0; }

  public GLib.TimeSpan get_last_set_timediff () {
    return this.last_timediff;
  }

  public void set_last_set_timediff (GLib.TimeSpan span) {
    this.last_timediff = span;
  }

  [GtkCallback]
  private void menu_button_clicked_cb () {
    stack.visible_child = delete_box;
  }

  [GtkCallback]
  private void cancel_button_clicked_cb () {
    stack.visible_child = grid;
  }

  [GtkCallback]
  private void delete_button_clicked_cb () {
    revealer.reveal_child = false;
    revealer.notify["child-revealed"].connect (() => {
      deleted (user_id);
    });
  }
}
