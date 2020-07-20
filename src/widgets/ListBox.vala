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

public class ListBox : Gtk.ListBox {
  private Gtk.Stack? placeholder = null;
  private Gtk.Label no_entries_label;

  private Gtk.Box error_box;
  private Gtk.Label error_label;
  private Gtk.Button retry_button;

  public signal void retry_button_clicked ();

  public ListBox () {
  }

  construct {
    add_placeholder ();
    this.set_selection_mode (Gtk.SelectionMode.NONE);
    Settings.get ().bind ("double-click-activation",
                          this, "activate-on-single-click",
                          GLib.SettingsBindFlags.INVERT_BOOLEAN);
  }

  private void add_placeholder () {
    placeholder = new Gtk.Stack ();
    placeholder.transition_type = Gtk.StackTransitionType.CROSSFADE;
    var loading_label = new Gtk.Label (_("Loading…"));
    loading_label.get_style_context ().add_class ("dim-label");
    placeholder.add_named (loading_label, "spinner");
    no_entries_label  = new Gtk.Label (_("No entries found"));
    no_entries_label.get_style_context ().add_class ("dim-label");
    no_entries_label.wrap_mode = Pango.WrapMode.WORD_CHAR;
    placeholder.add_named (no_entries_label, "no-entries");

    error_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
    error_label = new Gtk.Label ("");
    error_label.get_style_context ().add_class ("dim-label");
    error_label.margin = 12;
    error_label.selectable = true;
    error_label.wrap = true;
    retry_button = new Gtk.Button.with_label (_("Retry"));
    retry_button.set_halign (Gtk.Align.CENTER);
    retry_button.clicked.connect (() => {
      placeholder.visible_child_name = "spinner";
      retry_button_clicked ();
    });
    error_box.add (error_label);
    error_box.add (retry_button);
    placeholder.add_named (error_box, "error");

    placeholder.visible_child_name = "spinner";
    placeholder.show_all ();
    placeholder.set_valign (Gtk.Align.CENTER);
    placeholder.set_halign (Gtk.Align.CENTER);
    this.set_placeholder (placeholder);

  }

  public void set_empty () {
    placeholder.visible_child_name = "no-entries";
  }

  public void set_unempty () {
    placeholder.visible_child_name = "spinner";
  }

  public void set_error (string err_msg) {
    error_label.label = err_msg;
    placeholder.visible_child_name = "error";
  }

  public Gtk.Stack? get_placeholder () {
    return placeholder;
  }

  public void set_placeholder_text (string text) {
    no_entries_label.label = text;
  }

  public void reset_placeholder_text () {
    no_entries_label.label = _("No entries found");
  }

  public void remove_all () {
    this.foreach ((w) => {
      remove (w);
    });
  }

  public Gtk.Widget? get_first_visible_row () {
    int i = 0;
    Gtk.Widget? row = this.get_row_at_index (0);
    while (row != null && !row.visible) {
      i ++;
      row = this.get_row_at_index (i);
    }

    return row;
  }

  public Gtk.Widget? get_last_visible_row () {
    int i = (int)get_children().length() - 1;
    // We're in trouble if we get more than int.max (but less than uint.max) entries!
    Gtk.Widget? row = this.get_row_at_index (i);
    while (row != null && !row.visible) {
      i--;
      row = this.get_row_at_index (i);
    }

    return row;
  }
}
