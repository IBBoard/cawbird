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
[GtkTemplate (ui = "/uk/co/ibboard/cawbird/ui/modify-filter-dialog.ui")]
class ModifyFilterDialog : Gtk.Dialog {
  [GtkChild]
  private Gtk.Entry regex_entry;
  [GtkChild]
  private Gtk.Label regex_status_label;
  [GtkChild]
  private Gtk.TextView regex_test_text;
  [GtkChild]
  private Gtk.Button save_button;

  private GLib.Regex regex;
  private unowned Account account;
  private unowned Cb.Filter filter;
  private unowned MainWindow main_window;

  /** created will be true if the filter has just been created by the user(i.e. not modified) */
  public signal void filter_added (Cb.Filter filter, bool created);

  public ModifyFilterDialog (MainWindow parent,
                             Account    account,
                             Cb.Filter? filter = null) {
    GLib.Object (use_header_bar: Gtk.Settings.get_default ().gtk_dialogs_use_header ? 1 : 0);
    this.set_transient_for (parent);
    this.application = parent.get_application ();
    this.account = account;
    if (filter != null) {
      regex_entry.text = filter.get_contents ();
      this.title = _("Modify Filter");
    }
    this.filter = filter;
    this.main_window = parent;
  }

  construct {
    regex_test_text.buffer.changed.connect (regex_entry_changed_cb);
  }


  public override void response (int response_id) {
    if (response_id == Gtk.ResponseType.CANCEL) {
      this.destroy ();
    } else if (response_id == Gtk.ResponseType.OK) {
      save_filter ();
      this.destroy ();
    }
  }

  [GtkCallback]
  private void regex_entry_changed_cb () {
    try {
      regex = new GLib.Regex (regex_entry.text);
    } catch (GLib.RegexError e) {
      regex_status_label.label = e.message;
      save_button.sensitive = false;
      return;
    }
    bool matches = regex.match (regex_test_text.buffer.text);
    if (matches) {
      regex_status_label.label = _("Matches");
    } else {
      regex_status_label.label = _("Doesn't match");
    }
    save_button.sensitive = (regex_entry.text.length != 0);
  }

  private void save_filter () {
    string content = regex_entry.text;
    if (this.filter == null) {
      Cb.Filter f = Utils.create_persistent_filter (content, account);
      filter_added (f, true);
    } else {
      /* We update the existing filter */
      account.db.update ("filters").val ("content", content)
                                   .where_eq ("id", filter.get_id ().to_string ())
                                   .run ();

      for (int i = 0; i < account.filters.length; i ++) {
        var f = account.filters.get (i);
        if (f.get_id () == this.filter.get_id ()) {
          f.reset (content);
          filter_added (f, false);
          break;
        }
      }
    }

    /* Update timelines */
    main_window.rerun_filters ();
  }
}
