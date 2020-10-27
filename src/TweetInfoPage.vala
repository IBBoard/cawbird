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

[GtkTemplate (ui = "/uk/co/ibboard/cawbird/ui/tweet-info-page.ui")]
class TweetInfoPage : IPage, ScrollWidget, Cb.MessageReceiver {
  public const int KEY_MODE        = 0;
  public const int KEY_TWEET       = 1;
  public const int KEY_EXISTING    = 2;
  public const int KEY_TWEET_ID    = 3;
  public const int KEY_SCREEN_NAME = 4;

  public const int BY_INSTANCE = 1;
  public const int BY_ID       = 2;

  private const GLib.ActionEntry[] action_entries = {
    {"quote",    quote_activated   },
    {"reply",    reply_activated   },
    {"favorite", favorite_activated},
    {"delete",   delete_activated  }
  };

  public int unread_count { get {return 0;} }
  public int id           { get; set; }
  public unowned MainWindow window {
    set {
      main_window = value;
    }
  }
  public unowned Account account;
  private int64 tweet_id;
  private string screen_name;
  private bool values_set = false;
  private Cb.Tweet tweet;
  private GLib.SimpleActionGroup actions;
  private unowned MainWindow main_window;
  private GLib.Cancellable? cancellable = null;

  [GtkChild]
  private Gtk.Grid grid;
  [GtkChild]
  private Gtk.Box main_box;
  [GtkChild]
  private Gtk.Box lower_content;
  [GtkChild]
  private MultiMediaWidget mm_widget;
  [GtkChild]
  private Gtk.Label text_label;
  [GtkChild]
  private TextButton name_button;
  [GtkChild]
  private Gtk.Label screen_name_label;
  [GtkChild]
  private AvatarWidget avatar_image;
  [GtkChild]
  private Gtk.Label rt_label;
  [GtkChild]
  private Gtk.Image rt_image;
  [GtkChild]
  private Gtk.Label rts_label;
  [GtkChild]
  private Gtk.Label favs_label;
  [GtkChild]
  private TweetListBox replied_to_list_box;
  [GtkChild]
  private TweetListBox replies_list_box;
  [GtkChild]
  private TweetListBox self_replies_list_box;
  [GtkChild]
  private TweetListBox mentioned_replies_list_box;
  [GtkChild]
  private Gtk.ToggleButton favorite_button;
  [GtkChild]
  private Gtk.ToggleButton retweet_button;
  [GtkChild]
  private Gtk.MenuButton menu_button;
  [GtkChild]
  private Gtk.Label time_label;
  [GtkChild]
  private Gtk.Label source_label;
  [GtkChild]
  private Gtk.Stack main_stack;
  [GtkChild]
  private Gtk.Label missing_tweet_label;
  [GtkChild]
  private Gtk.Label error_label;
  [GtkChild]
  private Gtk.Label reply_label;
  [GtkChild]
  private Gtk.Box reply_box;

  public TweetInfoPage (int id, Account account) {
    this.id = id;
    this.account = account;
    this.replies_list_box.account = account;
    this.replies_list_box.set_thread_mode (true);
    this.self_replies_list_box.account = account;
    this.self_replies_list_box.set_thread_mode (true);
    this.mentioned_replies_list_box.account = account;
    this.mentioned_replies_list_box.set_thread_mode (true);
    this.replied_to_list_box.account = account;
    this.replied_to_list_box.set_thread_mode (true);
    Utils.connect_vadjustment (this, replies_list_box, scroll_past_top);
    Utils.connect_vadjustment (this, self_replies_list_box, scroll_past_top);
    Utils.connect_vadjustment (this, mentioned_replies_list_box, scroll_past_top);
    Utils.connect_vadjustment (this, replied_to_list_box, scroll_past_top);
    replied_to_list_box.keynav_failed.connect((direction) => {
      if (direction == Gtk.DirectionType.DOWN) {
        name_button.grab_focus();
      }
      return false;
    });
    self_replies_list_box.keynav_failed.connect((direction) => {
      if (direction == Gtk.DirectionType.DOWN) {
        if (mentioned_replies_list_box.is_visible()) {
          mentioned_replies_list_box.get_first_visible_row().grab_focus();
        }
        else if (replies_list_box.is_visible()) {
          replies_list_box.get_first_visible_row().grab_focus();
        }
        return true;
      }
      else if (direction == Gtk.DirectionType.UP) {
        menu_button.grab_focus();
        return true;
      }
      return false;
    });
    mentioned_replies_list_box.keynav_failed.connect((direction) => {
      if (direction == Gtk.DirectionType.UP) {
        if (self_replies_list_box.is_visible()) {
          self_replies_list_box.get_last_visible_row().grab_focus();
        }
        else {
          menu_button.grab_focus();
        }
        return true;
      }
      else if (direction == Gtk.DirectionType.DOWN && replies_list_box.is_visible()) {
        replies_list_box.get_first_visible_row().grab_focus();
        return true;
      }
      return false;
    });
    replies_list_box.keynav_failed.connect((direction) => {
      if (direction == Gtk.DirectionType.UP) {
        if (mentioned_replies_list_box.is_visible()) {
          mentioned_replies_list_box.get_last_visible_row().grab_focus();
        }
        else if (self_replies_list_box.is_visible()) {
          self_replies_list_box.get_last_visible_row().grab_focus();
        }
        else {
          menu_button.grab_focus();
        }
        return true;
      }
      return false;
    });

    grid.set_redraw_on_allocate (true);

    mm_widget.media_clicked.connect ((m, i) => TweetUtils.handle_media_click (tweet.get_medias (), main_window, i));

    replied_to_list_box.row_activated.connect ((row) => {
      var bundle = new Cb.Bundle ();
      bundle.put_int (KEY_MODE, TweetInfoPage.BY_INSTANCE);
      bundle.put_object (KEY_TWEET, ((TweetListEntry)row).tweet);
      bundle.put_bool (KEY_EXISTING, true);
      main_window.main_widget.switch_page (Page.TWEET_INFO, bundle);
    });
    replies_list_box.row_activated.connect ((row) => {
      var bundle = new Cb.Bundle ();
      bundle.put_int (KEY_MODE, TweetInfoPage.BY_INSTANCE);
      bundle.put_object (KEY_TWEET, ((TweetListEntry)row).tweet);
      bundle.put_bool (KEY_EXISTING, true);
      main_window.main_widget.switch_page (Page.TWEET_INFO, bundle);
    });
    self_replies_list_box.row_activated.connect ((row) => {
      var bundle = new Cb.Bundle ();
      bundle.put_int (KEY_MODE, TweetInfoPage.BY_INSTANCE);
      bundle.put_object (KEY_TWEET, ((TweetListEntry)row).tweet);
      bundle.put_bool (KEY_EXISTING, true);
      main_window.main_widget.switch_page (Page.TWEET_INFO, bundle);
    });
    mentioned_replies_list_box.row_activated.connect ((row) => {
      var bundle = new Cb.Bundle ();
      bundle.put_int (KEY_MODE, TweetInfoPage.BY_INSTANCE);
      bundle.put_object (KEY_TWEET, ((TweetListEntry)row).tweet);
      bundle.put_bool (KEY_EXISTING, true);
      main_window.main_widget.switch_page (Page.TWEET_INFO, bundle);
    });

    this.actions = new GLib.SimpleActionGroup ();
    this.actions.add_action_entries (action_entries, this);
    this.insert_action_group ("tweet", this.actions);

    Settings.get ().changed["media-visibility"].connect (media_visiblity_changed_cb);
    this.mm_widget.visible = (Settings.get_media_visiblity () != MediaVisibility.HIDE);
  }

  private void scroll_past_top(Gtk.ScrolledWindow parent, Gtk.ListBox list_box, int over_scroll) {
    parent.vadjustment.value = 0;
  }

  public override void size_allocate(Gtk.Allocation allocation) {
    base.size_allocate(allocation);
    lower_content.set_size_request(-1, allocation.height);
  }

  private void media_visiblity_changed_cb () {
    if (Settings.get_media_visiblity () == MediaVisibility.HIDE)
      this.mm_widget.hide ();
    else
      this.mm_widget.show ();
  }

  [GtkCallback]
  private bool key_released_cb (Gdk.EventKey evt) {
#if DEBUG
    switch(evt.keyval) {
      case Gdk.Key.k:
        TweetUtils.log_tweet(tweet);
        return Gdk.EVENT_STOP;
    }
#endif
    return Gdk.EVENT_PROPAGATE;
  }

  public void on_join (int page_id, Cb.Bundle? args) {
    int mode = args.get_int (KEY_MODE);

    if (mode == 0)
      return;

    values_set = false;

    bool existing = args.get_bool (KEY_EXISTING);

    main_stack.visible_child = main_box;
    missing_tweet_label.hide ();

    /* If we have a tweet instance here already, we set the avatar now instead of in
     * set_tweet_data, since the rearrange_tweets() or list.model.clear() calls
     * might cause the avatar to get removed from the cache. */

    if (existing) {
      // Only possible BY_INSTANCE
      var tweet = (Cb.Tweet) args.get_object (KEY_TWEET);
      if (Twitter.get ().has_avatar (tweet.get_user_id ()))
        avatar_image.surface = Twitter.get ().get_cached_avatar (tweet.get_user_id ());

      rearrange_tweets (tweet.id);
    } else {
      replied_to_list_box.model.clear ();
      replied_to_list_box.hide ();
      replies_list_box.model.clear ();
      replies_list_box.set_unempty ();
      replies_list_box.show ();
      self_replies_list_box.model.clear ();
      self_replies_list_box.hide ();
      mentioned_replies_list_box.model.clear ();
      mentioned_replies_list_box.hide ();
    }

    if (mode == BY_INSTANCE) {
      Cb.Tweet tweet = (Cb.Tweet)args.get_object (KEY_TWEET);

      if (Twitter.get ().has_avatar (tweet.get_user_id ()))
        avatar_image.surface = Twitter.get ().get_cached_avatar (tweet.get_user_id ());

      if (tweet.retweeted_tweet != null)
        this.tweet_id = tweet.retweeted_tweet.id;
      else
        this.tweet_id = tweet.id;

      this.screen_name = tweet.get_screen_name ();
      this.tweet = tweet;
      set_tweet_data (tweet);
    } else if (mode == BY_ID) {
      this.tweet = null;
      this.tweet_id = args.get_int64 (KEY_TWEET_ID);
      this.screen_name = args.get_string (KEY_SCREEN_NAME);
    }

    query_tweet_info ();
  }

  private void load_user_avatar (string url) {
    string avatar_url;
    int scale = this.get_scale_factor ();

    if (scale == 1)
      avatar_url = url.replace ("_normal", "_bigger");
    else
      avatar_url = url.replace ("_normal", "_200x200");

    TweetUtils.download_avatar.begin (avatar_url, 73 * scale, cancellable, (obj, res) => {
      Cairo.Surface surface;
      try {
        var pixbuf = TweetUtils.download_avatar.end (res);
        if (pixbuf == null) {
          surface = scale_surface ((Cairo.ImageSurface)Twitter.no_avatar, 73, 73);
        } else {
          surface = Gdk.cairo_surface_create_from_pixbuf (pixbuf, scale, null);
        }
      } catch (GLib.Error e) {
        warning (e.message);
        surface = Twitter.no_avatar;
      }
      avatar_image.surface = surface;
    });
  }

  private void rearrange_tweets (int64 new_id) {
    replies_list_box.model.clear ();
    replies_list_box.set_unempty ();
    replies_list_box.show ();

    if (replies_list_box.model.contains_id (new_id) || mentioned_replies_list_box.model.contains_id (new_id)) {
      // We're moving down the thread to a reply of the currently displayed tweet,
      // so move the current tweet up into replied_to_list_box
      replied_to_list_box.model.add (this.tweet);
      replied_to_list_box.show ();
      self_replies_list_box.model.clear ();
      self_replies_list_box.hide ();
      mentioned_replies_list_box.model.clear ();
      mentioned_replies_list_box.hide ();
    } else if (self_replies_list_box.model.contains_id (new_id)) {
      // We're moving down the thread to a self-reply of the currently displayed tweet,
      // so move all intervening tweets up into replied_to_list_box
      replied_to_list_box.model.add (this.tweet);
      replied_to_list_box.show ();
      mentioned_replies_list_box.model.clear ();
      mentioned_replies_list_box.hide ();
      var idx = self_replies_list_box.model.index_of (new_id);

      for (int i = 0; i < idx; i++) {
        replied_to_list_box.model.add ((Cb.Tweet)self_replies_list_box.model.get_item (i));
      }

      self_replies_list_box.model.remove_oldest_n_visible (idx + 1);

      if (self_replies_list_box.model.get_n_items () == 0) {
        self_replies_list_box.hide ();
      }
    } else if (replied_to_list_box.model.contains_id (new_id)) {
      // We're moving up the thread to a replied-to tweet so
      // remove all tweets below the selected one from the "replied to" list box
      // (they'll now be replies) and add the direct successor to the replies list
      // or add the chain of self-replies to the self-reply list
      // Other replies will then be loaded by a separate process
      mentioned_replies_list_box.model.clear ();
      mentioned_replies_list_box.hide ();
      self_replies_list_box.hide ();
      var idx = replied_to_list_box.model.index_of (new_id);
      var new_tweet = (Cb.Tweet)replied_to_list_box.model.get_item (idx);
      var new_screen_name_lower = new_tweet.get_screen_name().down();

      var self_replies_count = self_replies_list_box.model.get_n_items ();
      
      if (self_replies_count > 0) {
        Cb.Tweet? remove_from_tweet = null;
        for (int i = 0; i < self_replies_count; i++) {
          var tweet = (Cb.Tweet)self_replies_list_box.model.get_item (i);
          if (tweet.get_screen_name().down() != new_screen_name_lower) {
            remove_from_tweet = tweet;
            break;
          }
        }

        if (remove_from_tweet != null) {
          self_replies_list_box.model.remove_tweets_later_than (remove_from_tweet.id);
        }
      }

      var list_length = replied_to_list_box.model.get_n_items ();
      var prev_id = new_id;
      var mentions = new_tweet.get_mentions ();
      for (int i = 0; i < mentions.length; i++) {
        mentions[i] = mentions[i].down();
      }

      for (int i = idx + 1; i < list_length; i++) {
        var tweet = (Cb.Tweet)replied_to_list_box.model.get_item (i);
        var tweet_screen_name = tweet.get_screen_name().down();
        if (tweet_screen_name == new_screen_name_lower) {
          self_replies_list_box.model.add (tweet);
          self_replies_list_box.show ();
          prev_id = tweet.id;
        } else if (i == idx + 1) {
          if (tweet_screen_name in mentions) {
            mentioned_replies_list_box.model.add (tweet);
            mentioned_replies_list_box.show ();
          } else {
            replies_list_box.model.add (tweet);
            replies_list_box.show ();
          }
          self_replies_list_box.model.clear ();
          break;
        } else {
          var moved_item_count = i - idx;

          if (self_replies_list_box.model.get_n_items () > moved_item_count) {
            // Remove the remaining self-replies, which now aren't a self-reply thread
            self_replies_list_box.model.remove_tweets_later_than (tweet.id);
          }
          break;
        }
      }

      var cur_reply_id = this.tweet.source_tweet.reply_id;
      var screen_name_lower = screen_name.down();
      if (cur_reply_id == new_id) {
        if (screen_name_lower == new_screen_name_lower) {
          self_replies_list_box.model.add (this.tweet);
          self_replies_list_box.show ();
        } 
        else if (screen_name_lower in mentions) {
          mentioned_replies_list_box.model.add (this.tweet);
          mentioned_replies_list_box.show ();
        }
        else {
          replies_list_box.model.add (this.tweet);
          replies_list_box.show ();
        }
      } else if (self_replies_list_box.model.contains_id (cur_reply_id) && screen_name_lower == new_screen_name_lower) {
        self_replies_list_box.model.add (this.tweet);
        self_replies_list_box.show ();
      }

      replied_to_list_box.model.remove_tweets_later_than (new_id);
    
      if (replied_to_list_box.model.get_n_items () == 0)
        replied_to_list_box.hide ();
    }
    else {
      // New tweet - wipe the lot to be sure!
      // (It's most likely to be going back in the history from a previous
      // move *up* the thread, so we might be able to keep the replied_to, 
      // but there's also the possibility that we're moving back from a
      // quoted tweet and its thread and we can't tell until we load everything
      // so just wipe it and be done with it)
      replied_to_list_box.model.clear ();
      replied_to_list_box.hide ();
      mentioned_replies_list_box.model.clear ();
      mentioned_replies_list_box.hide ();
      self_replies_list_box.model.clear ();
      self_replies_list_box.hide ();
    }
  }

  public void on_leave () {
    if (cancellable != null) {
      cancellable.cancel ();
      cancellable = null;
    }
  }


  [GtkCallback]
  private void favorite_button_toggled_cb () {
    toggle_favorite_status ();
  }

  private void toggle_favorite_status () {
    if (!values_set)
      return;

    favorite_button.sensitive = false;

    TweetUtils.set_favorite_status.begin (account, tweet, favorite_button.active, (obj, res) => {
      var success = false;
      try {
        success = TweetUtils.set_favorite_status.end (res);
      } catch (GLib.Error e) {
        Utils.show_error_dialog (e, main_window);
      }
      if (success) {
        if (tweet.is_flag_set (Cb.TweetState.FAVORITED)) {
          this.tweet.favorite_count ++;
        } else {
          this.tweet.favorite_count --;
        }

        this.update_rts_favs_labels ();
      } else {
        favorite_button.active = tweet.is_flag_set (Cb.TweetState.FAVORITED);
      }

      favorite_button.sensitive = true;
    });
  }

  [GtkCallback]
  private void retweet_button_toggled_cb () {
    if (!values_set)
      return;

    retweet_button.sensitive = false;

    TweetUtils.set_retweet_status.begin (account, tweet, retweet_button.active, (obj, res) => {
      var success = false;
      try {
        success = TweetUtils.set_retweet_status.end (res);
      } catch (GLib.Error e) {
        Utils.show_error_dialog (e, main_window);
      }
      if (success) {
        if (tweet.is_flag_set (Cb.TweetState.RETWEETED)) {
          this.tweet.retweet_count ++;
        } else {
          this.tweet.retweet_count --;
        }

        this.update_rts_favs_labels ();
      } else {
        retweet_button.active = tweet.is_flag_set (Cb.TweetState.RETWEETED);
      }

      retweet_button.sensitive = true;
    });
  }

  [GtkCallback]
  private void reply_button_clicked_cb () {
    ComposeTweetWindow ctw = new ComposeTweetWindow(main_window, this.account, this.tweet,
                                                    ComposeTweetWindow.Mode.REPLY);
    ctw.show ();
  }

  [GtkCallback]
  private bool link_activated_cb (string uri) {
    return TweetUtils.activate_link (uri, main_window);
  }

  [GtkCallback]
  private void name_button_clicked_cb () {
    int64 id;
    string screen_name;

    if (this.tweet.retweeted_tweet != null) {
      id = this.tweet.retweeted_tweet.author.id;
      screen_name = this.tweet.retweeted_tweet.author.screen_name;
    } else {
      id = this.tweet.source_tweet.author.id;
      screen_name = this.tweet.source_tweet.author.screen_name;
    }

    var bundle = new Cb.Bundle ();
    bundle.put_int64 (ProfilePage.KEY_USER_ID, id);
    bundle.put_string (ProfilePage.KEY_SCREEN_NAME, screen_name);
    main_window.main_widget.switch_page (Page.PROFILE, bundle);
  }

  private void query_tweet_info () {
    if (this.cancellable != null) {
      this.cancellable.cancel ();
    }

    this.cancellable = new Cancellable ();

    var now = new GLib.DateTime.now_local ();
    var call = account.proxy.new_call ();
    call.set_method ("GET");
    call.set_function ("1.1/statuses/show.json");
    call.add_param ("id", tweet_id.to_string ());
    call.add_param ("include_my_retweet", "true");
    call.add_param ("tweet_mode", "extended");
    call.add_param ("include_ext_alt_text", "true");
    Cb.Utils.load_threaded_async.begin (call, cancellable, (__, res) => {
      Json.Node? root = null;

      try {
        root = Cb.Utils.load_threaded_async.end (res);
      } catch (GLib.Error e) {
        error_label.label = "%s: %s".printf (_("Could not show tweet"), e.message);
        main_stack.visible_child = error_label;
        return;
      }

      if (root == null)
        return;

      Json.Object root_object = root.get_object ();

      if (this.tweet != null) {
        int n_retweets  = (int)root_object.get_int_member ("retweet_count");
        int n_favorites = (int)root_object.get_int_member ("favorite_count");
        this.tweet.retweet_count = n_retweets;
        this.tweet.favorite_count = n_favorites;
      } else {
        this.tweet = new Cb.Tweet ();
        tweet.load_from_json (root, account.id, now);
      }

      string source_client = root_object.get_string_member ("source");
      source_client = "<span underline='none'>" + extract_source (source_client) + "</span>";

      set_tweet_data (tweet, source_client);

      if (tweet.retweeted_tweet == null)
        load_replied_to_tweet (tweet.source_tweet.reply_id);
      else
        load_replied_to_tweet (tweet.retweeted_tweet.reply_id);

      values_set = true;
    });

    // Pull the user's self-replies and user replies separately to ensure user replies don't overrun the thread
    // It doubles our query count, but we get 180 per 15 minutes, which is still 6 threads per minute!
    TweetUtils.search_for_tweets_json.begin (account, "to:" + this.screen_name + " from:" + this.screen_name, -1, tweet_id, 100, cancellable, add_replies);
    TweetUtils.search_for_tweets_json.begin (account, "to:" + this.screen_name + " -from:" + this.screen_name, -1, tweet_id, 100, cancellable, (src, res) => {
      add_replies(src, res);
      if (replies_list_box.model.get_n_items() == 0) {
        replies_list_box.hide();
      }
    });
  }
      
  private void add_replies (GLib.Object? src, GLib.AsyncResult res) {
    var now = new GLib.DateTime.now_local ();
    GLib.List<unowned Json.Node> statuses;

    try {
      statuses = TweetUtils.search_for_tweets_json.end (res);
    } catch (GLib.Error e) {
      if (!(e is GLib.IOError.CANCELLED))
        warning (e.message);

      return;
    }

    // Get the screen name of the author and the mentions of the current tweet.
    // And lowercase them so we can compare them, because Twitter isn't consistent in its casing
    // even in internal fields!
    var screen_name_lower = screen_name.down();
    var mentions = tweet.get_mentions ();
    for (int i = 0; i < mentions.length; i++) {
      mentions[i] = mentions[i].down();
    }

    int64[] thread_ids = {tweet_id};

    // Results come back in decreasing chronological order, but we need to work increasing
    statuses.reverse();
    statuses.foreach ((node) => {
      var obj = node.get_object ();
      if (!obj.has_member ("in_reply_to_status_id") || obj.get_null_member ("in_reply_to_status_id"))
        return;
      
      int64 reply_id = obj.get_int_member ("in_reply_to_status_id");

      if (!(reply_id in thread_ids)) {
        // Not relevant to the thread? Skip it
        return;
      }

      var user_obj = obj.get_object_member("user");
      var reply_screen_name = user_obj.get_string_member("screen_name").down();

      if (reply_id != tweet_id && reply_screen_name != screen_name_lower) {
        // Potentially relevant to the thread, but not from the author and not in reply to the current tweet? Skip it, it's something else
        return;
      }

      var t = new Cb.Tweet ();
      t.load_from_json (node, account.id, now);

      if (reply_screen_name == screen_name_lower) {
        // Must be relevant by now, so matching screen name means it's more of the author's thread
        thread_ids += t.id;
        self_replies_list_box.model.add (t);
      }
      else if (reply_screen_name in mentions) {
        mentioned_replies_list_box.model.add (t);
      }
      else {
        replies_list_box.model.add (t);
      }
    });

    if (replies_list_box.model.get_n_items () > 0) {
      replies_list_box.show ();
    }

    if (mentioned_replies_list_box.model.get_n_items () > 0) {
      mentioned_replies_list_box.show ();
    }

    if (self_replies_list_box.model.get_n_items () > 0) {
      self_replies_list_box.show ();
    }
  }

  /**
   * Loads the tweet this tweet is a reply to.
   * This will recursively call itself until the end of the chain is reached.
   *
   * @param reply_id The id of the tweet the previous tweet was a reply to.
   */
  private void load_replied_to_tweet (int64 reply_id) {
    if (reply_id == 0) {
      // Top of the thread, so stop
      return;
    }

    var replied_to_idx = replied_to_list_box.model.index_of (reply_id);

    if (replied_to_idx == -1) {
      replied_to_idx = replied_to_list_box.model.index_of_retweet (reply_id);
    }

    if (replied_to_idx != -1) {
      // We already have this tweet, so don't fetch it from the web
      // BUT we might not have the rest of the thread (because they pressed "Back" after we removed some of the thread)
      // so recurse anyway
      var replied_to_tweet = (Cb.Tweet)replied_to_list_box.model.get_item (replied_to_idx);
      if (replied_to_tweet.retweeted_tweet == null) {
        load_replied_to_tweet (replied_to_tweet.source_tweet.reply_id);
      }
      else {
        load_replied_to_tweet (replied_to_tweet.retweeted_tweet.reply_id);
      }
      return;
    }

    this.balance_next_upper_change(TOP);
    replied_to_list_box.show ();
    var call = account.proxy.new_call ();
    call.set_function ("1.1/statuses/show.json");
    call.set_method ("GET");
    call.add_param ("id", reply_id.to_string ());
    call.add_param ("tweet_mode", "extended");
    call.add_param ("include_ext_alt_text", "true");
    call.invoke_async.begin (cancellable, (obj, res) => {
      try {
        call.invoke_async.end (res);
      } catch (GLib.Error e) {
        var err = TweetUtils.failed_request_to_error (call, e);
        if (err.domain == TweetUtils.get_error_domain()) {
          if (err.code == 179) {
            missing_tweet_label.label = _("This tweet is hidden by the author");
          }
          else {
            // err.code == 144
            missing_tweet_label.label = _("This tweet is unavailable");
          }
          missing_tweet_label.show();
        } else {
          Utils.show_error_dialog (err, this.main_window);
        }
        replied_to_list_box.visible = (replied_to_list_box.get_children ().length () > 0);
        return;
      }

      var parser = new Json.Parser ();
      try {
        parser.load_from_data (call.get_payload ());
      } catch (GLib.Error e) {
        critical (e.message);
        return;
      }

      /* If we get here, the tweet is not protected so we can just use it */
      var tweet = new Cb.Tweet ();
      tweet.load_from_json (parser.get_root (), account.id, new GLib.DateTime.now_local ());
      replied_to_list_box.model.add (tweet);
      this.balance_next_upper_change(TOP);
      if (tweet.retweeted_tweet == null)
        load_replied_to_tweet (tweet.source_tweet.reply_id);
      else
        load_replied_to_tweet (tweet.retweeted_tweet.reply_id);
    });
  }

  /**
   *
   */
  private void set_tweet_data (Cb.Tweet tweet, string? with = null) {
    bool tweet_is_protected = tweet.is_flag_set (Cb.TweetState.PROTECTED);
    bool tweet_is_verified = tweet.is_flag_set (Cb.TweetState.VERIFIED);
    account.user_counter.user_seen_full (tweet.get_user_id (), tweet.get_screen_name (), tweet.get_user_name (), tweet_is_verified, tweet_is_protected);
    GLib.DateTime created_at = new GLib.DateTime.from_unix_local (
             tweet.retweeted_tweet != null ? tweet.retweeted_tweet.created_at :
                                             tweet.source_tweet.created_at);
    string time_format = created_at.format ("%x, %X");
    if (with != null) {
      time_format += " via " + with;
    }

    text_label.label = tweet.get_formatted_text ();
    name_button.set_text (tweet.get_user_name ());
    name_button.tooltip_text = tweet.get_user_name ();
    var screen_name = "@" + tweet.get_screen_name ();
    screen_name_label.label = screen_name;
    screen_name_label.tooltip_text = screen_name;

    load_user_avatar (tweet.avatar_url);

    if (tweet.retweeted_tweet != null) {
      rt_label.show ();
      rt_image.show ();
      var buff = new StringBuilder ();
      buff.append ("<span underline='none'><a href=\"@")
          .append (tweet.source_tweet.author.id.to_string ())
          .append ("/@")
          .append (tweet.source_tweet.author.screen_name)
          .append ("\" title=\"@")
          .append (tweet.source_tweet.author.screen_name)
          .append ("\">")
          .append (GLib.Markup.escape_text(tweet.source_tweet.author.user_name))
          .append ("</a></span> @")
          .append (tweet.source_tweet.author.screen_name);
      rt_label.label = buff.str;
    }
    else {
      rt_label.hide ();
      rt_image.hide ();
    }

    update_rts_favs_labels ();
    time_label.label = time_format;
    retweet_button.active  = tweet.is_flag_set (Cb.TweetState.RETWEETED);
    favorite_button.active = tweet.is_flag_set (Cb.TweetState.FAVORITED);
    avatar_image.verified  = tweet_is_verified;
    avatar_image.protected_account = tweet_is_protected;

    // Linking to a RT in New Twitter gives you a "RT …" page with no apparent way to get
    // to the original tweet, therefore we need to link to the RTed tweet to be useful.
    // Also, this used to mix the RT ID with the RTed username, which was wrong.
    if (tweet.retweeted_tweet != null) {
      set_source_link (tweet.retweeted_tweet.id, tweet.retweeted_tweet.author.screen_name);
    } else {
      set_source_link (tweet.source_tweet.id, tweet.source_tweet.author.screen_name);
    }

    if ((tweet.retweeted_tweet != null &&
         tweet.retweeted_tweet.reply_id != 0) ||
        (tweet.source_tweet.reply_id != 0 && (tweet.quoted_tweet == null || tweet.source_tweet.reply_id != tweet.quoted_tweet.id))) {
      var author_id = (tweet.retweeted_tweet != null &&
         tweet.retweeted_tweet.reply_id != 0) ? tweet.retweeted_tweet.author.id : tweet.source_tweet.author.id;
      var reply_users = tweet.get_reply_users ();
      for (int i = 0; i < reply_users.length; i ++) {
        if (reply_users[i].id == author_id) {
          var author = reply_users[i];
          // Move the author to the end to deprioritise them.
          // This lets us indicate self-replies in TweetInfoView while also showing
          // more useful information first for multi-user threads
          reply_users.move(i+1, i, reply_users.length - i - 1);
          reply_users[reply_users.length - 1] = author;
          break;
        }
      }

      if (reply_users.length > 0) {
        reply_box.show ();
        var buff = new StringBuilder ();
        buff.append (_("Replying to"));
        buff.append_c (' ');
        Cb.Utils.linkify_user (ref reply_users[0], buff);

        for (int i = 1; i < reply_users.length - 1; i ++) {
          buff.append (", ");
          Cb.Utils.linkify_user (ref reply_users[i], buff);
        }

        if (reply_users.length > 1) {
          /* Last one */
          buff.append_c (' ')
              .append (_("and"))
              .append_c (' ');
          Cb.Utils.linkify_user (ref reply_users[reply_users.length - 1], buff);
        }

        reply_label.label = buff.str;
      } else {
        reply_box.hide ();
      }
    } else {
      reply_box.hide ();
    }

    if (tweet.has_inline_media ()) {
      this.mm_widget.visible = (Settings.get_media_visiblity () != MediaVisibility.HIDE);
      mm_widget.set_all_media (tweet.get_medias ());
    } else {
      mm_widget.hide ();
    }

    ((GLib.SimpleAction)actions.lookup_action ("delete")).set_enabled (tweet.get_user_id () == account.id);

    if (tweet.is_flag_set (Cb.TweetState.PROTECTED)) {
      retweet_button.hide ();
      ((GLib.SimpleAction)actions.lookup_action ("quote")).set_enabled (false);
    } else {
      retweet_button.show ();
      ((GLib.SimpleAction)actions.lookup_action ("quote")).set_enabled (true);
    }
  }

  private void update_rts_favs_labels () {
    rts_label.label = "<big><b>%'d</b></big> %s".printf (tweet.retweet_count, _("Retweets"));
    favs_label.label = "<big><b>%'d</b></big> %s".printf (tweet.favorite_count, _("Favorites"));
  }

  private void set_source_link (int64 id, string screen_name) {
    var link = "https://twitter.com/%s/status/%s".printf (screen_name,
                                                          id.to_string ());

    source_label.label = "<span underline='none'><a href='%s' title='%s'>%s</a></span>"
                         .printf (link, _("Open in Browser"), _("Source"));
  }


  private void quote_activated () {
    ComposeTweetWindow ctw = new ComposeTweetWindow(main_window, this.account, this.tweet,
                                                    ComposeTweetWindow.Mode.QUOTE);
    ctw.show ();
  }

  private void reply_activated () {
    ComposeTweetWindow ctw = new ComposeTweetWindow(main_window, this.account, this.tweet,
                                                    ComposeTweetWindow.Mode.REPLY);
    ctw.show ();
  }

  private void favorite_activated () {
    if (!favorite_button.sensitive)
      return;

    toggle_favorite_status ();
  }

  private void delete_activated () {
    if (this.tweet == null ||
        this.tweet.get_user_id () != account.id) {
      return;
    }

    TweetUtils.delete_tweet.begin (account, tweet, (obj, res) => {
      var success = false;
      try {
        success = TweetUtils.delete_tweet.end (res);
      } catch (GLib.Error e) {
        Utils.show_error_dialog (e, main_window);
      }
      if (success) {
        this.main_window.main_widget.remove_current_page ();
      }
    });
  }

  public string get_title () {
    return _("Tweet Details");
  }

  /**
   * Twitter's source parameter of tweets includes a 'rel' parameter
   * that doesn't work as pango markup, so we rebuild a hyperlink that will work.
   *
   * Note: This assumes a certain format of source parameter hyperlink:
   *   <a href=\"http://www.tweetdeck.com\" rel=\"nofollow\">TweetDeck</a>
   *
   * @param source_str The source string from twitter
   *
   * @return The rebuilt #source_string that's valid pango markup
   */
  private string extract_source (string source_str) {
    int from, to;
    from = source_str.index_of_char ('"') + 1;
    to = source_str.index_of_char ('"', from);
    if (to == -1 || from == -1)
      return source_str;
    int name_start = source_str.index_of_char('>', to) + 1;
    int name_end = source_str.index_of_char('<', name_start);
    string client_name = source_str.substring(name_start, name_end - name_start);
    return "<a href=\"%s\" title=\"%s\">%s</a>".printf(source_str.substring (from, to - from), client_name, client_name);
  }

  public void create_radio_button (Gtk.RadioButton? group) {}
  public Gtk.RadioButton? get_radio_button () {
    return null;
  }

  public void stream_message_received (Cb.StreamMessageType type,
                                       Json.Node         root) {
    if (type == Cb.StreamMessageType.TWEET) {
      Json.Object root_obj = root.get_object ();
      if (Utils.usable_json_value (root_obj, "in_reply_to_status_id")) {
        int64 reply_id = root_obj.get_int_member ("in_reply_to_status_id");

        if (reply_id == this.tweet_id) {
          var t = new Cb.Tweet ();
          t.load_from_json (root, account.id, new GLib.DateTime.now_local ());

          var screen_name_lower = t.get_screen_name().down();
          var mentions = tweet.get_mentions ();
          for (int i = 0; i < mentions.length; i++) {
            mentions[i] = mentions[i].down();
          }

          if (screen_name_lower == screen_name.down()) {
            self_replies_list_box.model.add (t);
            self_replies_list_box.show ();
          }
          else if (screen_name_lower in mentions) {
            mentioned_replies_list_box.model.add (t);
            mentioned_replies_list_box.show ();
          }
          else {
            replies_list_box.model.add (t);
            replies_list_box.show ();
          }
        }
      }
    } else if (type == Cb.StreamMessageType.DELETE) {
      int64 tweet_id = root.get_object ().get_object_member ("delete")
                                         .get_object_member ("status")
                                         .get_int_member ("id");
      if (tweet_id == this.tweet_id && main_window.cur_page_id == this.id) {
        /* TODO: We should probably remove this page with this bundle form the
                 history, even if it's not the currently visible page */
        debug ("Current tweet with id %s deleted!", tweet_id.to_string ());
        this.main_window.main_widget.remove_current_page ();
      }
    } else if (type == Cb.StreamMessageType.EVENT_FAVORITE) {
      int64 id = root.get_object ().get_int_member ("id");
      if (id == this.tweet_id) {
        this.values_set = false;
        this.favorite_button.active = true;
        this.tweet.favorite_count ++;
        this.update_rts_favs_labels ();
        this.values_set = true;
      }

    } else if (type == Cb.StreamMessageType.EVENT_UNFAVORITE) {
      int64 id = root.get_object ().get_object_member ("target_object").get_int_member ("id");
      int64 source_id = root.get_object ().get_object_member ("source").get_int_member ("id");
      if (source_id == account.id && id == this.tweet_id) {
        this.values_set = false;
        this.favorite_button.active = false;
        this.tweet.favorite_count --;
        this.update_rts_favs_labels ();
        this.values_set = true;
      }
    }
  }
}
