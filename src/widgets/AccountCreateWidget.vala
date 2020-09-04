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

[GtkTemplate (ui = "/uk/co/ibboard/cawbird/ui/account-create-widget.ui")]
class AccountCreateWidget : Gtk.Box {
  [GtkChild]
  private Gtk.Entry pin_entry;
  [GtkChild]
  private Gtk.Label error_label;
  [GtkChild]
  private Gtk.Button confirm_button;
  [GtkChild]
  private Gtk.Button request_pin_button;
  [GtkChild]
  private Gtk.Label info_label;
  [GtkChild]
  private Gtk.Stack content_stack;
  private unowned Account acc;
  private unowned Cawbird cawbird;
  private unowned MainWindow main_window;
  public signal void result_received (bool result, Account acc);

  public AccountCreateWidget (Account acc, Cawbird cawbird, MainWindow main_window) {
    this.acc = acc;
    this.cawbird = cawbird;
    this.main_window = main_window;
    info_label.label = "%s <a href=\"https://twitter.com/signup\">%s</a>"
                       .printf (_("Don't have a Twitter account yet?"), _("Create one"));
    pin_entry.buffer.deleted_text.connect (pin_changed_cb);
    pin_entry.buffer.inserted_text.connect (pin_changed_cb);
  }

  private void pin_request_cb (Rest.OAuthProxy proxy, Error? error, Object? weak_object) {
    if (error != null) {
      Utils.show_error_dialog (error, this.main_window);
      critical (error.message);
      return;
    }
    
    string uri = "http://twitter.com/oauth/authorize?oauth_token=" + acc.proxy.get_token();
    debug ("Trying to open %s", uri);

    try {
      GLib.AppInfo.launch_default_for_uri (uri, null);
    } catch (GLib.Error e) {
      this.show_error (_("Could not open %s").printf ("<a href=\"" + uri + "\">" + uri + "</a>"));
      Utils.show_error_dialog (e, this.main_window);
      critical ("Could not open %s", uri);
      critical (e.message);
    }
  }

  public void open_pin_request_site () {
    acc.init_proxy (false, true);
    try {
      if (!acc.proxy.request_token_async ("oauth/request_token", "oob", pin_request_cb, this)) {
        show_error(_("Failed to retrieve request token"));
      }
    } catch(GLib.Error e) {
      Utils.show_error_dialog (e, this.main_window);
      critical (e.message);
    }
  }

  [GtkCallback]
  private void request_pin_clicked_cb () {
    open_pin_request_site ();
    content_stack.visible_child_name = "pin";
  }

  [GtkCallback]
  private async void confirm_button_clicked_cb () {
    pin_entry.sensitive = false;
    confirm_button.sensitive = false;
    request_pin_button.sensitive = false;

    this.do_confirm.begin ();
  }

  private void confirm_cb (Rest.OAuthProxy proxy, Error? error, Object? weak_object) {
    if (error != null) {
      critical (error.message);
      // We just assume that it was the wrong code
      show_error (_("Wrong PIN"));
      pin_entry.sensitive = true;
      confirm_button.sensitive = true;
      request_pin_button.sensitive = true;
      return;
    }

    var call = acc.proxy.new_call ();
    call.set_function ("1.1/account/settings.json");
    call.set_method ("GET");

    
    Cb.Utils.load_threaded_async.begin (call, null, (obj, res) => {
      Json.Node? root_node;
      try {
        root_node = Cb.Utils.load_threaded_async.end(res);
      } catch (GLib.Error e) {
        warning ("Could not get json data: %s", e.message);
        return;
      }

      Json.Object root = root_node.get_object ();
      string screen_name = root.get_string_member ("screen_name");
      debug ("Checking for %s", screen_name);
      Account? existing_account = Account.query_account (screen_name);
      if (existing_account != null) {
        result_received (false, existing_account);
        critical ("Account is already in use");
        show_error (_("Account already in use"));
        pin_entry.sensitive = true;
        pin_entry.text = "";
        request_pin_button.sensitive = true;
        return;
      }
  
      acc.query_user_info_by_screen_name.begin (screen_name, (obj, res) => {
        acc.query_user_info_by_screen_name.end(res);
        debug ("user info call");
        acc.init_database ();
        acc.save_info();
        acc.db.insert ("common")
              .val ("token", acc.proxy.token)
              .val ("token_secret", acc.proxy.token_secret)
              .run ();
        acc.suppress_notifications();
        acc.init_proxy (true, true);
        cawbird.account_added (acc);
        result_received (true, acc);
      });
    });
  }

  private async void do_confirm () {
    try {
      if (!acc.proxy.access_token_async ("oauth/access_token", pin_entry.get_text (), confirm_cb, this)) {
        show_error(_("Failed to retrieve access token"));
      }
    } catch (GLib.Error e) {
      Utils.show_error_dialog (e, this.main_window);
      critical (e.message);
    }
  }

  private void show_error (string err) {
    info_label.visible = false;
    error_label.visible = true;
    error_label.label = err;
  }

  private void pin_changed_cb () {
    string text = pin_entry.get_text ();
    bool confirm_possible = text.length > 0 && acc.proxy != null;
    confirm_button.sensitive = confirm_possible;
  }

  [GtkCallback]
  private bool delete_event_cb () {
    Account.remove_account (Account.DUMMY);
    return false;
  }
}
