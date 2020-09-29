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

[GtkTemplate (ui = "/uk/co/ibboard/cawbird/ui/search-page.ui")]
class SearchPage : IPage, Gtk.Box {
  public const int KEY_QUERY = 0;
  private const int USER_COUNT = 3;
  /** The unread count here is always zero */
  public int unread_count {
    get { return 0; }
  }
  public unowned Account account;
  public int id                         { get; set; }
  private unowned MainWindow main_window;
  public unowned MainWindow window {
    set {
      main_window = value;
    }
  }

  [GtkChild]
  private Gtk.SearchEntry search_entry;
  [GtkChild]
  private Gtk.Button search_button;
  [GtkChild]
  private TweetListBox tweet_list;
  [GtkChild]
  private ListBox user_list;
  [GtkChild]
  private Gtk.Label users_header;
  [GtkChild]
  private Gtk.Label tweets_header;
  [GtkChild]
  private ScrollWidget scroll_widget;
  private Gtk.RadioButton radio_button;
  private GLib.Cancellable? cancellable = null;
  private LoadMoreEntry load_more_entry = new LoadMoreEntry ();
  private string search_query;
  private int user_page = 1;
  private Gtk.Widget last_focus_widget;
  private Collect collect_obj;
  private uint remove_content_timeout = 0;
  private string last_search_query;
  private bool loading_tweets = false;  
  private bool loading_users  = false;
  private Json.Node? pending_user = null;


  public SearchPage (int id, Account account) {
    this.id = id;
    this.account = account;

    tweet_list.set_header_func (header_func);
    tweet_list.row_activated.connect (tweet_row_activated_cb);
    tweet_list.retry_button_clicked.connect (retry_button_clicked_cb);
    tweet_list.account = account;
    tweet_list.set_placeholder_text(_("No tweets found"));
    Utils.connect_vadjustment (scroll_widget, tweet_list);
    user_list.set_header_func (header_func);
    user_list.set_sort_func (twitter_item_sort_func);
    user_list.row_activated.connect (user_row_activated_cb);
    user_list.retry_button_clicked.connect (retry_button_clicked_cb);
    user_list.set_placeholder_text(_("No users found"));
    // We could connect the vadjust for the user list as well, but as it's the top then we won't bother

    search_entry.keynav_failed.connect((direction) => {
      if (direction == Gtk.DirectionType.DOWN) {
        Gtk.Widget? first_row = user_list.get_first_visible_row();
        if (first_row != null) {
          first_row.grab_focus();
          return true;
        }
        else {
          first_row = tweet_list.get_first_visible_row();
          if (first_row != null) {
            first_row.grab_focus();
            return true;
          }
        }
      }
      return false;
    });
    search_button.keynav_failed.connect((direction) => {
      if (direction == Gtk.DirectionType.DOWN) {
        Gtk.Widget? first_row = user_list.get_first_visible_row();
        if (first_row != null) {
          first_row.grab_focus();
          return true;
        }
        else {
          first_row = tweet_list.get_first_visible_row();
          if (first_row != null) {
            first_row.grab_focus();
            return true;
          }
        }
      }
      return false;
    });
    user_list.keynav_failed.connect((direction) => {
      if (direction == Gtk.DirectionType.UP) {
        search_entry.grab_focus();
        return true;
      }
      else if (direction == Gtk.DirectionType.DOWN) {
        Gtk.Widget? first_row = tweet_list.get_first_visible_row();
        if (first_row != null) {
          first_row.grab_focus();
          return true;
        }
      }
      return false;
    });
    tweet_list.keynav_failed.connect((direction) => {
      if (direction == Gtk.DirectionType.UP) {
        Gtk.Widget? first_row = user_list.get_last_visible_row();
        if (first_row != null) {
          first_row.grab_focus();
          return true;
        }
        else {
         search_entry.grab_focus();
        }
        return true;
      }
      return false;
    });

    search_button.clicked.connect (() => {
      search_for (search_entry.get_text());
    });
    load_more_entry.get_button ().clicked.connect (() => {
      user_page++;
      load_users ();
    });
    scroll_widget.scrolled_to_end.connect (load_tweets);
    tweet_list.get_placeholder ().hide ();
    user_list.get_placeholder ().hide ();
  }

  [GtkCallback]
  private void search_entry_activate_cb () {
    search_for (search_entry.get_text ());
  }

  private void retry_button_clicked_cb () {
    search_for (last_search_query);
  }

  /**
   * see IPage#onJoin
   */
  public void on_join (int page_id, Cb.Bundle? args) {
    string? term = args != null ? args.get_string (KEY_QUERY) : null;

    if (this.remove_content_timeout != 0) {
      GLib.Source.remove (this.remove_content_timeout);
      this.remove_content_timeout = 0;
    }
    else {
      scroll_widget.hide();
    }


    if (term == null) {
      if (last_focus_widget != null &&
          last_focus_widget.parent != null)
        last_focus_widget.grab_focus ();
      else
        search_entry.grab_focus ();
      return;
    }

    search_for (term, true);
  }

  public override void dispose () {
    if (this.remove_content_timeout != 0) {
      GLib.Source.remove (this.remove_content_timeout);
      this.remove_content_timeout = 0;
    }

    base.dispose ();
  }

  public void on_leave () {
    this.remove_content_timeout = GLib.Timeout.add (3 * 1000 * 60, () => {
      tweet_list.remove_all ();
      tweet_list.get_placeholder ().hide ();
      user_list.remove_all();
      user_list.get_placeholder ().hide ();
      scroll_widget.hide();
      this.last_focus_widget  = null;

      this.remove_content_timeout = 0;
      return GLib.Source.REMOVE;
    });
  }

  public void search_for (string search_term, bool set_text = false) {
    if (search_term.length == 0) {
      tweet_list.set_empty();
      user_list.set_empty();
      return;
    }

    this.last_search_query = search_term;

    if (this.cancellable != null) {
      debug ("Cancelling earlier search...");
      this.cancellable.cancel ();
    }

    this.cancellable = new GLib.Cancellable ();

    string q = this.last_search_query;//search_term.copy ();

    // clear the list
    tweet_list.remove_all ();
    tweet_list.set_unempty ();
    user_list.remove_all();
    user_list.set_unempty();
    user_list.get_placeholder().show();
    scroll_widget.show();
    // Set accessible text
    var accessible_name = _("Users matching \"%s\"".printf(q));
    user_list.get_accessible().set_name(accessible_name);
    user_list.get_accessible().set_description(accessible_name);
    accessible_name = _("Tweets matching \"%s\"".printf(q));
    tweet_list.get_accessible().set_name(accessible_name);
    tweet_list.get_accessible().set_description(accessible_name);


    if (set_text)
      search_entry.set_text(q);

    this.search_query    = q;
    this.user_page       = 1;

    collect_obj = new Collect (2);
    collect_obj.finished.connect (show_entries);

    load_tweets ();
    load_users ();
  }

  private void tweet_row_activated_cb (Gtk.ListBoxRow row) {
    this.last_focus_widget = row;
    var bundle = new Cb.Bundle ();
    bundle.put_int (TweetInfoPage.KEY_MODE, TweetInfoPage.BY_INSTANCE);
    bundle.put_object (TweetInfoPage.KEY_TWEET, ((TweetListEntry)row).tweet);
    main_window.main_widget.switch_page (Page.TWEET_INFO, bundle);
  }

  private void user_row_activated_cb (Gtk.ListBoxRow row) {
    this.last_focus_widget = row;
    var user_row = (UserListEntry)row;
    var bundle = new Cb.Bundle ();
    bundle.put_int64 (ProfilePage.KEY_USER_ID, user_row.user_id);
    bundle.put_string (ProfilePage.KEY_SCREEN_NAME, user_row.screen_name);
    main_window.main_widget.switch_page (Page.PROFILE, bundle);
  }

  private void header_func (Gtk.ListBoxRow row, Gtk.ListBoxRow? before) {
    Gtk.Widget header = row.get_header ();
    if (header != null)
      return;

    if (before == null) {
      if (row is UserListEntry) {
        row.set_header (users_header);
      } else if (row is TweetListEntry) {
        row.set_header (tweets_header);
      }
    }
  }

  private void load_users () {
    if (this.loading_users)
      return;

    this.loading_users = true;
    var user_call = account.proxy.new_call ();
    user_call.set_method ("GET");
    user_call.set_function ("1.1/users/search.json");
    user_call.add_param ("q", this.search_query);
    user_call.add_param ("count", (USER_COUNT + 1).to_string ());
    user_call.add_param ("include_entities", "false");
    user_call.add_param ("page", user_page.to_string ());
    Cb.Utils.load_threaded_async.begin (user_call, cancellable, (_, res) => {
      Json.Node? root = null;
      try {
        root = Cb.Utils.load_threaded_async.end (res);
      } catch (GLib.Error e) {
        warning (e.message);
        user_list.set_error (e.message);

        if (!collect_obj.done)
          collect_obj.emit ();

        this.loading_users = false;
        return;
      }

      if (root == null) {
        this.loading_users = false;
        debug ("load_users: root is null");
        if (!collect_obj.done)
          collect_obj.emit ();

        return;
      }

      var users = root.get_array ();

      if (user_list.get_children().length() + users.get_length() <= 0) {
        user_list.set_empty ();
        user_list.get_placeholder().show();
      }

      var final_page = false;

      if (user_page > 1) {
        add_user_to_list(pending_user);
      }
      
      pending_user = null;

      if (this.loading_tweets) {
        // Keep a "loading" placeholder showing
        tweet_list.get_placeholder ().show ();
      }

      users.foreach_element ((array, index, node) => {
        if (index > USER_COUNT - 1) {
          // Keep one item back so that we know there's more to load
          pending_user = node;
          return;
        }

        final_page |= add_user_to_list(node);
      });
      if (!final_page && pending_user != null) {
        if (load_more_entry.parent == null) {
          user_list.add (load_more_entry);
        }
        
        load_more_entry.show ();
      } else {
        load_more_entry.hide ();
      }

      if (!collect_obj.done)
        collect_obj.emit ();

      this.loading_users = false;
    });
  }

  private bool add_user_to_list(Json.Node node) {
    var final_page = false;
    var user_obj = node.get_object ();
    var screen_name = user_obj.get_string_member ("screen_name");    
    var exists = false;
    var children = user_list.get_children();
    children.reverse();

    foreach (Gtk.Widget widget in children) {
      if (widget is UserListEntry && ((UserListEntry)widget).screen_name == screen_name) {
        // We got overlap
        final_page = true;
        exists = true;
        break;
      }
    }

    if (!exists) {
      var entry = new UserListEntry ();
      string avatar_url = user_obj.get_string_member ("profile_image_url_https");

      if (this.get_scale_factor () == 2)
        avatar_url = avatar_url.replace ("_normal", "_bigger");

      entry.user_id = user_obj.get_int_member ("id");
      entry.set_screen_name ("@" + screen_name);
      entry.name = user_obj.get_string_member ("name").strip ();
      entry.avatar_url = avatar_url;
      entry.verified = user_obj.get_boolean_member ("verified");
      entry.protected_account = user_obj.get_boolean_member ("protected");
      entry.show_settings = false;
      user_list.add (entry);
    }
    return final_page;
  }

  private void load_tweets () {
    if (loading_tweets)
      return;

    this.loading_tweets = true;

    TweetUtils.search_for_tweets.begin (account, this.search_query + " -filter:retweets", (this.tweet_list.model.min_id - 1), -1, 35, cancellable, (_, res) => {
      Cb.Tweet[] tweets;
      try {
        tweets = TweetUtils.search_for_tweets.end (res);
      } catch (GLib.Error e) {
        warning (e.message);
        tweet_list.set_error (e.message);
        this.loading_tweets = false;
        if (!collect_obj.done)
          collect_obj.emit ();
        return;
      }

      if (tweets.length <= 0) {
        tweet_list.set_empty ();
        tweet_list.get_placeholder().show();
      }

      foreach (Cb.Tweet tweet in tweets) {
        tweet_list.model.add (tweet);
      }

      this.loading_tweets = false;
      if (!collect_obj.done)
        collect_obj.emit ();

    });
  }

  private void show_entries (GLib.Error? e) {
    if (e != null) {
      user_list.set_error (e.message);
      user_list.set_empty ();
      tweet_list.set_empty ();
      this.loading_tweets = false;
      this.loading_users = false;
      return;
    }

    this.loading_tweets = false;
    this.loading_users = false;

    /* Work around a problem with GtkListBox where the entries are not redrawn for some reason.
       This happened whenever we remove_all'd all the rows from the list while it was not mapped */
    tweet_list.queue_draw ();
  }

  public void create_radio_button (Gtk.RadioButton? group){
    radio_button = new BadgeRadioButton (group, "cawbird-edit-find-symbolic", _("Search"));
  }

  public Gtk.RadioButton? get_radio_button() {
    return radio_button;
  }


  public string get_title () {
    return _("Search");
  }

  public bool handles_double_open () {
    return true;
  }
}

class LoadMoreEntry : Gtk.ListBoxRow, Cb.TwitterItem {
  private GLib.TimeSpan last_timediff;
  public bool seen {
    get { return true; }
    set {}
  }
  private Gtk.Button load_more_button;

  public LoadMoreEntry () {
    this.activatable = false;
    this.load_more_button = new Gtk.Button.with_label (_("Load More"));
    load_more_button.get_style_context ().add_class ("dim-label");
    load_more_button.set_halign (Gtk.Align.FILL);
    load_more_button.set_hexpand (true);
    load_more_button.set_relief (Gtk.ReliefStyle.NONE);
    load_more_button.show ();
    this.add (load_more_button);
  }

  public Gtk.Button get_button () {
    return load_more_button;
  }
  public int update_time_delta (GLib.DateTime? now = null) {return 0;}
  public int64 get_sort_factor () {
    return int64.MAX - 2;
  }
  public int64 get_timestamp () {
    return 0;
  }

  public GLib.TimeSpan get_last_set_timediff () {
    return this.last_timediff;
  }

  public void set_last_set_timediff (GLib.TimeSpan span) {
    this.last_timediff = span;
  }
}
