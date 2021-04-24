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
  private unowned Gtk.Entry pin_entry;
  [GtkChild]
  private unowned Gtk.Label error_label;
  [GtkChild]
  private unowned Gtk.Button confirm_button;
  [GtkChild]
  private unowned Gtk.Button request_pin_button;
  [GtkChild]
  private unowned Gtk.Label info_label;
  [GtkChild]
  private unowned Gtk.Stack content_stack;
  private Rest.OAuthProxy proxy;
  private unowned Cawbird cawbird;
  private unowned MainWindow main_window;
  public signal void account_created (Account acc);

  public AccountCreateWidget (Cawbird cawbird, MainWindow main_window) {
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
    
    string uri = "http://twitter.com/oauth/authorize?oauth_token=" + proxy.get_token();
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
    proxy = new Rest.OAuthProxy(Settings.get_consumer_key(), Settings.get_consumer_secret(), "https://api.twitter.com/", false);

    try {
      if (!proxy.request_token_async ("oauth/request_token", "oob", pin_request_cb, this)) {
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

    var call = proxy.new_call ();
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
      Account? acc = Account.query_account (screen_name);
      if (acc != null) {
        bool proxies_match = proxy_values_match(proxy, acc.get_proxy_values());
        bool override_acct = false;
        if (!proxies_match) {
          Gtk.MessageDialog replace_dialog = new Gtk.MessageDialog(main_window, Gtk.DialogFlags.DESTROY_WITH_PARENT,
                                                                   Gtk.MessageType.QUESTION, Gtk.ButtonsType.YES_NO,
                                                                   _("The account %s already exists with different keys.\n\nReplace it?"),
                                                                   screen_name);
          var result = replace_dialog.run();
          replace_dialog.destroy();
          override_acct = result == Gtk.ResponseType.YES;
        }

        if (!proxies_match && override_acct) {
          Account.update_api_details(acc.id, proxy);
          acc.proxy = proxy;
        }
        else {
          critical ("Account is already in use");
          show_error (_("Account already in use"));
          pin_entry.sensitive = true;
          pin_entry.text = "";
          request_pin_button.sensitive = true;
          return;
        }
      }
  
      Twitter.get().get_own_user_info.begin (proxy, (obj, res) => {
        UserInfo user_info;
        try {
          user_info = Twitter.get().get_own_user_info.end(res);
        } catch (GLib.Error e) {
          warning ("Could not get json data: %s", e.message);
          return;
        }
        if (acc == null) {
          acc = Account.create_account(user_info, proxy);
        }
        // else we retrieved and updated an existing account earlier
        debug ("user info call");
        acc.init_database ();
        acc.init_proxy ();
        acc.save_info();
        acc.suppress_notifications();
        cawbird.account_added (acc);
        account_created (acc);
      });
    });
  }

  private bool proxy_values_match(Rest.OAuthProxy proxy, string[] proxy_values) {
    return proxy.consumer_key == proxy_values[0] && proxy.consumer_secret == proxy_values[1]
      && proxy.token == proxy_values[2] && proxy.token_secret == proxy_values[3];
  }

  private async void do_confirm () {
    try {
      if (!proxy.access_token_async ("oauth/access_token", pin_entry.get_text (), confirm_cb, this)) {
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
    bool confirm_possible = text.length > 0 && proxy != null;
    confirm_button.sensitive = confirm_possible;
  }
}
