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

[GtkTemplate (ui = "/uk/co/ibboard/cawbird/ui/list-list-entry.ui")]
public class ListListEntry : Gtk.ListBoxRow {
  public static int sort_func (Gtk.ListBoxRow r1,
                               Gtk.ListBoxRow r2) {
    if (!(r1 is ListListEntry))
      return -1;

    return ((ListListEntry)r1).name.ascii_casecmp (((ListListEntry)r2).name);
  }

  [GtkChild]
  private Gtk.Label title_label;
  public string title {
    set {
      title_label.label = value;
    }
    get {
      return title_label.label;
    }
  }

  [GtkChild]
  private Gtk.Label description_label;
  public string description {
    set {
      description_label.label = value;
    }
    get {
      return description_label.label;
    }
  }

  [GtkChild]
  private Gtk.Label name_label;
  public new string name {
    set {
      name_label.label = normalize_name (value);
    }
    get {
      return name_label.label;
    }
  }

  [GtkChild]
  private Gtk.Stack stack;
  [GtkChild]
  private Gtk.Button subscribe_button;
  [GtkChild]
  private Gtk.Button unsubscribe_button;
  [GtkChild]
  private Gtk.Button delete_button;


  public int64 id;
  public bool user_list = false;
  public string creator_screen_name;
  public int n_subscribers;
  public int n_members = 0;
  public int64 created_at;
  public string mode;
  private unowned Account account;

  public ListListEntry.from_json_data (Json.Object obj, Account account) {
    this.account = account;
    var user = obj.get_object_member ("user");
    title = obj.get_string_member ("name");
    name = obj.get_string_member ("full_name");
    description = obj.get_string_member ("description");
    id = obj.get_int_member ("id");
    creator_screen_name = user.get_string_member ("screen_name");
    n_subscribers = (int)obj.get_int_member ("subscriber_count");
    n_members = (int)obj.get_int_member ("member_count");
    created_at = Cb.Utils.parse_date (obj.get_string_member ("created_at")).to_unix ();
    mode = obj.get_string_member ("mode");
    bool following = obj.get_boolean_member ("following");

    if (following || user.get_int_member ("id") == account.id) {
      unsubscribe_button.show ();
      subscribe_button.hide ();
    } else {
      unsubscribe_button.hide ();
      subscribe_button.show ();
    }

    if (user.get_int_member ("id") == account.id) {
      user_list = true;
      unsubscribe_button.hide ();
    } else {
      delete_button.hide ();
    }
  }

  private string normalize_name (string name) {
    if (name.contains ("/lists/")) {
      return name.replace ("/lists/", "/");
    }
    return name;
  }

  [GtkCallback]
  private void delete_button_clicked_cb () {
    this.sensitive = false;
    ListUtils.delete_list.begin (account, id, (obj, res) => {
      try {
        ListUtils.delete_list.end (res);
        cancel_more_mode();
      } catch (GLib.Error e) {
        Utils.show_error_dialog (e, (Gtk.Window)this.get_toplevel());
        this.sensitive = true;
        return;
      }
    });
  }

  [GtkCallback]
  private void subscribe_button_clicked_cb () {
    this.sensitive = false;
    var call = account.proxy.new_call ();
    call.set_function ("1.1/lists/subscribers/create.json");
    call.set_method ("POST");
    call.add_param ("list_id", id.to_string ());
    call.invoke_async.begin (null, (o, res) => {
      try {
        call.invoke_async.end (res);
      } catch (GLib.Error e) {
        // Subscribing to a subscribed list doesn't appear to cause errors,
        // so there's nothing to ignore as "accidental success"
        Utils.show_error_dialog (TweetUtils.failed_request_to_error (call, e), (Gtk.Window)this.get_toplevel());
        return;
      } finally {
        this.sensitive = true;
      }
      subscribe_button.hide ();
      unsubscribe_button.show ();
    });

  }

  [GtkCallback]
  private void unsubscribe_button_clicked_cb () {
    this.sensitive = false;
    var call = account.proxy.new_call ();
    call.set_function ("1.1/lists/subscribers/destroy.json");
    call.set_method ("POST");
    call.add_param ("list_id", id.to_string ());
    call.invoke_async.begin (null, (o, res) => {
      try {
        call.invoke_async.end (res);
      } catch (GLib.Error e) {
        var err = TweetUtils.failed_request_to_error (call, e);

        if (err.domain != TweetUtils.get_error_domain() || err.code != 109) {
          // 109 is "user isn't subscribed to the list", so assume they were unsubscribed by another source
          Utils.show_error_dialog (err, (Gtk.Window)this.get_toplevel());
          return;
        }
      } finally {
        this.sensitive = true;
      }
      subscribe_button.show ();
      unsubscribe_button.hide ();
    });
  }


  [GtkCallback]
  private void more_button_clicked_cb () {
    stack.visible_child_name = "more";
    this.activatable = false;
  }

  [GtkCallback]
  private void cancel_button_clicked_cb () {
    cancel_more_mode();
  }

  private void cancel_more_mode () {
    stack.visible_child_name = "default";
    this.activatable = true;
  }

  [GtkCallback]
  private bool focus_out_cb () {
    stack.visible_child_name = "default";
    return false;
  }
}
