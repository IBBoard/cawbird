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

[GtkTemplate (ui = "/uk/co/ibboard/cawbird/ui/new-list-entry.ui")]
class NewListEntry : Gtk.ListBoxRow {
  [GtkChild]
  private Gtk.Box create_box;
  [GtkChild]
  private Gtk.Grid grid;
  [GtkChild]
  private Gtk.Label list_name_label;
  [GtkChild]
  private Gtk.Entry list_name_entry;
  [GtkChild]
  private Gtk.Revealer revealer;
  [GtkChild]
  private Gtk.Button create_list_button;

  public signal void create_activated (string list_name);


  construct {
    list_name_entry.buffer.notify["text"].connect (name_text_changed_cb);
  }

  public void reveal () {
    revealer.reveal_child = true;
    this.activatable = false;
    list_name_entry.grab_focus ();
  }

  public void unreveal () {
    revealer.reveal_child = false;
    this.activatable = true;
    list_name_entry.text = "";
  }

  public override void get_preferred_width (out int min, out int nat) {
    min = nat = 0;
    int child_min, child_nat;
    list_name_label.get_preferred_width (out child_min, out child_nat);
    min += child_min;
    nat += child_nat;
    list_name_entry.get_preferred_width (out child_min, out child_nat);
    min += child_min;
    nat += child_nat;
    create_list_button.get_preferred_width (out child_min, out child_nat);
    // We can wrap when narrow enough, so ignore the create button for min and only include in natural size (because we'll take the space if possible)
    nat += child_nat;
  }

  public override void get_preferred_height_for_width (int width, out int min, out int nat) {
    int child_min, child_nat;
    create_box.get_preferred_height_for_width (width, out min, out nat);
    if (revealer.reveal_child) {
      list_name_entry.get_preferred_height_for_width (width, out child_min, out child_nat);
      min += child_min;
      nat += child_nat;
      if (width < Cawbird.RESPONSIVE_LIMIT) {
        create_list_button.get_preferred_height_for_width (width, out child_min, out child_nat);
        min += child_min;
        nat += child_nat;        
      }
    }
  }

  public override void size_allocate(Gtk.Allocation allocation) {
    if (allocation.width < Cawbird.RESPONSIVE_LIMIT) {
      grid.child_set(create_list_button, "left-attach", 0);
      grid.child_set(create_list_button, "top-attach", 1);
      grid.child_set(create_list_button, "width", 2);
    }
    else {
      grid.child_set(create_list_button, "left-attach", 2);
      grid.child_set(create_list_button, "top-attach", 0);
      grid.child_set(create_list_button, "width", 1);
    }
    base.size_allocate(allocation);
  }

  [GtkCallback]
  private void create_list_button_clicked_cb () {
    create_activated (list_name_entry.text);
  }

  private void name_text_changed_cb () {
    string name = list_name_entry.text;

    create_list_button.sensitive = false;

    if (name.length == 0 || name.char_count () > 25)
      return;

    if (name.get_char (0).isdigit())
      return;


    create_list_button.sensitive = true;
  }
}
