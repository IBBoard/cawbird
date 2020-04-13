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
  private MultiMediaWidget mm_widget;
  // If we don't have the scroller property then the app crashes,
  // but if we do then we get an "unused" compiler warning!
  [GtkChild]
  private ChildSizedScroller scroller;
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
  private Gtk.Label fav_label;
  [GtkChild]
  private TweetListBox replied_to_list_box;
  [GtkChild]
  private TweetListBox replies_list_box;
  [GtkChild]
  private Gtk.ToggleButton favorite_button;
  [GtkChild]
  private Gtk.ToggleButton retweet_button;
  [GtkChild]
  private Gtk.Label time_label;
  [GtkChild]
  private Gtk.Label source_label;
  [GtkChild]
  private MaxSizeContainer max_size_container;
  [GtkChild]
  private Gtk.Stack main_stack;
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
    this.replies_list_box.set_sort_order (true);
    this.replied_to_list_box.account = account;
    this.replied_to_list_box.set_sort_order (true);

    grid.set_redraw_on_allocate (true);

    mm_widget.media_clicked.connect ((m, i) => TweetUtils.handle_media_click (tweet.get_medias (), main_window, i));
    this.scroll_event.connect ((evt) => {
      if (evt.delta_y < 0 && this.vadjustment.value == 0 && tweet.is_reply()) {
        int inc = (int)(vadjustment.step_increment * (-evt.delta_y));
        max_size_container.max_size += inc;
        return true;
      }
      return false;
    });
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

    this.actions = new GLib.SimpleActionGroup ();
    this.actions.add_action_entries (action_entries, this);
    this.insert_action_group ("tweet", this.actions);

    Settings.get ().changed["media-visibility"].connect (media_visiblity_changed_cb);
    this.mm_widget.visible = (Settings.get_media_visiblity () != MediaVisibility.HIDE);
  }

  private void media_visiblity_changed_cb () {
    if (Settings.get_media_visiblity () == MediaVisibility.HIDE)
      this.mm_widget.hide ();
    else
      this.mm_widget.show ();
  }

  public void on_join (int page_id, Cb.Bundle? args) {
    int mode = args.get_int (KEY_MODE);

    if (mode == 0)
      return;

    values_set = false;

    bool existing = args.get_bool (KEY_EXISTING);

    max_size_container.max_size = 0;
    main_stack.visible_child = main_box;

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
      replies_list_box.hide ();
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

    query_tweet_info (existing);
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
    //assert (new_id != this.tweet_id);
    if (replies_list_box.model.contains_id (new_id)) {
      // We're moving down the thread to a reply of the currently displayed tweet,
      // so move the current tweet up into replied_to_list_box
      replied_to_list_box.model.add (this.tweet);
      replied_to_list_box.show ();
      replies_list_box.model.clear ();
      replies_list_box.hide ();
    } else if (replied_to_list_box.model.contains_id (new_id)) {
      // We're moving up the thread to a replied-to tweet so
      // remove all tweets below the selected one from the "replied to" list box
      // (they'll now be replies) and add the direct successor to the replies list
      // Other replies will then be loaded by a separate process
      replies_list_box.model.clear ();
      replies_list_box.show ();
      var t = replied_to_list_box.model.get_for_id (new_id, 1);
      if (t != null) {
        replies_list_box.model.add (t);
      } else {
        replies_list_box.model.add (this.tweet);
      }

      replied_to_list_box.model.remove_tweets_later_than (new_id);
      if (replied_to_list_box.model.get_n_items () == 0)
        replied_to_list_box.hide ();
    }
    //else
      //error ("wtf");
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

        this.update_rt_fav_labels ();
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

        this.update_rt_fav_labels ();
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

  private void query_tweet_info (bool existing) {
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

      string with = root_object.get_string_member ("source");
      with = "<span underline='none'>" + extract_source (with) + "</span>";

      set_tweet_data (tweet, with);

      if (!existing) {
        if (tweet.retweeted_tweet == null)
          load_replied_to_tweet (tweet.source_tweet.reply_id);
        else
          load_replied_to_tweet (tweet.retweeted_tweet.reply_id);
      }

      values_set = true;
    });

    var reply_call = account.proxy.new_call ();
    reply_call.set_method ("GET");
    reply_call.set_function ("1.1/search/tweets.json");
    reply_call.add_param ("q", "to:" + this.screen_name);
    reply_call.add_param ("since_id", tweet_id.to_string ());
    reply_call.add_param ("count", "200");
    reply_call.add_param ("tweet_mode", "extended");
    Cb.Utils.load_threaded_async.begin (reply_call, cancellable, (_, res) => {
      Json.Node? root = null;

      try {
        root = Cb.Utils.load_threaded_async.end (res);
      } catch (GLib.Error e) {
        if (!(e is GLib.IOError.CANCELLED))
          warning (e.message);

        return;
      }

      if (root == null)
        return;

      int64[] thread_ids = {tweet_id};
      var statuses_node = root.get_object ().get_array_member ("statuses");
      int64 previous_tweet_id = -1;
      int n_replies = 0;
      // Results come back in decreasing chronological order, but we need to work increasing
      var statuses = statuses_node.get_elements();
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
        var reply_screen_name = user_obj.get_string_member("screen_name");

        if (reply_id != tweet_id && reply_screen_name != screen_name) {
          // Relevant to the thread, but not from the author and not in reply to the current tweet? Skip it
          return;
        }
        
        if (reply_screen_name == screen_name) {
          // Must be relevant by now, so matching screen name means it's more of the author's thread
          thread_ids += obj.get_int_member("id");
        }

        var t = new Cb.Tweet ();
        t.load_from_json (node, account.id, now);
        replies_list_box.model.add (t);
        n_replies ++;
      });

      if (n_replies > 0) {
        replies_list_box.show ();
      }
    });

  }

  /**
   * Loads the tweet this tweet is a reply to.
   * This will recursively call itself until the end of the chain is reached.
   *
   * @param reply_id The id of the tweet the previous tweet was a reply to.
   */
  private void load_replied_to_tweet (int64 reply_id) {
    if (reply_id == 0) {
      return;
    }

    replied_to_list_box.show ();
    var call = account.proxy.new_call ();
    call.set_function ("1.1/statuses/show.json");
    call.set_method ("GET");
    call.add_param ("id", reply_id.to_string ());
    call.add_param ("tweet_mode", "extended");
    call.invoke_async.begin (cancellable, (obj, res) => {
      try {
        call.invoke_async.end (res);
      } catch (GLib.Error e) {
        Utils.show_error_dialog (TweetUtils.failed_request_to_error (call, e), this.main_window);
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
    update_rt_fav_labels ();
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
      var all_reply_users = tweet.get_reply_users ();
      var reply_users = new Cb.UserIdentity[0];
      for (int i = 0; i < all_reply_users.length; i ++) {
        if (all_reply_users[i].id == author_id)
          continue;
        reply_users += all_reply_users[i];
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

  private void update_rt_fav_labels () {
    rt_label.label = "<big><b>%'d</b></big> %s".printf (tweet.retweet_count, _("Retweets"));
    fav_label.label = "<big><b>%'d</b></big> %s".printf (tweet.favorite_count, _("Favorites"));
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
          replies_list_box.model.add (t);
          replies_list_box.show ();
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
        this.update_rt_fav_labels ();
        this.values_set = true;
      }

    } else if (type == Cb.StreamMessageType.EVENT_UNFAVORITE) {
      int64 id = root.get_object ().get_object_member ("target_object").get_int_member ("id");
      int64 source_id = root.get_object ().get_object_member ("source").get_int_member ("id");
      if (source_id == account.id && id == this.tweet_id) {
        this.values_set = false;
        this.favorite_button.active = false;
        this.tweet.favorite_count --;
        this.update_rt_fav_labels ();
        this.values_set = true;
      }
    }
  }
}
