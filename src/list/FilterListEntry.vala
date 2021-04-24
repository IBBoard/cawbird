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
[GtkTemplate (ui = "/uk/co/ibboard/cawbird/ui/filter-list-entry.ui")]
class FilterListEntry : Gtk.ListBoxRow {
  [GtkChild]
  private unowned Gtk.Label content_label;
  [GtkChild]
  private unowned Gtk.Revealer revealer;
  [GtkChild]
  private unowned Gtk.Stack stack;
  [GtkChild]
  private unowned Gtk.Grid normal_box;
  [GtkChild]
  private unowned Gtk.Box delete_box;

  private unowned Cb.Filter _filter;
  public unowned Cb.Filter filter {
    set {
      content_label.label = value.get_contents ();
      _filter = value;
    }
    get {
      return _filter;
    }
  }
  public string content {
    set {
      content_label.label = value;
    }
    get {
      return content_label.label;
    }
  }
  private unowned Account account;
  private unowned MainWindow main_window;

  public FilterListEntry (Cb.Filter  f,
                          Account    account,
                          MainWindow main_window) {
    this.filter = f;
    this.account = account;
    this.main_window = main_window;
  }

  construct {
    revealer.notify["child-revealed"].connect (() => {
      if (!revealer.child_revealed) {
        ((Gtk.Container)this.get_parent ()).remove (this);
      }
    });
  }

  [GtkCallback]
  private void menu_button_clicked_cb () {
    stack.visible_child = delete_box;
    this.activatable = false;
  }

  [GtkCallback]
  private void cancel_button_clicked_cb () {
    stack.visible_child = normal_box;
    this.activatable = true;
  }

  [GtkCallback]
  private void delete_button_clicked_cb () {
    for (int i = 0; i < account.filters.length; i ++) {
      var f = account.filters.get (i);
      if (f.get_id () == this.filter.get_id ()) {
        account.filters.remove (f);
        account.db.exec ("DELETE FROM `filters` WHERE `id`='%d'".printf (f.get_id ()));
        revealer.reveal_child = false;
        main_window.rerun_filters ();
        return;
      }
    }
  }

}
