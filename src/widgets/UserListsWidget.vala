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

[GtkTemplate (ui = "/uk/co/ibboard/cawbird/ui/user-lists-widget.ui")]
class UserListsWidget : Gtk.Box {
  [GtkChild]
  private Gtk.Label user_list_label;
  [GtkChild]
  private Gtk.ListBox user_list_box;
  [GtkChild]
  private Gtk.Frame user_list_frame;
  [GtkChild]
  private Gtk.Label subscribed_list_label;
  [GtkChild]
  private Gtk.ListBox subscribed_list_box;
  [GtkChild]
  private Gtk.Frame subscribed_list_frame;
  [GtkChild]
  private NewListEntry new_list_entry;
  [GtkChild]
  private Gtk.Revealer user_lists_revealer;
  [GtkChild]
  private Gtk.Separator upper_separator;
  [GtkChild]
  private Gtk.ListBox new_list_box;

  public unowned MainWindow main_window { get; set; }
  public unowned Account account        { get; set; }
  private bool show_create_entry = true;

  public UserListsWidget() {
  }

  construct {
    user_list_box.set_header_func (default_header_func);
    user_list_box.set_sort_func (ListListEntry.sort_func);
    subscribed_list_box.set_header_func (default_header_func);
    subscribed_list_box.set_sort_func (ListListEntry.sort_func);
  }

  public void connect_nav(Gtk.ScrolledWindow parent, Gtk.Widget widget_up) {
    // FIXME: "Up" key works between lists, but not from top list - no keynav_failed event is fired
    // (and moving between the lists doesn't seem to trigger it anyway - only moving down from
    // the bottom list)
    Utils.connect_vadjustment(parent, user_list_box);
    Utils.connect_vadjustment(parent, subscribed_list_box);
  }

  public void hide_user_list_entry () {
    new_list_entry.hide ();
    new_list_entry.no_show_all = true;
    user_list_label.visible = true;
    //user_list_frame.margin_top = 24;
    show_create_entry = false;
    upper_separator.visible = false;
    upper_separator.no_show_all = true;
  }

  [GtkCallback]
  private void row_activated (Gtk.ListBoxRow row) {
    if (row is NewListEntry) {
      ((NewListEntry)row).reveal ();
    } else {
      var entry = (ListListEntry) row;
      var bundle = new Cb.Bundle ();
      bundle.put_int64 (ListStatusesPage.KEY_LIST_ID, entry.id);
      bundle.put_string (ListStatusesPage.KEY_TITLE, entry.title);
      bundle.put_string (ListStatusesPage.KEY_NAME, entry.name);
      bundle.put_bool (ListStatusesPage.KEY_USER_LIST, entry.user_list);
      bundle.put_string (ListStatusesPage.KEY_DESCRIPTION, entry.description);
      bundle.put_string (ListStatusesPage.KEY_CREATOR, entry.creator_screen_name);
      bundle.put_int (ListStatusesPage.KEY_N_SUBSCRIBERS, entry.n_subscribers);
      bundle.put_int (ListStatusesPage.KEY_N_MEMBERS, entry.n_members);
      bundle.put_int64 (ListStatusesPage.KEY_CREATED_AT, entry.created_at);
      bundle.put_string (ListStatusesPage.KEY_MODE, entry.mode);

      main_window.main_widget.switch_page (Page.LIST_STATUSES, bundle);
    }
  }

  public async void load_lists (int64 user_id, string name = "", string screen_name = "") {
    if (user_id == 0)
      user_id = account.id;

    var collect_obj = new Collect (2);

    collect_obj.finished.connect (() => {
      load_lists.callback ();
    });

    var call = account.proxy.new_call ();
    call.set_function ("1.1/lists/subscriptions.json");
    call.set_method ("GET");
    call.add_param ("count", "200");
    call.add_param ("user_id", user_id.to_string ());
    Cb.Utils.load_threaded_async.begin (call, null, (_, res) => {
      Json.Node? root = null;
      try {
        root = Cb.Utils.load_threaded_async.end (res);
      } catch (GLib.Error e) {
        warning (e.message);
      }

      uint n_subscribed_list = lists_received_cb (root, subscribed_list_box);
      if (n_subscribed_list == 0) {
        subscribed_list_box.hide ();
        subscribed_list_frame.hide ();
        subscribed_list_label.hide ();
      } else {
        subscribed_list_box.show ();
        subscribed_list_frame.show ();
        subscribed_list_label.show ();
      }
      collect_obj.emit ();
    });

    var user_call = account.proxy.new_call ();
    user_call.set_function ("1.1/lists/ownerships.json");
    user_call.set_method ("GET");
    user_call.add_param ("user_id", user_id.to_string ());
    user_call.add_param ("count", "200");
    Cb.Utils.load_threaded_async.begin (user_call, null, (_, res) => {
      Json.Node? root = null;
      try {
        root = Cb.Utils.load_threaded_async.end (res);
      } catch (GLib.Error e) {
        warning (e.message);
      }

      uint n_user_list = lists_received_cb (root, user_list_box);
      if (n_user_list == 0 && !show_create_entry) {
        user_list_label.hide ();
        user_list_box.hide ();
        user_list_frame.hide ();
        user_list_frame.margin_top = 0;
      } else {
        user_list_label.visible = !show_create_entry;
        user_list_frame.margin_top = show_create_entry ? 24 : 0;
        user_list_box.show ();
        user_list_frame.show ();
        user_lists_revealer.reveal_child = n_user_list > 0;
      }
      collect_obj.emit ();
    });

    // TRANSLATORS: Value is user's name - used for accessibility text in "list of lists that this user has subscribed to"
    var accessible_name = user_id == account.id ? _("Subscribed lists") : _("%s subscribed lists").printf(name);
    this.subscribed_list_box.get_accessible().set_name(accessible_name);
    // TRANSLATORS: Value is user's name - used for accessibility text in "list of lists that this user created"
    accessible_name = user_id == account.id ? _("Your lists") : _("%s lists").printf(name);
    this.user_list_box.get_accessible().set_name(accessible_name);

    yield;
  }

  private uint lists_received_cb (Json.Node?  root,
                                  Gtk.ListBox list_box)
  { // {{{
    if (root == null)
      return 0;

    int64[] ids = {};
    var arr = root.get_object ().get_array_member ("lists");
    arr.foreach_element ((array, index, node) => {
      var obj = node.get_object ();
      ids += obj.get_int_member ("id");
      var entry = new ListListEntry.from_json_data (obj, account);
      add_list(entry, list_box);
    });
    var size_after = list_box.get_children().length();
    var list_count = arr.get_length ();

    if (size_after != list_count) {
      foreach (var entry in list_box.get_children()) {
        var id = ((ListListEntry)entry).id;
        if (!(id in ids)) {
          remove_list(id);
        }
      }
    }

    return list_count;
  } // }}}


  public void remove_list (int64 list_id) {
    uint n_user_lists = user_list_box.get_children ().length ();
    user_list_box.foreach ((w) => {
      if (!(w is ListListEntry))
        return;

      if (((ListListEntry)w).id == list_id) {
        user_list_box.remove (w);
        if (n_user_lists - 1 == 0)
          user_lists_revealer.reveal_child = false;
      }
    });

    subscribed_list_box.foreach ((w) => {
      if (!(w is ListListEntry))
        return;

      if (((ListListEntry)w).id == list_id) {
        subscribed_list_box.remove (w);
      }
    });

    if (subscribed_list_box.get_children ().length () == 0) {
      subscribed_list_label.hide ();
      subscribed_list_frame.hide ();
    }
  }

  public void add_list (ListListEntry entry, Gtk.ListBox? list_box = null) {
    if (list_box == null) {
      if (entry.user_list) {
        list_box = user_list_box;
      }
      else {
        list_box = subscribed_list_box;
      }
    }

    var updated = false;
    // Avoid duplicates
    var user_lists = list_box.get_children ();
    foreach (Gtk.Widget w in user_lists) {
      if (!(w is ListListEntry))
        continue;
      var list_entry = (ListListEntry)w;
      if (list_entry.id == entry.id) {
        update_list_entry_from_entry(list_entry, entry);
        updated = true;
        break;
      }
    }

    if (!updated) {
      list_box.add (entry);
    }

    if (entry.user_list) {
      user_lists_revealer.reveal_child = true;
    } else if (list_box.get_children().length() > 0) {
      if (list_box == user_list_box) {
        user_list_frame.show ();
        user_list_box.show ();
        user_list_label.show ();
      }
      else {
        subscribed_list_frame.show ();
        subscribed_list_box.show ();
        subscribed_list_label.show ();
      }
    }
  }

  public void update_list (int64 list_id, string title, string name, string description, string mode) {
    user_list_box.foreach ((w) => {
      if (!(w is ListListEntry))
        return;

      var lle = (ListListEntry) w;
      if (lle.id == list_id) {
        update_list_entry(lle, title, name, description, mode);
      }
    });
  }

  private void update_list_entry_from_entry (ListListEntry list_entry, ListListEntry src_entry) {
    update_list_entry(list_entry, src_entry.title, src_entry.name, src_entry.description, src_entry.mode);
  }

  private void update_list_entry (ListListEntry list_entry, string title, string name, string description, string mode) {
    list_entry.title = title;
    list_entry.name = name;
    list_entry.description = description;
    list_entry.mode = mode;
    list_entry.queue_draw ();
  }

  public void update_member_count (int64 list_id, int increase) {
    var lists = user_list_box.get_children ();
    foreach (var list in lists) {
      if (!(list is ListListEntry))
        continue;

      var lle = (ListListEntry) list;
      if (lle.id == list_id) {
        lle.n_members += increase;
        break;
      }
    }
  }

  public TwitterList[] get_user_lists () {
    GLib.List<weak Gtk.Widget> children = user_list_box.get_children ();
    TwitterList[] lists = new TwitterList[children.length ()];
    int i = 0;
    foreach (Gtk.Widget w in children) {
      assert (w is ListListEntry);
      var lle = (ListListEntry) w;
      lists[i].id = lle.id;
      lists[i].name = lle.name;
      lists[i].description = lle.description;
      lists[i].mode = lle.mode;
      lists[i].n_members = lle.n_members;
      i ++;
    }
    return lists;
  }

  public void clear_lists () {
    user_list_box.foreach ((w) => { user_list_box.remove (w);});
    subscribed_list_box.foreach ((w) => {subscribed_list_box.remove (w);});
  }

  [GtkCallback]
  private void new_list_create_activated_cb (string list_name) { // {{{
    if (list_name.strip ().length <= 0)
      return;

    new_list_entry.sensitive = false;
    var call = account.proxy.new_call ();
    call.set_function ("1.1/lists/create.json");
    call.set_method ("POST");
    call.add_param ("name", list_name);
    call.invoke_async.begin (null, (o, res) => {
      try {
        call.invoke_async.end (res);
      } catch (GLib.Error e) {
        Utils.show_error_dialog (TweetUtils.failed_request_to_error (call, e), this.main_window);
        new_list_entry.sensitive = true;
        return;
      }
      var parser = new Json.Parser ();
      try {
        parser.load_from_data (call.get_payload ());
      } catch (GLib.Error e) {
        critical (e.message);
        return;
      }
      var root = parser.get_root ().get_object ();
      var entry = new ListListEntry.from_json_data (root, account);
      add_list (entry);

      var bundle = new Cb.Bundle ();
      bundle.put_int64 (ListStatusesPage.KEY_LIST_ID, entry.id);
      bundle.put_string (ListStatusesPage.KEY_TITLE, entry.title);
      bundle.put_string (ListStatusesPage.KEY_NAME, entry.name);
      bundle.put_bool (ListStatusesPage.KEY_USER_LIST, true);
      bundle.put_string (ListStatusesPage.KEY_DESCRIPTION, entry.description);
      bundle.put_string (ListStatusesPage.KEY_CREATOR, entry.creator_screen_name);
      bundle.put_int (ListStatusesPage.KEY_N_SUBSCRIBERS, entry.n_subscribers);
      bundle.put_int (ListStatusesPage.KEY_N_MEMBERS, entry.n_members);
      bundle.put_int64 (ListStatusesPage.KEY_CREATED_AT, entry.created_at);
      bundle.put_string (ListStatusesPage.KEY_MODE, entry.mode);

      main_window.main_widget.switch_page (Page.LIST_STATUSES, bundle);
      new_list_entry.sensitive = true;
    });
  } // }}}

  public void unreveal () {
    new_list_entry.unreveal ();
  }

  [GtkCallback]
  private bool new_list_box_keynav_failed_cb (Gtk.DirectionType direction) {
    if (direction == Gtk.DirectionType.DOWN) {
      if (user_list_box.visible) {
        user_list_box.child_focus (direction);
        return Gdk.EVENT_STOP;
      } else if (subscribed_list_box.visible) {
        subscribed_list_box.child_focus (direction);
        return Gdk.EVENT_STOP;
      }
    }
    return Gdk.EVENT_PROPAGATE;
  }

  [GtkCallback]
  private bool user_list_box_keynav_failed_cb (Gtk.DirectionType direction) {
    if (direction == Gtk.DirectionType.UP) {
      if (new_list_box.visible) {
        new_list_box.child_focus (direction);
        return Gdk.EVENT_STOP;
      }
    } else if (direction == Gtk.DirectionType.DOWN) {
      if (subscribed_list_box.visible) {
        subscribed_list_box.child_focus (direction);
        return Gdk.EVENT_STOP;
      }
    }
    return Gdk.EVENT_PROPAGATE;
  }

  [GtkCallback]
  private bool subscribed_list_box_keynav_failed_cb (Gtk.DirectionType direction) {
    if (direction == Gtk.DirectionType.UP) {
      if (user_list_box.visible) {
        user_list_box.child_focus (direction);
        return Gdk.EVENT_STOP;
      } else if (new_list_box.visible) {
        new_list_box.child_focus (direction);
        return Gdk.EVENT_STOP;
      }
    }
    return Gdk.EVENT_PROPAGATE;
  }

  [GtkCallback]
  private void revealer_child_revealed_cb (GLib.Object source, GLib.ParamSpec spec) {
    Gtk.Revealer revealer = (Gtk.Revealer) source;
    if (revealer.child_revealed)
      revealer.show ();
    else
      revealer.hide ();
  }
}
