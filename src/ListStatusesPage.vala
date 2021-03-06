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

[GtkTemplate (ui = "/uk/co/ibboard/cawbird/ui/list-statuses-page.ui")]
class ListStatusesPage : ScrollWidget, Cb.MessageReceiver, IPage {
  public const int KEY_USER_LIST     = 0;
  public const int KEY_NAME          = 1;
  public const int KEY_DESCRIPTION   = 2;
  public const int KEY_CREATOR       = 3;
  public const int KEY_N_SUBSCRIBERS = 4;
  public const int KEY_N_MEMBERS     = 5;
  public const int KEY_CREATED_AT    = 6;
  public const int KEY_MODE          = 7;
  public const int KEY_LIST_ID       = 8;
  public const int KEY_TITLE         = 9;

  public int id                             { get; set; }
  private unowned MainWindow main_window;
  public unowned MainWindow window {
    set {
      main_window = value;
      tweet_list.main_window = main_window;
    }
  }
  public unowned Account account;
  private int64 list_id;
  private uint tweet_remove_timeout = 0;
  [GtkChild]
  private TweetListBox tweet_list;
  [GtkChild]
  private Gtk.MenuButton delete_button;
  [GtkChild]
  private Gtk.Button edit_button;
  [GtkChild]
  private Gtk.Label description_label;
  [GtkChild]
  private Gtk.Label title_label;
  [GtkChild]
  private Gtk.Label creator_label;
  [GtkChild]
  private Gtk.Label subscribers_label;
  [GtkChild]
  private Gtk.Label members_label;
  [GtkChild]
  private Gtk.Label created_at_label;
  [GtkChild]
  private Gtk.Stack title_stack;
  [GtkChild]
  private Gtk.Entry title_entry;
  [GtkChild]
  private Gtk.Stack description_stack;
  [GtkChild]
  private Gtk.Entry description_entry;
  [GtkChild]
  private Gtk.Stack delete_stack;
  [GtkChild]
  private Gtk.Button cancel_button;
  [GtkChild]
  private Gtk.Stack edit_stack;
  [GtkChild]
  private Gtk.Button save_button;
  [GtkChild]
  private Gtk.Stack mode_stack;
  [GtkChild]
  private Gtk.Label mode_label;
  [GtkChild]
  private Gtk.ComboBoxText mode_combo_box;
  [GtkChild]
  private Gtk.Button refresh_button;
  private bool loading = false;


  public ListStatusesPage (int id, Account account) {
    this.id = id;
    this.account = account;
    this.tweet_list.account = account;
    this.scrolled_to_end.connect (load_older);
    this.scrolled_to_start.connect (handle_scrolled_to_start);
    tweet_list.set_adjustment (this.get_vadjustment ());
  }

  protected virtual void stream_message_received (Cb.StreamMessageType type, Json.Node root) {
    if (type == Cb.StreamMessageType.EVENT_BLOCK) {
      hide_tweets_from (root, Cb.TweetState.HIDDEN_AUTHOR_BLOCKED, Cb.TweetState.HIDDEN_RETWEETER_BLOCKED);
    } else if (type == Cb.StreamMessageType.EVENT_UNBLOCK) {
      show_tweets_from (root, Cb.TweetState.HIDDEN_AUTHOR_BLOCKED, Cb.TweetState.HIDDEN_RETWEETER_BLOCKED);
    } else if (type == Cb.StreamMessageType.EVENT_MUTE) {
      hide_tweets_from (root, Cb.TweetState.HIDDEN_AUTHOR_MUTED, Cb.TweetState.HIDDEN_RETWEETER_MUTED);
    } else if (type == Cb.StreamMessageType.EVENT_UNMUTE) {
      show_tweets_from (root, Cb.TweetState.HIDDEN_AUTHOR_MUTED, Cb.TweetState.HIDDEN_RETWEETER_MUTED);
    } else if (type == Cb.StreamMessageType.EVENT_HIDE_RTS) {
      tweet_list.hide_retweets_from (get_user_id (root), Cb.TweetState.HIDDEN_RTS_DISABLED);      
    } else if (type == Cb.StreamMessageType.EVENT_SHOW_RTS) {
      tweet_list.show_retweets_from (get_user_id (root), Cb.TweetState.HIDDEN_RTS_DISABLED);        
    }
  }

  private int64 get_user_id (Json.Node root) {
    return root.get_object ().get_object_member ("target").get_int_member ("id");
  }

  protected void show_tweets_from (Json.Node root, Cb.TweetState tweet_reason, Cb.TweetState retweet_reason = 0) {
    if (retweet_reason == 0) {
      retweet_reason = tweet_reason;
    }
    int64 user_id = get_user_id(root);
    tweet_list.show_tweets_from (user_id, tweet_reason);
    tweet_list.show_retweets_from (user_id, retweet_reason);
  }

  protected void hide_tweets_from (Json.Node root, Cb.TweetState tweet_reason, Cb.TweetState retweet_reason = 0) {
    if (retweet_reason == 0) {
      retweet_reason = tweet_reason;
    }
    int64 user_id = get_user_id(root);
    tweet_list.hide_tweets_from (user_id, tweet_reason);
    tweet_list.hide_retweets_from (user_id, retweet_reason);
  }

  /**
   * va_list params:
   *  - int64 list_id - The id of the list to show
   *  - string name - The lists's name
   *  - bool user_list - true if the list belongs to the user, false otherwise
   *  - string description - the lists's description
   *  - string creator
   *  - int subscribers_count
   *  - int memebers_count
   *  - int64 created_at
   *  - string mode
   */
  public void on_join (int page_id, Cb.Bundle? args) {
    int64 list_id = args.get_int64 (KEY_LIST_ID);
    if (list_id == 0) {
      list_id = this.list_id;
      return;
      // Continue
    }

    string? list_name = args.get_string (KEY_NAME);
    if (list_name != null) {
      string list_title = args.get_string (KEY_TITLE);
      bool user_list = args.get_bool (KEY_USER_LIST);
      string description = args.get_string (KEY_DESCRIPTION);
      string creator = args.get_string (KEY_CREATOR);
      int n_subscribers = args.get_int (KEY_N_SUBSCRIBERS);
      int n_members = args.get_int (KEY_N_MEMBERS);
      int64 created_at = args.get_int64 (KEY_CREATED_AT);
      string mode = args.get_string (KEY_MODE);

      delete_button.sensitive = user_list;
      edit_button.sensitive = user_list;
      title_label.label = list_title;
      description_label.label = description;
      creator_label.label = creator;
      members_label.label = "%'d".printf (n_members);
      subscribers_label.label = "%'d".printf (n_subscribers);
      created_at_label.label = new GLib.DateTime.from_unix_local (created_at).format ("%x, %X");
      mode_label.label = Utils.capitalize (mode);

      // TRANSLATORS: "%s" is the user's name for the list - e.g. "Contributors" when looking at https://twitter.com/i/lists/1285277968676331522
      var accessible_name = _("%s list tweets").printf(list_title);
      tweet_list.get_accessible().set_name(accessible_name);
      tweet_list.get_accessible().set_description(accessible_name);
    }

    debug (@"Showing list with id $list_id");
    if (list_id == this.list_id) {
      this.list_id = list_id;
      load_newer.begin ();
    } else {
      this.list_id = list_id;
      tweet_list.model.clear ();
      load_newest.begin ();
    }

  }

  public void on_leave () {}

  private async void load_newest () {
    loading = true;
    tweet_list.set_unempty ();
    uint requested_tweet_count = 25;
    var call = account.proxy.new_call ();
    call.set_function ("1.1/lists/statuses.json");
    call.set_method ("GET");
    debug ("USING LIST ID %s", list_id.to_string ());
    call.add_param ("list_id", list_id.to_string ());
    call.add_param ("count", requested_tweet_count.to_string ());
    call.add_param ("tweet_mode", "extended");
    call.add_param ("include_ext_alt_text", "true");

    Json.Node? root = null;
    try {
      root = yield Cb.Utils.load_threaded_async (call, null);
    } catch (GLib.Error e) {
      if (e.message.down () == "not found") {
        tweet_list.set_empty ();
      }
      warning (e.message);
      loading = false;
      return;
    }

    var root_array = root.get_array ();
    if (root_array.get_length () == 0) {
      tweet_list.set_empty ();
      loading = false;
      return;
    }
    TweetUtils.work_array (root_array,
                           tweet_list,
                           account);

    loading = false;
  }

  private async void load_older () {
    if (loading)
      return;

    loading = true;
    uint requested_tweet_count = 25;
    var call = account.proxy.new_call ();
    call.set_function ("1.1/lists/statuses.json");
    call.set_method ("GET");
    call.add_param ("list_id", list_id.to_string ());
    call.add_param ("max_id", (tweet_list.model.min_id -1).to_string ());
    call.add_param ("count", requested_tweet_count.to_string ());
    call.add_param ("tweet_mode", "extended");
    call.add_param ("include_ext_alt_text", "true");

    Json.Node? root = null;
    try {
      root = yield Cb.Utils.load_threaded_async (call, null);
    } catch (GLib.Error e) {
      warning (e.message);
      return;
    }

    var root_array = root.get_array ();
    TweetUtils.work_array (root_array,
                           tweet_list,
                           account);
    loading = false;
  }

  [GtkCallback]
  private void edit_button_clicked_cb () {
    title_stack.visible_child = title_entry;
    description_stack.visible_child = description_entry;
    delete_stack.visible_child = cancel_button;
    edit_stack.visible_child = save_button;
    mode_stack.visible_child = mode_combo_box;

    title_entry.text = title_label.label;
    description_entry.text = description_label.label;
    mode_combo_box.active_id = mode_label.label;
  }

  [GtkCallback]
  private void cancel_button_clicked_cb () {
    title_stack.visible_child = title_label;
    description_stack.visible_child = description_label;
    delete_stack.visible_child = delete_button;
    edit_stack.visible_child = edit_button;
    mode_stack.visible_child = mode_label;
  }

  [GtkCallback]
  private void save_button_clicked_cb () {
    // Make everything go back to normal
    title_label.label = title_entry.get_text();
    description_label.label = description_entry.text;
    mode_label.label = mode_combo_box.active_id;
    cancel_button_clicked_cb ();
    edit_button.sensitive = false;
    delete_button.sensitive = false;
    var call = account.proxy.new_call ();
    call.set_function ("1.1/lists/update.json");
    call.set_method ("POST");
    call.add_param ("list_id", list_id.to_string ());
    call.add_param ("name", title_label.label);
    call.add_param ("mode", mode_label.label.down ());
    call.add_param ("description", description_label.label);
    main_window.set_window_title (this.get_title ());

    call.invoke_async.begin (null, (o, res) => {
      try {
        call.invoke_async.end (res);
      } catch (GLib.Error e) {
        Utils.show_error_dialog (TweetUtils.failed_request_to_error (call, e), this.main_window);
      }
      account.user_stream.inject_tweet(Cb.StreamMessageType.EVENT_LIST_UPDATED, call.get_payload());
      edit_button.sensitive = true;
      delete_button.sensitive = true;
    });
  }

  [GtkCallback]
  private void delete_confirmation_item_clicked_cb () {
    ListUtils.delete_list.begin (account, list_id, (obj, res) => {
      try {
        ListUtils.delete_list.end (res);
        // Go back to the ListsPage and tell it to remove this list
        var bundle = new Cb.Bundle ();
        bundle.put_int (ListsPage.KEY_MODE, ListsPage.MODE_DELETE);
        bundle.put_int64 (ListsPage.KEY_LIST_ID, list_id);
        main_window.main_widget.switch_page (Page.LISTS, bundle);
      } catch (GLib.Error e) {
        Utils.show_error_dialog (e, this.main_window);
      }
    });
  }

  [GtkCallback]
  private void refresh_button_clicked_cb () {
    refresh_button.sensitive = false;
    load_newer.begin (() => {
      refresh_button.sensitive = true;
    });
  }

  [GtkCallback]
  private void tweet_activated_cb (Gtk.ListBoxRow row) {
    if (row is TweetListEntry) {
      var bundle = new Cb.Bundle ();
      bundle.put_int (TweetInfoPage.KEY_MODE, TweetInfoPage.BY_INSTANCE);
      bundle.put_object (TweetInfoPage.KEY_TWEET, ((TweetListEntry)row).tweet);
      main_window.main_widget.switch_page (Page.TWEET_INFO, bundle);
    } else
      warning ("row is of unknown type");
  }

  private async void load_newer () {
    var call = account.proxy.new_call ();
    call.set_function ("1.1/lists/statuses.json");
    call.set_method ("GET");
    call.add_param ("list_id", list_id.to_string ());
    call.add_param ("count", "30");
    call.add_param ("tweet_mode", "extended");
    call.add_param ("include_ext_alt_text", "true");
    int64 since_id = tweet_list.model.max_id;
    if (since_id < 0)
      since_id = 1;

    call.add_param ("since_id", since_id.to_string ());
    debug ("Getting statuses since %s for list_id %s",
           since_id.to_string (), list_id.to_string ());

    Json.Node? root = null;
    try {
      root = yield Cb.Utils.load_threaded_async (call, null);
    } catch (GLib.Error e) {
      warning (e.message);
      return;
    }

    var root_array = root.get_array ();
    if (root_array.get_length () > 0) {
      TweetUtils.work_array (root_array,
                             tweet_list,
                             account);
    }
  }

  protected void handle_scrolled_to_start() {
    if (tweet_remove_timeout != 0)
      return;

    if (tweet_list.model.get_n_items () > DefaultTimeline.REST) {
      tweet_remove_timeout = GLib.Timeout.add (500, () => {
        if (!scrolled_up) {
          tweet_remove_timeout = 0;
          return false;
        }

        tweet_list.model.remove_oldest_n_visible (tweet_list.model.get_n_items () - DefaultTimeline.REST);
        tweet_remove_timeout = 0;
        return GLib.Source.REMOVE;
      });
    } else if (tweet_remove_timeout != 0) {
      GLib.Source.remove (tweet_remove_timeout);
      tweet_remove_timeout = 0;
    }
  }

  public string get_title () {
    return title_label.label;
  }

  public void create_radio_button (Gtk.RadioButton? group) {}
  public Gtk.RadioButton? get_radio_button () {return null;}

  public void rerun_filters () {
    TweetUtils.rerun_filters(tweet_list, account);
  }
}
