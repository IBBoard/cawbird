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

class ListsPage : IPage, ScrollWidget, Cb.MessageReceiver {
  public const int KEY_MODE = 0;
  public const int KEY_LIST_ID = 1;

  public const int MODE_DELETE = 1;

  private BadgeRadioButton radio_button;
  public int unread_count                   { get; set; }
  private unowned MainWindow main_window;
  public unowned MainWindow window {
    set {
      main_window = value;
      user_lists_widget.main_window = value;
    }
  }
  public unowned Account account            { get; set; }
  public unowned Cb.DeltaUpdater delta_updater { get; set; }
  public int id                             { get; set; }
  private int64 user_id;
  private UserListsWidget user_lists_widget;
  private GLib.DateTime last_load = new GLib.DateTime.from_unix_utc (0);


  public ListsPage (int id, Account account) {
    this.id = id;
    this.account = account;

    this.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);

    this.user_lists_widget = new UserListsWidget ();
    this.user_lists_widget.account = account;
    this.add (user_lists_widget);
  }

  public void on_join (int page_id, Cb.Bundle? args) {
    int mode = 0;

    if (!GLib.NetworkMonitor.get_default ().get_network_available ())
      return;

    if (args != null)
      mode = args.get_int (KEY_MODE);

    if (mode == 0) {
      this.user_id = account.id;
      load_newest.begin ();
    } else if (mode  == MODE_DELETE) {
      int64 list_id = args.get_int64 (KEY_LIST_ID);
      message (@"Deleting list with id $list_id");
      user_lists_widget.remove_list (list_id);
    }
  }

  public void on_leave () {
    user_lists_widget.unreveal ();
  }

  private async void load_newest () {
    var now = new GLib.DateTime.now_local ();
    if (now.difference (last_load) > GLib.TimeSpan.MINUTE) {
      last_load = now;
      yield user_lists_widget.load_lists (user_id);
    }
  }

  private void stream_message_received (Cb.StreamMessageType type, Json.Node root) { // {{{
    if (type == Cb.StreamMessageType.EVENT_LIST_CREATED ||
        type == Cb.StreamMessageType.EVENT_LIST_SUBSCRIBED) {
      var obj = root.get_object ();
      var entry = new ListListEntry.from_json_data (obj, account);
      user_lists_widget.add_list (entry);
    } else if (type == Cb.StreamMessageType.EVENT_LIST_DESTROYED ||
               type == Cb.StreamMessageType.EVENT_LIST_UNSUBSCRIBED) {
      var obj = root.get_object ();
      int64 list_id = obj.get_int_member ("id");
      user_lists_widget.remove_list (list_id);
    } else if (type == Cb.StreamMessageType.EVENT_LIST_UPDATED) {
      var obj = root.get_object ();
      int64 list_id = obj.get_int_member ("id");
      update_list (list_id, obj);
    } else if (type == Cb.StreamMessageType.EVENT_LIST_MEMBER_ADDED) {
      var obj = root.get_object ();
      int64 list_id = obj.get_int_member ("id");
      user_lists_widget.update_member_count (list_id, 1);
    } else if (type == Cb.StreamMessageType.EVENT_LIST_MEMBER_REMOVED) {
      var obj = root.get_object ();
      int64 list_id = obj.get_int_member ("id");
      user_lists_widget.update_member_count (list_id, -1);
    }

  } // }}}

  public async TwitterList[] get_user_lists () {
    yield load_newest();
    return user_lists_widget.get_user_lists ();
  }

  private void update_list (int64 list_id, Json.Object obj) {
    string title = obj.get_string_member ("name");
    string name = obj.get_string_member ("full_name");
    string description = obj.get_string_member ("description");
    string mode = obj.get_string_member ("mode");
    user_lists_widget.update_list (list_id, title, name, description, mode);
  }


  public void create_radio_button (Gtk.RadioButton? group) {
    radio_button = new BadgeRadioButton (group, "view-list-symbolic", _("Lists"));
  }


  public string get_title () {
    return _("Lists");
  }

  public Gtk.RadioButton? get_radio_button () {
    return radio_button;
  }

}
