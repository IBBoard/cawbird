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

[GtkTemplate (ui = "/uk/co/ibboard/cawbird/ui/profile-page.ui")]
class ProfilePage : ScrollWidget, IPage, Cb.MessageReceiver {
  private const GLib.ActionEntry[] action_entries = {
    {"write-dm", write_dm_activated},
    {"tweet-to", tweet_to_activated},
    {"add-remove-list", add_remove_list_activated},
  };
  public const int KEY_SCREEN_NAME = 0;
  public const int KEY_USER_ID     = 1;


  public int unread_count {
    get { return 0; }
  }

  private unowned MainWindow main_window;
  public unowned MainWindow window {
    set {
      main_window = value;
      user_lists.main_window = value;
      tweet_list.main_window = main_window;
      followers_list.main_window = main_window;
      followers_list.main_window = main_window;
    }
  }
  public unowned Account account;
  public int id { get; set; }

  [GtkChild]
  private unowned AspectImage banner_image;
  [GtkChild]
  private unowned AvatarWidget avatar_image;
  [GtkChild]
  private unowned Gtk.Label name_label;
  [GtkChild]
  private unowned Gtk.Label screen_name_label;
  [GtkChild]
  private unowned Gtk.Label description_label;
  [GtkChild]
  private unowned Gtk.Label url_label;
  [GtkChild]
  private unowned Gtk.Label tweets_label;
  [GtkChild]
  private unowned Gtk.Label following_label;
  [GtkChild]
  private unowned Gtk.Label followers_label;
  [GtkChild]
  private unowned Gtk.Label location_label;
  [GtkChild]
  private unowned FollowButton follow_button;
  [GtkChild]
  private unowned TweetListBox tweet_list;
  [GtkChild]
  private unowned TweetListBox followers_list;
  [GtkChild]
  private unowned TweetListBox following_list;
  [GtkChild]
  private unowned Gtk.Spinner progress_spinner;
  [GtkChild]
  private unowned Gtk.Label follows_you_label;
  [GtkChild]
  private unowned UserListsWidget user_lists;
  [GtkChild]
  private unowned Gtk.Stack user_stack;
  [GtkChild]
  private unowned Gtk.MenuButton more_button;
  [GtkChild]
  private unowned Gtk.Stack loading_stack;
  [GtkChild]
  private unowned Gtk.RadioButton tweets_button;
  [GtkChild]
  private unowned Gtk.RadioButton followers_button;
  [GtkChild]
  private unowned Gtk.RadioButton following_button;
  [GtkChild]
  private unowned Gtk.RadioButton lists_button;
  [GtkChild]
  private unowned Gtk.Label loading_error_label;
  [GtkChild]
  private unowned Gtk.Box user_blocked_page;
  [GtkChild]
  private unowned Gtk.Label user_blocked_label;
  private int64 user_id;
  private new string name;
  private string screen_name;
  private string avatar_url;
  private int follower_count = -1;
  private GLib.Cancellable data_cancellable;
  private bool lists_page_inited = false;
  private bool retweet_item_blocked = false;
  private bool tweets_loading = false;
  private bool followers_loading = false;
  private JsonCursor? followers_cursor = null;
  private bool following_loading = false;
  private JsonCursor? following_cursor = null;
  private GLib.SimpleActionGroup actions;
  private bool override_block = false;
  private bool is_withheld = false;

  public ProfilePage (int id, Account account) {
    this.id = id;
    this.account = account;
    this.user_lists.account = account;
    this.tweet_list.account = account;

    this.scrolled_to_end.connect (() => {
      if (user_stack.visible_child == tweet_list) {
        this.load_older_tweets.begin ();
      } else if (user_stack.visible_child == followers_list) {
        this.load_followers.begin ();
      } else if (user_stack.visible_child == following_list) {
        this.load_following.begin ();
      }
    });

    tweet_list.row_activated.connect ((row) => {
      var bundle = new Cb.Bundle ();
      bundle.put_int (TweetInfoPage.KEY_MODE, TweetInfoPage.BY_INSTANCE);
      bundle.put_object (TweetInfoPage.KEY_TWEET, ((TweetListEntry)row).tweet);
      main_window.main_widget.switch_page (Page.TWEET_INFO, bundle);
    });
    tweet_list.keynav_failed.connect((direction) => {
      if (direction == Gtk.DirectionType.UP) {
        tweets_button.grab_focus();
        return Gdk.EVENT_STOP;
      }
      return Gdk.EVENT_PROPAGATE;
    });
    Utils.connect_vadjustment (this, tweet_list);

    followers_list.row_activated.connect ((row) => {
      var bundle = new Cb.Bundle ();
      bundle.put_int64 (ProfilePage.KEY_USER_ID, ((UserListEntry)row).user_id);
      bundle.put_string (ProfilePage.KEY_SCREEN_NAME, ((UserListEntry)row).screen_name);
      main_window.main_widget.switch_page (Page.PROFILE, bundle);
    });
    followers_list.keynav_failed.connect((direction) => {
      if (direction == Gtk.DirectionType.UP) {
        followers_button.grab_focus();      
        return Gdk.EVENT_STOP;
      }
      return Gdk.EVENT_PROPAGATE;
    });
    Utils.connect_vadjustment (this, followers_list);

    following_list.row_activated.connect ((row) => {
      var bundle = new Cb.Bundle ();
      bundle.put_int64 (ProfilePage.KEY_USER_ID, ((UserListEntry)row).user_id);
      bundle.put_string (ProfilePage.KEY_SCREEN_NAME, ((UserListEntry)row).screen_name);
      main_window.main_widget.switch_page (Page.PROFILE, bundle);
    });
    following_list.keynav_failed.connect((direction) => {
      if (direction == Gtk.DirectionType.UP) {
        following_button.grab_focus();
        return Gdk.EVENT_STOP;
      }
      return Gdk.EVENT_PROPAGATE;
    });
    Utils.connect_vadjustment (this, following_list);

    user_lists.hide_user_list_entry ();
    user_lists.connect_nav(this, lists_button);

    actions = new GLib.SimpleActionGroup ();
    actions.add_action_entries (action_entries, this);

    GLib.SimpleAction block_action = new GLib.SimpleAction.stateful ("toggle-blocked", null,
                                                                     new GLib.Variant.boolean (false));
    block_action.activate.connect (toggle_blocked_activated);
    actions.add_action (block_action);

    GLib.SimpleAction mute_action = new GLib.SimpleAction.stateful ("toggle-muted", null,
                                                                    new GLib.Variant.boolean (false));
    mute_action.activate.connect (toggle_muted_activated);
    actions.add_action (mute_action);

    GLib.SimpleAction rt_action = new GLib.SimpleAction.stateful ("toggle-retweets", null,
                                                                  new GLib.Variant.boolean (false));
    rt_action.activate.connect (retweet_action_activated);
    actions.add_action (rt_action);

    this.insert_action_group ("user", actions);
  }

  public override void size_allocate(Gtk.Allocation allocation) {
    if (allocation.width < Cawbird.RESPONSIVE_LIMIT) {
      follow_button.set_property("margin-end", 6);
      follow_button.compact = true;
    }
    else {
      follow_button.set_property("margin-end", 16);
      follow_button.compact = false;
    }
    base.size_allocate(allocation);
  }

  private void set_user_id (int64 user_id) {
    this.user_id = user_id;
    follow_button.sensitive = (user_id != account.id);


    loading_stack.visible_child_name = "progress";
    progress_spinner.start ();

    set_banner (null);
    load_friendship.begin ();
    load_profile_data.begin (user_id);
  }


  private async void load_friendship () {
    /* Set muted and blocked status now, let the friendship update it */
    set_user_muted (account.is_muted (user_id));
    set_user_blocked (account.is_blocked (user_id));
    /* We (maybe) re-enable this later when the friendship object has arrived */
    ((SimpleAction)actions.lookup_action ("toggle-retweets")).set_enabled (false);
    ((SimpleAction)actions.lookup_action ("add-remove-list")).set_enabled (user_id != account.id);
    ((SimpleAction)actions.lookup_action ("write-dm")).set_enabled (user_id != account.id);
    ((SimpleAction)actions.lookup_action ("toggle-blocked")).set_enabled (user_id != account.id);
    ((SimpleAction)actions.lookup_action ("toggle-muted")).set_enabled (user_id != account.id);

    uint fr = yield UserUtils.load_friendship (account, this.user_id, this.screen_name);

    follows_you_label.visible = (fr & FRIENDSHIP_FOLLOWED_BY) > 0;
    set_user_muted ((fr & FRIENDSHIP_MUTING) > 0);
    set_user_blocked ((fr & FRIENDSHIP_BLOCKING) > 0);
    set_retweets_disabled ((fr & FRIENDSHIP_FOLLOWING) > 0 &&
                           (fr & FRIENDSHIP_WANT_RETWEETS) == 0);

    if ((fr & FRIENDSHIP_CAN_DM) == 0)
      ((SimpleAction)actions.lookup_action ("write-dm")).set_enabled (false);

    ((SimpleAction)actions.lookup_action ("toggle-retweets")).set_enabled ((fr & FRIENDSHIP_FOLLOWING) > 0);
  }

  private async void load_profile_data (int64 user_id) {
    follow_button.sensitive = false;
    var call = account.proxy.new_call ();
    call.set_method ("GET");
    call.set_function ("1.1/users/show.json");
    if (user_id != 0)
      call.add_param ("user_id", user_id.to_string ());
    else
      call.add_param ("screen_name", this.screen_name);
    call.add_param ("include_entities", "false");

    Json.Node? root_node = null;
    try {
      root_node = yield Cb.Utils.load_threaded_async (call, data_cancellable);
    } catch (GLib.Error e) {
      if (e.message == "Forbidden") {
        loading_error_label.label = _("Suspended Account");
        loading_stack.visible_child = loading_error_label;
      } else if (e.domain == Rest.ProxyError.quark() && e.code == new Rest.ProxyError.SSL ("workaround").code) {
        debug ("Reloading user profile on SSL failure");
        load_profile_data.begin (user_id);
      } else {
        warning (e.message);
      }
      return;
    }

    if (root_node == null) return;

    var root = root_node.get_object();
    int64 id = root.get_int_member ("id");
    this.user_id = id;
    is_withheld = root.get_array_member("withheld_in_countries").get_length() > 0;

    string avatar_url = root.get_string_member("profile_image_url_https");
    int scale = this.get_scale_factor ();

    /* Always load the 200x200 px version even in loDPI since there's no 100x100px version */
    avatar_url = avatar_url.replace ("_normal", "_200x200");

    if (is_withheld) {
      avatar_image.surface = scale_surface ((Cairo.ImageSurface)Twitter.withheld_avatar, 100, 100);
      progress_spinner.stop ();
      loading_stack.visible_child_name = "data";
    }
    else {
      // We don't use our AvatarCache here because this (100×100) avatar is only
      // ever loaded here.
      TweetUtils.download_avatar.begin (avatar_url, 100 * scale, data_cancellable, (obj, res) => {
        Cairo.Surface surface;
        try {
          var pixbuf = TweetUtils.download_avatar.end (res);
          if (pixbuf == null) {
            var avatar_surface = avatar_url.length > 0 ? Twitter.no_avatar : Twitter.null_avatar;
            surface = scale_surface ((Cairo.ImageSurface)avatar_surface,
                                    100, 100);
          } else {
            surface = Gdk.cairo_surface_create_from_pixbuf (pixbuf, scale, null);
          }
        } catch (GLib.Error e) {
          warning (e.message);
          surface = avatar_url.length > 0 ? Twitter.no_avatar : Twitter.null_avatar;
        }
        avatar_image.surface = surface;
        progress_spinner.stop ();
        loading_stack.visible_child_name = "data";
      });
    }

    string name        = root.get_string_member("name").strip ();
    string screen_name = root.get_string_member("screen_name");
    string description = root.get_string_member("description");
    int followers      = (int)root.get_int_member("followers_count");
    int following      = (int)root.get_int_member("friends_count");
    int tweets         = (int)root.get_int_member("statuses_count");
    bool is_following  = false;
    if (Utils.usable_json_value (root, "following"))
      is_following = root.get_boolean_member("following");
    bool has_url       = root.get_object_member("entities").has_member("url");
    bool verified      = root.get_boolean_member ("verified");
    bool protected_user = root.get_boolean_member ("protected");
    if (is_withheld) {
      tweet_list.set_placeholder_text(_("Withheld account"));
    }
    else if (protected_user) {
      tweet_list.set_placeholder_text (_("Protected profile"));
    }

    string color = root.get_string_member ("profile_background_color");
    banner_image.color_string = "#" + color;

    if (root.has_member ("profile_banner_url")) {
      string banner_base_url = root.get_string_member ("profile_banner_url");
      load_profile_banner (banner_base_url);
    }

    string display_url = "";
    Json.Object entities = root.get_object_member ("entities");
    if (has_url) {
      var urls_object = entities.get_object_member("url").get_array_member("urls").
        get_element(0).get_object();

      var url = urls_object.get_string_member("expanded_url");
      if (urls_object.has_member ("display_url")) {
        display_url = urls_object.get_string_member("expanded_url");
      } else {
        url = urls_object.get_string_member("url");
        display_url = url;
      }
    }

    string location = null;
    if (root.has_member("location")) {
      location = root.get_string_member("location");
    }

    Cb.TextEntity[]? text_urls = null;
    if (root.has_member ("description")) {
      int n_tl_entities = 0;
      Tl.Entity[]? tl_entities = Tl.extract_entities (description, null);

      // We just add hashtags and mentions ourselves and leave links to Twitter
      foreach (Tl.Entity e in tl_entities) {
        if (e.type == Tl.EntityType.HASHTAG ||
            e.type == Tl.EntityType.MENTION)
          n_tl_entities ++;

      }

      Json.Array urls = entities.get_object_member ("description").get_array_member ("urls");
      text_urls = new Cb.TextEntity[urls.get_length () + n_tl_entities];
      urls.foreach_element ((arr, i, node) => {
        var ent = node.get_object ();
        string expanded_url = ent.get_string_member ("expanded_url");
        Json.Array indices = ent.get_array_member ("indices");
        text_urls[i] = Cb.TextEntity(){
          from = (uint)indices.get_int_element (0),
          to   = (uint)indices.get_int_element (1),
          target = expanded_url,
          original_text = ent.get_string_member ("url"),
          display_text = ent.get_string_member ("display_url"),
          tooltip_text = expanded_url
        };
      });

      // Adding them now is fine since we will sort them later
      int i = (int)urls.get_length ();
      foreach (Tl.Entity e in tl_entities) {
        if (e.type != Tl.EntityType.HASHTAG &&
            e.type != Tl.EntityType.MENTION)
          continue;

        if (e.type == Tl.EntityType.HASHTAG) {
          text_urls[i] = Cb.TextEntity () {
            from = (uint)e.start_character_index,
            to   = (uint)(e.start_character_index + e.length_in_characters),
            target = e.start->substring(0, (long)e.length_in_bytes),
            original_text = e.start->substring(0, (long)e.length_in_bytes),
            display_text = e.start->substring(0, (long)e.length_in_bytes),
            tooltip_text = e.start->substring(0, (long)e.length_in_bytes)
          };
        } else if (e.type == Tl.EntityType.MENTION) {
          text_urls[i] = Cb.TextEntity () {
            from = (uint)e.start_character_index,
            to   = (uint)(e.start_character_index + e.length_in_characters),
            target = "@0/%.*s".printf (e.length_in_bytes, e.start),
            original_text = e.start->substring(0, (long)e.length_in_bytes),
            display_text = e.start->substring(0, (long)e.length_in_bytes),
            tooltip_text = e.start->substring(0, (long)e.length_in_bytes)
          };
        }

        i ++;
      }
    }

    account.user_counter.user_seen_full (id, screen_name, name, verified, protected_user);

    this.follow_button.following = is_following;
    this.follow_button.sensitive = (this.user_id != this.account.id);


    var section = (GLib.Menu)more_button.menu_model.get_item_link (0, GLib.Menu.LINK_SECTION);
    var user_item = new GLib.MenuItem (_("Tweet to @%s").printf (screen_name.replace ("_", "__")),
                                       "user.tweet-to");
    section.remove (1);
    section.insert_item (1, user_item);
    var _name = name.strip ();
    name_label.set_text (name);
    name_label.tooltip_text = _name;
    var _screen_name = "@" + screen_name;
    screen_name_label.set_label (_screen_name);
    screen_name_label.tooltip_text = _screen_name;
    TweetUtils.sort_entities (ref text_urls);
    string desc = Cb.TextTransform.text (description,
                                         text_urls,
                                         0,
                                         0,
                                         0);

    this.follower_count = followers;
    description_label.label = "<big>%s</big>".printf (desc);
    tweets_label.label = "%'d".printf(tweets);
    tweets_button.get_accessible().set_name(ngettext("%d tweet", "%d tweets", tweets).printf(tweets));
    following_label.label = "%'d".printf(following);
    following_button.get_accessible().set_name(ngettext("Following %d account", "Following %d accounts", following).printf(following));
    update_follower_label ();

    if (location != null && location != "") {
      location_label.visible = true;
      location_label.label = location;
      location_label.get_accessible().set_name(_("Location: %s".printf(location)));
    } else
      location_label.visible = false;

    avatar_image.verified = verified;
    avatar_image.protected_account = protected_user;

    if (display_url.length > 0) {
      display_url = GLib.Markup.escape_text (display_url);
      url_label.visible = true;
      url_label.set_markup ("<span underline='none'><a href='%s'>%s</a></span>"
                            .printf (display_url, display_url));
      description_label.margin_bottom = 6;
    } else {
      url_label.visible = false;
      description_label.margin_bottom = 12;
    }

    this.name = name;
    this.screen_name = screen_name;
    this.avatar_url = avatar_url;
    // TRANSLATORS: Value is user's name - used for accessibility text for profile timeline view
    tweet_list.get_accessible().set_name(_("%s timeline").printf(name));
    // TRANSLATORS: Value is user's name - used for accessibility text for list of users following the user
    followers_list.get_accessible().set_name(_("%s followers").printf(name));
    // TRANSLATORS: Value is user's name - used for accessibility text for list of users followed by the user
    following_list.get_accessible().set_name(_("%s following").printf(name));
  }


  private async void load_tweets () {
    if (account.blocked_or_muted (user_id) && !override_block) {
      return;
    }
    if (is_withheld) {
      return;
    }
    if ((!account.blocked_or_muted(user_id) || override_block) && user_stack.visible_child == user_blocked_page) {
      user_stack.visible_child = tweet_list;
    }
    tweet_list.set_unempty ();
    tweets_loading = true;

    Json.Array root_array;
    
    try {
      if (user_id != 0) {
        root_array = yield UserUtils.load_user_timeline_by_id(account, user_id, 10);
      }
      else {
        root_array = yield UserUtils.load_user_timeline_by_screen_name(account, screen_name, 10);
      }
    } catch (GLib.Error e) {
      if (e.message != "Authorization Required") {
        warning (e.message);
      }
      tweet_list.set_empty ();
      return;
    }

    if (root_array.get_length () == 0) {
      tweet_list.set_empty ();
      return;
    }
    TweetUtils.work_array (root_array,
                           tweet_list,
                           account);
    tweet_list.set_empty ();
    tweets_loading = false;
  }

  private async void load_older_tweets (int count_multiplier = 1) {
    if (tweets_loading)
      return;

    if (user_stack.visible_child != tweet_list)
      return;

    if (is_withheld)
      return;

    tweets_loading = true;
    int requested_tweet_count = 15 * count_multiplier;
    
    Json.Array root_array;

    try {
      if (user_id != 0) {
        root_array = yield UserUtils.load_user_timeline_by_id(account, user_id, requested_tweet_count, -1, tweet_list.model.min_id);
      }
      else {
        root_array = yield UserUtils.load_user_timeline_by_screen_name(account, screen_name, requested_tweet_count, -1, tweet_list.model.min_id);
      }
    } catch (GLib.Error e) {
      warning (e.message);
      return;
    }

    TweetUtils.work_array (root_array,
                           tweet_list,
                           account);
    tweets_loading = false;
  }

  private async void load_followers () {
    if (this.followers_cursor != null && this.followers_cursor.full)
      return;

    if (this.followers_loading)
      return;

    this.followers_loading = true;

    this.followers_cursor = yield UserUtils.load_followers (this.account,
                                                            this.user_id,
                                                            this.followers_cursor);

    if (this.followers_cursor == null) {
      this.followers_list.set_placeholder_text (_("Protected Profile"));
      this.followers_list.set_empty ();
      return;
    }

    var users_array = this.followers_cursor.json_object.get_array ();

    users_array.foreach_element ((array, index, node) => {
      var user_obj = node.get_object ();
      string avatar_url = user_obj.get_string_member ("profile_image_url_https");

      if (this.get_scale_factor () >= 2)
        avatar_url = avatar_url.replace ("_normal", "_bigger");


      var entry = new UserListEntry ();
      entry.show_settings = false;
      entry.user_id = user_obj.get_int_member ("id");
      entry.set_screen_name ("@" + user_obj.get_string_member ("screen_name"));
      entry.name = user_obj.get_string_member ("name");
      entry.avatar_url = avatar_url;
      entry.get_style_context ().add_class ("tweet");
      entry.show ();
      this.followers_list.add (entry);
    });

    this.followers_loading = false;
  }

  private async void load_following () {
    if (this.following_cursor != null && this.following_cursor.full)
      return;

    if (this.following_loading)
      return;

    this.following_loading = true;

    this.following_cursor = yield UserUtils.load_following (this.account,
                                                            this.user_id,
                                                            this.following_cursor);

    if (this.following_cursor == null) {
      message ("null cursor");
      this.following_list.set_placeholder_text (_("Protected Profile"));
      this.following_list.set_empty ();
      return;
    }

    var users_array = this.following_cursor.json_object.get_array ();

    users_array.foreach_element ((array, index, node) => {
      var user_obj = node.get_object ();
      string avatar_url = user_obj.get_string_member ("profile_image_url_https");

      if (this.get_scale_factor () >= 2)
        avatar_url = avatar_url.replace ("_normal", "_bigger");

      var entry = new UserListEntry ();
      entry.show_settings = false;
      entry.user_id = user_obj.get_int_member ("id");
      entry.set_screen_name ("@" + user_obj.get_string_member ("screen_name"));
      entry.name = user_obj.get_string_member ("name");
      entry.avatar_url = avatar_url;
      entry.get_style_context ().add_class ("tweet");
      entry.show ();
      this.following_list.add (entry);

    });

    this.following_loading = false;
  }

  private void load_profile_banner (string base_url) {
    string banner_url  = base_url + "/mobile_retina";
    Utils.download_pixbuf.begin (banner_url, null, (obj, res) => {
      Gdk.Pixbuf? banner = Utils.download_pixbuf.end (res);
      set_banner (banner);
    });
  }

  [GtkCallback]
  private void follow_button_clicked_cb () {
    follow_button.sensitive = false;
    var call = account.proxy.new_call();
    call.set_method ("POST");
    if (follow_button.following) {
      call.set_function( "1.1/friendships/destroy.json");
    } else {
      call.set_function ("1.1/friendships/create.json");
      call.add_param ("follow", "false");
    }
    call.add_param ("id", user_id.to_string ());
    call.invoke_async.begin (null, (obj, res) => {
      try {
        this.follow_button.sensitive = (this.user_id != this.account.id);
        call.invoke_async.end (res);
      } catch (GLib.Error e) {
        var err = TweetUtils.failed_request_to_error(call, e);
        if (err.domain != TweetUtils.get_error_domain() || err.code != 160) {
          debug("Code: %d", err.code);
          Utils.show_error_dialog (err, main_window);
          follow_button.sensitive = true;
          return;
        }
      }

      if (follow_button.following) {
        TweetUtils.inject_user_unfollow (this.user_id, account);
        follower_count --;
        account.unfollow_id (this.user_id);
        ((SimpleAction)actions.lookup_action ("toggle-retweets")).set_enabled (false);
        set_retweets_disabled (false);
      } else {
        TweetUtils.inject_user_follow (this.user_id, account);
        set_user_blocked (false);
        follower_count ++;
        account.follow_id (this.user_id);
        ((SimpleAction)actions.lookup_action ("toggle-retweets")).set_enabled (true);
      }
      
      this.follow_button.following = !this.follow_button.following;
      update_follower_label ();
      follow_button.sensitive = true;
    });
  }

  [GtkCallback]
  private bool activate_link (string uri) {
    return TweetUtils.activate_link (uri, main_window);
  }


  private inline void set_banner (Gdk.Pixbuf? banner) {
    if (banner == null)
      banner_image.pixbuf = Twitter.no_banner;
    else
      banner_image.pixbuf = banner;
  }

  /**
   * see IPage#onJoin
   */
  public void on_join (int page_id, Cb.Bundle? args) {
    int64 user_id = args.get_int64 (KEY_USER_ID);
    if (user_id == -1)
      return;

    string? screen_name = args.get_string (KEY_SCREEN_NAME);
    if (screen_name != null) {
      this.screen_name = screen_name;
    }


    data_cancellable = new GLib.Cancellable ();
    tweet_list.reset_placeholder_text ();
    followers_list.reset_placeholder_text ();
    following_list.reset_placeholder_text ();

    if (user_id != this.user_id) {
      reset_data ();
      followers_cursor = null;
      followers_list.remove_all ();
      following_cursor = null;
      following_list.remove_all ();
      set_user_id (user_id);
      if (account.follows_id (user_id)) {
        this.follow_button.following = true;
        this.follow_button.sensitive = true;
      }
      tweet_list.model.clear ();
      user_lists.clear_lists ();
      lists_page_inited = false;
      load_tweets.begin (() => {
        // Try to load more in case we loaded tweets with RTs disabled
        //and didn't fetch enough in one go
        fill_tweet_list.begin();
      });
      override_block = false;
      show_tweet_list();
    } else {
      /* Still load the friendship since muted/blocked/etc. may have changed */
      load_friendship.begin ();
    }
    tweets_button.active = true;
  }

  public void on_leave () {
    // We might otherwise overwrite the new user's data with that from the old one.
    data_cancellable.cancel ();
    more_button.get_popover ().hide ();
  }

  private void reset_data () {
    is_withheld = false;
    name_label.label = " ";
    screen_name_label.label = " ";
    description_label.label = " ";
    url_label.label = " ";
    location_label.label = " ";
    tweets_label.label = " ";
    following_label.label = " ";
    followers_label.label = " ";
    avatar_image.surface = null;
  }

  public void create_radio_button (Gtk.RadioButton? group) {}


  public string get_title () {
    return "@" + screen_name;
  }

  public Gtk.RadioButton? get_radio_button(){
    return null;
  }

  private void write_dm_activated (GLib.SimpleAction a, GLib.Variant? v) {
    var bundle = new Cb.Bundle ();
    bundle.put_int64 (DMPage.KEY_SENDER_ID, user_id);
    bundle.put_string (DMPage.KEY_SCREEN_NAME, screen_name);
    bundle.put_string (DMPage.KEY_USER_NAME, name);
    bundle.put_string (DMPage.KEY_AVATAR_URL, avatar_url.replace ("_bigger", "_normal"));
    main_window.main_widget.switch_page (Page.DM, bundle);
  }

  private void tweet_to_activated (GLib.SimpleAction a, GLib.Variant? v) {
    var cw = new ComposeTweetWindow (main_window, account, null);
    cw.set_text ("@" + screen_name + " ");
    cw.show_all ();
  }

  private void add_remove_list_activated (GLib.SimpleAction a, GLib.Variant? v) {
    var uld = new UserListDialog (main_window, account, user_id);
    uld.load_lists ();
    uld.show_all ();
  }


  private void toggle_blocked_activated (GLib.SimpleAction a, GLib.Variant? v) {
    bool current_state = get_user_blocked ();
    a.set_enabled (false);
    UserUtils.block_user.begin (account, this.user_id, !current_state, (obj, res) => {
      try {
        UserUtils.block_user.end (res);
        a.set_state(!current_state);
        if (!current_state) {
          this.follow_button.following = false;
          this.follow_button.sensitive = (this.user_id != this.account.id);
        }
      } catch (GLib.Error e) {
        Utils.show_error_dialog (e, this.main_window);
      } finally {
        a.set_enabled (true);
      }
    });
  }

  private void toggle_muted_activated (GLib.SimpleAction a, GLib.Variant? v) {
    bool setting = get_user_muted ();
    a.set_enabled (false);
    UserUtils.mute_user.begin (account,this.user_id, !setting, (obj, res) => {
      try {
        UserUtils.mute_user.end (res);
        a.set_state (!setting);
      } catch (GLib.Error e) {
        Utils.show_error_dialog (e, this.main_window);
      } finally {
        a.set_enabled (true);
      }
    });
  }

  private void retweet_action_activated (GLib.SimpleAction a, GLib.Variant? v) {
    if (retweet_item_blocked)
      return;

    retweet_item_blocked = true;
    bool current_state = a.get_state ().get_boolean ();
    a.set_state (new GLib.Variant.boolean (!current_state));
    var call = account.proxy.new_call ();
    call.set_function ("1.1/friendships/update.json");
    call.set_method ("POST");
    call.add_param ("user_id", this.user_id.to_string ());
    call.add_param ("retweets", current_state.to_string ());
    if (current_state) {
      account.remove_disabled_rts_id (this.user_id);
      TweetUtils.inject_user_show_rts(user_id, account);
    } else {
      account.add_disabled_rts_id (this.user_id);
      TweetUtils.inject_user_hide_rts (this.user_id, account);
    }

    call.invoke_async.begin (null, (obj, res) => {
      try {
        call.invoke_async.end (res);
      } catch (GLib.Error e) {
        Utils.show_error_dialog (TweetUtils.failed_request_to_error (call, e), this.main_window);
        /* Reset the state if the retweeting failed */
        a.set_state (new GLib.Variant.boolean (current_state));
      }
      retweet_item_blocked = false;
    });
  }

  private void hide_tweets(Cb.TweetState reason, string message) {
    tweet_list.hide_tweets_from(user_id, reason);
    tweet_list.hide_retweets_from(user_id, reason);
    tweet_list.set_placeholder_text(message);
    tweet_list.set_empty();
    user_blocked_label.label = message;
    user_stack.visible_child = user_blocked_page;
    override_block = false;
  }

  private void show_tweets(Cb.TweetState reason) {
    tweet_list.show_tweets_from(user_id, reason);
    tweet_list.show_retweets_from(user_id, reason);
    if (tweet_list.model.get_n_items() == 0 && (!account.blocked_or_muted(user_id) || override_block)) {
      load_tweets.begin(() => {
        if (override_block) {
          // It's either this or adding a "flag mask" to a util function
          tweet_list.show_tweets_from(user_id, reason);
          tweet_list.show_retweets_from(user_id, reason);
        }
      });
    }
  }

  private void set_user_blocked (bool blocked) {
    ((SimpleAction)actions.lookup_action ("toggle-blocked")).set_state (new GLib.Variant.boolean (blocked));
    var reason = Cb.TweetState.HIDDEN_AUTHOR_BLOCKED;
    if (blocked) {
      hide_tweets(reason, _("User is blocked"));
    }
    else {
      show_tweets(reason);
    }
  }

  private bool get_user_blocked () {
    return ((SimpleAction)actions.lookup_action ("toggle-blocked")).get_state ().get_boolean ();
  }

  private void set_user_muted (bool muted) {
    ((SimpleAction)actions.lookup_action ("toggle-muted")).set_state (new GLib.Variant.boolean (muted));
    var reason = Cb.TweetState.HIDDEN_AUTHOR_MUTED;
    if (muted) {
      hide_tweets(reason, _("User is muted"));
    }
    else {
      show_tweets(reason);
    }
  }

  private bool get_user_muted () {
    return ((SimpleAction)actions.lookup_action ("toggle-muted")).get_state ().get_boolean ();
  }

  private void set_retweets_disabled (bool disabled) {
    ((SimpleAction)actions.lookup_action ("toggle-retweets")).set_state (new GLib.Variant.boolean (disabled));
  }

  private void update_follower_label () {
    followers_label.label = "%'d".printf(follower_count);
    followers_button.get_accessible().set_name(ngettext("%d follower", "%d followers", follower_count).printf(follower_count));
  }

  public void stream_message_received (Cb.StreamMessageType type,
                                       Json.Node         root_node) {
    if (type == Cb.StreamMessageType.TWEET) {
      Utils.set_rt_from_tweet (root_node, this.tweet_list.model, this.account);

      var obj = root_node.get_object ();
      var user = obj.get_object_member ("user");
      if (user.get_int_member ("id") != this.user_id)
        return;

      // Correct user!
      var tweet = new Cb.Tweet ();
      tweet.load_from_json (root_node,
                            account.id,
                            new GLib.DateTime.now_local ());
      this.tweet_list.model.add (tweet);
    }
    else if (type == Cb.StreamMessageType.DELETE) {
      var status = root_node.get_object ().get_object_member ("delete").get_object_member ("status");
      int64 user_id = status.get_int_member ("user_id");
      
      if (user_id != this.user_id) {
        return;
      }

      int64 id = status.get_int_member ("id");
      bool was_seen;
      this.tweet_list.model.delete_id (id, out was_seen);
    } else if (type == Cb.StreamMessageType.RT_DELETE) {
      Utils.unrt_tweet (root_node, this.tweet_list.model);
    } else if (type == Cb.StreamMessageType.EVENT_HIDE_RTS) {
      var event_user_id = get_user_id (root_node);
      if (event_user_id == user_id) {
        tweet_list.hide_retweets_from (event_user_id, Cb.TweetState.HIDDEN_RTS_DISABLED);
        fill_tweet_list.begin();
      }
    } else if (type == Cb.StreamMessageType.EVENT_SHOW_RTS) {
      var event_user_id = get_user_id (root_node);
      if (event_user_id == user_id) {
        tweet_list.show_retweets_from (event_user_id, Cb.TweetState.HIDDEN_RTS_DISABLED);
      }
    } else if (type == Cb.StreamMessageType.EVENT_BLOCK) {
      var event_user_id = get_user_id (root_node);
      if (event_user_id == user_id) {
        set_user_blocked (true);
      }
    } else if (type == Cb.StreamMessageType.EVENT_MUTE) {
      var event_user_id = get_user_id (root_node);
      if (event_user_id == user_id) {
        set_user_muted (true);
      }
    } else if (type == Cb.StreamMessageType.EVENT_UNBLOCK) {
      var event_user_id = get_user_id (root_node);
      if (event_user_id == user_id) {
        set_user_blocked (false);
      }
    } else if (type == Cb.StreamMessageType.EVENT_UNMUTE) {
      var event_user_id = get_user_id (root_node);
      if (event_user_id == user_id) {
        set_user_muted (false);
      }
    }
  }

  private async void fill_tweet_list() {
    // Try to load more tweets if we may not have enough because we disabled RTs from this user
    // But don't try too many times or we'll burn up all of our requests
    var count_multiplier = 1;
    for (int i = 0; i < 5; i++) {
      GLib.Idle.add(() => {
        // Give the scroller time to update its status
        fill_tweet_list.callback();
        return GLib.Source.REMOVE;
      });
      yield;
      if (this.is_scrollable) {
        break;            
      }
      var prev_min_id = tweet_list.model.min_id;
      yield load_older_tweets(count_multiplier);
      if (tweet_list.model.min_id == prev_min_id) {
        count_multiplier++;
      }
    }
  }

  private int64 get_user_id (Json.Node root) {
    return root.get_object ().get_object_member ("target").get_int_member ("id");
  }

  private void show_tweet_list() {
    if (account.blocked_or_muted (user_id) && !override_block) {
      user_stack.visible_child = user_blocked_page;
    }
    else {
      user_stack.visible_child = tweet_list;
    }
  }

  [GtkCallback]
  private void tweets_button_toggled_cb (GLib.Object source) {
    if (((Gtk.RadioButton)source).active) {
      this.balance_next_upper_change (BOTTOM);
      show_tweet_list();
    }
  }
  [GtkCallback]
  private void followers_button_toggled_cb (GLib.Object source) {
    if (((Gtk.RadioButton)source).active) {
      if (this.followers_cursor == null) {
        this.load_followers.begin ();
      }
      this.balance_next_upper_change (BOTTOM);
      user_stack.visible_child = followers_list;
    }
  }

  [GtkCallback]
  private void following_button_toggled_cb (GLib.Object source) {
    if (((Gtk.RadioButton)source).active) {
      if (this.following_cursor == null) {
        this.load_following.begin ();
      }
      this.balance_next_upper_change (BOTTOM);
      user_stack.visible_child = following_list;
    }
  }

  [GtkCallback]
  private void lists_button_toggled_cb (GLib.Object source) {
    if (((Gtk.RadioButton)source).active) {
      if (!lists_page_inited) {
        user_lists.load_lists.begin (user_id, name, screen_name);
        lists_page_inited = true;
      }
      this.balance_next_upper_change (BOTTOM);
      user_stack.visible_child = user_lists;
    }
  }

  [GtkCallback]
  private void show_anyway_clicked(GLib.Object source) {
    override_block = true;
    user_stack.visible_child = tweet_list;
    if (account.is_muted(user_id)) {
      show_tweets(Cb.TweetState.HIDDEN_AUTHOR_MUTED);
    }
    if (account.is_blocked(user_id)) {
      show_tweets(Cb.TweetState.HIDDEN_AUTHOR_BLOCKED);
    }
  }

  public void rerun_filters () {
    TweetUtils.rerun_filters(tweet_list, account);
  }
}
