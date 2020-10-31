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

[GtkTemplate (ui = "/uk/co/ibboard/cawbird/ui/tweet-list-entry.ui")]
public class TweetListEntry : Cb.TwitterItem, Gtk.ListBoxRow {

  private const GLib.ActionEntry[] action_entries = {
    {"quote", quote_activated},
    {"delete", delete_activated}
  };

  [GtkChild]
  private Gtk.Label name_label;
  [GtkChild]
  private Gtk.Label time_delta_label;
  [GtkChild]
  private AvatarWidget avatar_image;
  [GtkChild]
  private ChildSizedScroller scroller;
  [GtkChild]
  private Gtk.Label text_label;
  [GtkChild]
  private Gtk.Label rt_label;
  [GtkChild]
  private Gtk.Image rt_image;
  [GtkChild]
  private Gtk.Image conversation_image;
  [GtkChild]
  private Gtk.Image rt_status_image;
  [GtkChild]
  private Gtk.Image fav_status_image;
  [GtkChild]
  private DoubleTapButton retweet_button;
  [GtkChild]
  private Gtk.ToggleButton favorite_button;
  [GtkChild]
  private Gtk.Grid grid;
  [GtkChild]
  private Gtk.Stack stack;
  [GtkChild]
  private Gtk.Box action_box;
  [GtkChild]
  private Gtk.Label reply_label;

  /* Conditionally created widgets... */
  private Gtk.Label? quote_label = null;
  private Gtk.Label? quote_name = null;
  private Gtk.Label? quote_time_delta = null;
  private Gtk.Label? quote_reply_label = null;
  private Gtk.Grid? quote_grid = null;
  private Gtk.Stack? media_stack = null;
  private MultiMediaWidget? mm_widget = null;
  private Gtk.Stack? quoted_media_stack = null;
  private MultiMediaWidget? quoted_mm_widget = null;


  private bool _read_only = false;
  public bool read_only {
    set {
      assert (value);
      if (mm_widget != null)
        mm_widget.sensitive = !value;
      if (quoted_mm_widget != null)
        quoted_mm_widget.sensitive = !value;

      name_label.set_markup("<b>" + GLib.Markup.escape_text(tweet.get_user_name()) + "</b>  @" + tweet.get_screen_name());
      this.get_style_context ().add_class ("read-only");
      this._read_only = value;
    }
  }
  public bool shows_actions {
    get {
      return stack.visible_child == action_box;
    }
  }
  private unowned Account account;
  private unowned MainWindow main_window;
  public Cb.Tweet tweet;
  private bool values_set = false;
  private bool delete_first_activated = false;
  private GLib.TimeSpan last_timediff;
  [Signal (action = true)]
  private signal void reply_tweet ();
  [Signal (action = true)]
  private signal void favorite_tweet ();
  [Signal (action = true)]
  private signal void retweet_tweet ();
  [Signal (action = true)]
  private signal void delete_tweet ();
  [Signal (action = true)]
  private signal void quote_tweet ();

  public TweetListEntry (Cb.Tweet    tweet,
                         MainWindow? main_window,
                         Account     account,
                         bool        restrict_height = false) {
    this.account = account;
    this.tweet = tweet;
    this.main_window = main_window;

    var name = tweet.get_user_name ();
    var screen_name = "@" + tweet.get_screen_name ();
    Cb.UserIdentity author;
    if (tweet.retweeted_tweet != null) {
      author = tweet.retweeted_tweet.author;
    } else {
      author = tweet.source_tweet.author;
    }
    name_label.set_markup ("%s  &#x2068;%s&#x2069;".printf(Utils.linkify_user (author, true), screen_name));
    name_label.tooltip_text = "%s \u2068%s\u2069".printf(name, screen_name);
    if (tweet.avatar_url != null) {
      string avatar_url = tweet.avatar_url;
      if (this.get_scale_factor () == 2)
        avatar_url = avatar_url.replace ("_normal", "_bigger");
      Twitter.get ().get_avatar.begin (tweet.get_user_id (), avatar_url, avatar_image,
                                       48 * this.get_scale_factor ());
    }
    avatar_image.verified = tweet.is_flag_set (Cb.TweetState.VERIFIED);
    avatar_image.protected_account = tweet.is_flag_set (Cb.TweetState.PROTECTED);
    
    if (tweet.retweeted_tweet != null) {
      var rt_author = tweet.source_tweet.author;
      rt_label.show ();
      rt_image.show ();
      rt_label.label = "%s  &#x2068;@%s&#x2069;".printf(Utils.linkify_user (rt_author), rt_author.screen_name);
      // Set the accessible text as a single string rather than trying to make screen readers read
      // separate text for the RT icon and the names
      // TRANSLATORS: replacements are name and handle (without the "@")
      var rt_by = _("Retweeted by %s (@%s)").printf(rt_author.user_name, rt_author.screen_name);
      rt_label.get_accessible().set_name(rt_by);
      rt_label.get_accessible().set_name(rt_by);
    }

    if ((tweet.retweeted_tweet != null &&
         tweet.retweeted_tweet.reply_id != 0) ||
        (tweet.source_tweet.reply_id != 0 && (tweet.quoted_tweet == null || tweet.source_tweet.reply_id != tweet.quoted_tweet.id))) {
      var buff = new StringBuilder ();

      if (tweet.retweeted_tweet != null)
        Cb.Utils.write_reply_text (ref tweet.retweeted_tweet, buff);
      else
        Cb.Utils.write_reply_text (ref tweet.source_tweet, buff);

      if (buff.str != "") {
        reply_label.label = buff.str;
        reply_label.show ();
      } else {
        reply_label.hide ();
      }
    }

    if (tweet.quoted_tweet != null) {
      this.create_quote_grid (tweet.quoted_tweet.reply_id != 0);
      var quoted_screen_name = "@" + tweet.quoted_tweet.author.screen_name;
      quote_name.set_markup ("%s  &#x2068;%s&#x2069;".printf(Utils.linkify_user (tweet.quoted_tweet.author, true), quoted_screen_name));
      quote_name.tooltip_text = "%s \u2068%s\u2069".printf(tweet.quoted_tweet.author.user_name, quoted_screen_name);
      if (tweet.quoted_tweet.reply_id != 0) {
        var buff = new GLib.StringBuilder ();
        Cb.Utils.write_reply_text (ref tweet.quoted_tweet, buff);

        if (buff.str != "") {
          quote_reply_label.label = buff.str;
          quote_reply_label.show ();
        } else {
          quote_reply_label.hide ();
        }
      }
    }

    retweet_button.active    =   tweet.is_flag_set (Cb.TweetState.RETWEETED);
    retweet_button.sensitive = !(tweet.is_flag_set (Cb.TweetState.PROTECTED) &&
                                 tweet.get_user_id () != account.id);

    favorite_button.active = tweet.is_flag_set (Cb.TweetState.FAVORITED);

    tweet.state_changed.connect (state_changed_cb);

    conversation_image.visible = (tweet.source_tweet.reply_id != 0 ||
      (tweet.retweeted_tweet != null && tweet.retweeted_tweet.reply_id != 0));

    if (tweet.has_inline_media ()) {
      this.create_media_widget (tweet.is_flag_set (Cb.TweetState.NSFW), out this.mm_widget, out this.media_stack);
      Gtk.Widget w = media_stack != null ? ((Gtk.Widget)media_stack) : ((Gtk.Widget)mm_widget);
      this.grid.attach (w, 2, 3, 5, 1);
      mm_widget.restrict_height = restrict_height;
      mm_widget.set_all_media (tweet.get_medias ());
      mm_widget.media_clicked.connect (media_clicked_cb);
      mm_widget.media_invalid.connect (media_invalid_cb);
      mm_widget.window = main_window;
    }

    if (tweet.has_quoted_inline_media ()) {
      this.create_media_widget (tweet.is_quoted_flag_set (Cb.TweetState.NSFW), out this.quoted_mm_widget, out this.quoted_media_stack);
      quoted_mm_widget.margin_start = 12;
      Gtk.Widget w = quoted_media_stack != null ? ((Gtk.Widget)quoted_media_stack) : ((Gtk.Widget)quoted_mm_widget);
      this.quote_grid.attach (w, 0, 3, 3, 1);
      quoted_mm_widget.restrict_height = restrict_height;
      quoted_mm_widget.set_all_media (tweet.get_quoted_medias ());
      quoted_mm_widget.media_clicked.connect (quoted_media_clicked_cb);
      quoted_mm_widget.media_invalid.connect (quoted_media_invalid_cb);
      quoted_mm_widget.window = main_window;
    }

    if (tweet.has_inline_media () || tweet.has_quoted_inline_media ()) {
      Settings.get ().changed["media-visibility"].connect (media_visibility_changed_cb);

      if (tweet.is_flag_set (Cb.TweetState.NSFW) || tweet.is_quoted_flag_set (Cb.TweetState.NSFW))
        Settings.get ().changed["hide-nsfw-content"].connect (hide_nsfw_content_changed_cb);
    }

    var actions = new GLib.SimpleActionGroup ();
    actions.add_action_entries (action_entries, this);
    this.insert_action_group ("tweet", actions);

    if (tweet.get_user_id () != account.id)
      ((GLib.SimpleAction)actions.lookup_action ("delete")).set_enabled (false);

    if (tweet.is_flag_set (Cb.TweetState.PROTECTED))
      ((GLib.SimpleAction)actions.lookup_action ("quote")).set_enabled (false);

    reply_tweet.connect (reply_tweet_activated);
    delete_tweet.connect (delete_tweet_activated);
    quote_tweet.connect (quote_activated);
    favorite_tweet.connect (() => {
      favorite_button.active = !favorite_button.active;
    });
    retweet_tweet.connect (() => {
      retweet_button.tap ();
    });

    if (tweet.is_flag_set (Cb.TweetState.FAVORITED))
      fav_status_image.show ();

    if (tweet.is_flag_set (Cb.TweetState.RETWEETED))
      rt_status_image.show ();

    values_set = true;

    set_tweet_text();
    update_time_delta ();

    // TODO All these settings signal connections with lots of tweets could be costly...
    Settings.get ().changed["text-transform-flags"].connect (set_tweet_text);
  }

  ~TweetListEntry () {
    Settings.get ().changed["text-transform-flags"].disconnect (set_tweet_text);

    if (tweet.is_flag_set (Cb.TweetState.NSFW) || tweet.is_quoted_flag_set (Cb.TweetState.NSFW))
      Settings.get ().changed["hide-nsfw-content"].disconnect (hide_nsfw_content_changed_cb);

    if (this.mm_widget != null || this.mm_widget != null)
      Settings.get ().changed["media-visibility"].disconnect (media_visibility_changed_cb);
  }

  private void media_visibility_changed_cb () {
    if (Settings.get_media_visiblity () == MediaVisibility.SHOW) {
      if (mm_widget != null) {
        this.mm_widget.show ();
      }
      if (quoted_mm_widget != null) {
        this.quoted_mm_widget.show ();
      }
    } else {
      if (mm_widget != null) {
        this.mm_widget.hide ();
      }
      if (quoted_mm_widget != null) {
        this.quoted_mm_widget.hide ();
      }
    }

    set_tweet_text();
  }

  private void set_tweet_text() {
    Cb.TransformFlags transform_flags = Settings.get_text_transform_flags ();

    if (Settings.get_media_visiblity () != MediaVisibility.SHOW) {
      // Forcefully unset "remove media links" so people can see there's media without loading it
      transform_flags &= ~Cb.TransformFlags.REMOVE_MEDIA_LINKS;
    }

    text_label.label = tweet.get_trimmed_text (transform_flags);
    if (this.tweet.quoted_tweet != null) {
      this.quote_label.label = Cb.TextTransform.tweet (ref tweet.quoted_tweet, transform_flags, 0);
      if (quote_label.label == "") {
        quote_label.hide ();
      }
    }

    if (this.mm_widget != null) {
      Gtk.Widget w = media_stack != null ? ((Gtk.Widget)media_stack) : ((Gtk.Widget)mm_widget);

      // Move the media widget up (to overlap with avatar) if there's no text
      // We don't do this for quoted images because there is no avatar
      if (text_label.label == "") {
        this.grid.child_set (w, "top-attach", 2);
        scroller.hide();
      }
      else {
        this.grid.child_set (w, "top-attach", 3);
        scroller.show();
      }
    }
  }

  private void hide_nsfw_content_changed_cb () {
    if (this.media_stack != null) {
      if (this.tweet.is_flag_set (Cb.TweetState.NSFW) &&
          Settings.hide_nsfw_content ())
        this.media_stack.visible_child_name = "nsfw";
      else
        this.media_stack.visible_child = mm_widget;
    }
    if (this.quoted_media_stack != null) {
      if (this.tweet.is_quoted_flag_set (Cb.TweetState.NSFW) &&
          Settings.hide_nsfw_content ())
        this.quoted_media_stack.visible_child_name = "nsfw";
      else
        this.quoted_media_stack.visible_child = quoted_mm_widget;
    }
  }

  private void media_clicked_cb (Cb.Media m, int index, double px, double py) {
    TweetUtils.handle_media_click (this.tweet.get_medias (), this.main_window, index);
  }

  private void quoted_media_clicked_cb (Cb.Media m, int index, double px, double py) {
    TweetUtils.handle_media_click (this.tweet.get_quoted_medias (), this.main_window, index);
  }

  private void delete_tweet_activated () {
    if (tweet.get_user_id () != account.id)
      return; // Nope.

    if (delete_first_activated) {
      TweetUtils.delete_tweet.begin (account, tweet, (obj, res) => {
        var success = false;
        try {
          success = TweetUtils.delete_tweet.end (res);
        } catch (GLib.Error e) {
          Utils.show_error_dialog (e, main_window);
        }
        if (success) {
          sensitive = false;
          if (shows_actions) {
            toggle_mode ();
          }
        }
      });
    } else
      delete_first_activated = true;
  }

  static construct {
    unowned Gtk.BindingSet binding_set = Gtk.BindingSet.by_class ((GLib.ObjectClass)typeof (TweetListEntry).class_ref ());

    Gtk.BindingEntry.add_signal (binding_set, Gdk.Key.r, 0, "reply-tweet", 0, null);
    Gtk.BindingEntry.add_signal (binding_set, Gdk.Key.d, 0, "delete-tweet", 0, null);
    Gtk.BindingEntry.add_signal (binding_set, Gdk.Key.t, 0, "retweet-tweet", 0, null);
    Gtk.BindingEntry.add_signal (binding_set, Gdk.Key.f, 0, "favorite-tweet", 0, null);
    Gtk.BindingEntry.add_signal (binding_set, Gdk.Key.q, 0, "quote-tweet", 0, null);
  }

  [GtkCallback]
  private bool focus_out_cb (Gdk.EventFocus evt) {
    delete_first_activated = false;
    retweet_button.reset ();
    return false;
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

  /**
   * Retweets or un-retweets the tweet.
   */
  [GtkCallback]
  private void retweet_button_toggled_cb () {
    bool retweetable = tweet.get_user_id () == account.id ||
                       !tweet.is_flag_set (Cb.TweetState.PROTECTED);

    if (!retweetable || !values_set)
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
        if (shows_actions) {
          toggle_mode ();
        }
      } else {
        retweet_button.active = tweet.is_flag_set (Cb.TweetState.RETWEETED);
      }

      retweet_button.sensitive = true;
    });
  }

  [GtkCallback]
  private void favorite_button_toggled_cb () {
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
        if (shows_actions) {
          toggle_mode ();
        }
      } else {
        favorite_button.active = tweet.is_flag_set (Cb.TweetState.FAVORITED);
      }

      favorite_button.sensitive = true;
    });
  }

  [GtkCallback]
  private void reply_button_clicked_cb () {
    ComposeTweetWindow ctw = new ComposeTweetWindow (this.main_window, this.account, this.tweet,
                                                     ComposeTweetWindow.Mode.REPLY);
    ctw.show ();
    if (shows_actions)
      toggle_mode ();
  }

  private void quote_activated () {
    ComposeTweetWindow ctw = new ComposeTweetWindow (this.main_window, this.account, this.tweet,
                                                     ComposeTweetWindow.Mode.QUOTE);
    ctw.show ();

    if (shows_actions)
      toggle_mode ();
  }

  private void reply_tweet_activated () {
    ComposeTweetWindow ctw = new ComposeTweetWindow (this.main_window, this.account, this.tweet,
                                                     ComposeTweetWindow.Mode.REPLY);
    ctw.show ();
  }

  private void delete_activated () {
    delete_first_activated = true;
    delete_tweet ();
  }

  [GtkCallback]
  private bool link_activated_cb (string uri) {
    if (this._read_only) {
      return false;
    }

    this.grab_focus ();

    return TweetUtils.activate_link (uri, main_window);
  }

  [GtkCallback]
  private void populate_popup_cb (Gtk.Label source, Gtk.Menu menu) {
    var link_text = source.get_current_uri ();
    if (link_text.has_prefix ("#")) {
      var item = new Gtk.MenuItem.with_label (_("Block %s").printf (link_text));
      item.show ();
      item.activate.connect (() => {
        Utils.create_persistent_filter (link_text, account);
        main_window.rerun_filters ();
      });
      menu.add (item);
    }
  }

  private void media_invalid_cb () {
    Cb.TransformFlags flags = Settings.get_text_transform_flags ()
                              & ~Cb.TransformFlags.REMOVE_MEDIA_LINKS;

    string new_text;
    if (tweet.retweeted_tweet != null)
      new_text = Cb.TextTransform.tweet (ref tweet.retweeted_tweet, flags, 0);
    else
      new_text = Cb.TextTransform.tweet (ref tweet.source_tweet, flags, 0);

    this.text_label.label = new_text;
  }

  private void quoted_media_invalid_cb () {
    //FIXME: Use quoted flags, once/if implemented
    Cb.TransformFlags flags = Settings.get_text_transform_flags ()
                              & ~Cb.TransformFlags.REMOVE_MEDIA_LINKS;

    if (tweet.quoted_tweet != null) {
      string new_quote_text = Cb.TextTransform.tweet (ref tweet.quoted_tweet,
                                                      flags, 0);
      this.quote_label.label = new_quote_text;
    }
  }

  private void state_changed_cb () {
    this.values_set = false;
    this.fav_status_image.visible = tweet.is_flag_set (Cb.TweetState.FAVORITED);
    this.favorite_button.active = tweet.is_flag_set (Cb.TweetState.FAVORITED);

    this.retweet_button.active = tweet.is_flag_set (Cb.TweetState.RETWEETED);
    this.rt_status_image.visible = tweet.is_flag_set (Cb.TweetState.RETWEETED);

    if (tweet.is_flag_set (Cb.TweetState.DELETED)) {
      this.sensitive = false;
      stack.visible_child = grid;
    }

    this.values_set = true;
  }

  public void set_avatar (Cairo.Surface surface) {
    /* This should only ever be called from the settings page. */
    this.avatar_image.surface = surface;
  }


  /**
   * Updates the time delta label in the upper right
   *
   * @return The seconds between the current time and
   *         the time the tweet was created
   */
  public int update_time_delta (GLib.DateTime? now = null) {
    GLib.DateTime cur_time;
    if (now == null)
      cur_time = new GLib.DateTime.now_local ();
    else
      cur_time = now;

    GLib.DateTime then = new GLib.DateTime.from_unix_local (
                             tweet.retweeted_tweet != null ? tweet.retweeted_tweet.created_at :
                                                             tweet.source_tweet.created_at);

    var link = "https://twitter.com/%s/status/%s".printf (tweet.source_tweet.author.screen_name, tweet.id.to_string());
    time_delta_label.label = "<span underline='none'><a href='%s' title='%s'>%s</a></span>"
                             .printf (link, _("Open in Browser"), GLib.Markup.escape_text(Utils.get_time_delta(then, cur_time)));

    var long_delta = Utils.get_time_delta(then, cur_time, true);
    time_delta_label.get_accessible().set_name(long_delta);
    time_delta_label.get_accessible().set_description(long_delta);

    if (quote_time_delta != null) {
      then = new GLib.DateTime.from_unix_local (tweet.quoted_tweet.created_at);
      link = "https://twitter.com/%s/status/%s".printf (tweet.quoted_tweet.author.screen_name, tweet.quoted_tweet.id.to_string());
      quote_time_delta.label = "<span underline='none'><a href='%s' title='%s'>%s</a></span>"
                         .printf (link, _("Open in Browser"), GLib.Markup.escape_text(Utils.get_time_delta(then, cur_time)));
      var long_quote_delta = Utils.get_time_delta(then, cur_time, true);
      quote_time_delta.get_accessible().set_name(long_quote_delta);
      quote_time_delta.get_accessible().set_description(long_quote_delta);
    }

    return (int)(cur_time.difference (then) / 1000.0 / 1000.0);
  }

  public int64 get_sort_factor () {
    return tweet.source_tweet.id;
  }

  public int64 get_timestamp () {
    return tweet.source_tweet.created_at;
  }

  public GLib.TimeSpan get_last_set_timediff () {
    return this.last_timediff;
  }

  public void set_last_set_timediff (GLib.TimeSpan span) {
    this.last_timediff = span;
  }

  public void toggle_mode () {
    if (this._read_only)
      return;

    if (stack.visible_child == action_box) {
      stack.visible_child = grid;
      this.activatable = true;
      this.grab_focus();
    } else {
      stack.visible_child = action_box;
      this.activatable = false;
      retweet_button.grab_focus();
    }
  }


  private int64 start_time;
  private int64 end_time;

  private bool anim_tick (Gtk.Widget widget, Gdk.FrameClock frame_clock) {
    int64 now = frame_clock.get_frame_time ();

    if (now > end_time) {
      this.opacity = 1.0;
      return false;
    }

    double t = (now - start_time) / (double)(end_time - start_time);

    t = ease_out_cubic (t);

    this.opacity = t;

    return true;
  }

  public void fade_in () {
    if (this.get_realized ()) {
      this.show ();
      return;
    }

    ulong realize_id = 0;
    realize_id = this.realize.connect (() => {
      this.start_time = this.get_frame_clock ().get_frame_time ();
      this.end_time = start_time + TRANSITION_DURATION;
      this.add_tick_callback (anim_tick);
      this.disconnect (realize_id);
    });

    this.show ();
  }

  private void create_media_widget (bool nsfw, out MultiMediaWidget? mm_widget, out Gtk.Stack? media_stack) {
    // Note: We need to use local variables first, because the anonymous function won't capture an "out" parameter
    MultiMediaWidget _mm_widget = new MultiMediaWidget ();
    _mm_widget.halign = Gtk.Align.FILL;
    _mm_widget.hexpand = true;
    _mm_widget.margin_top = 6;

    if (nsfw) {
      Gtk.Stack _media_stack = new Gtk.Stack ();
      _media_stack.transition_type = Gtk.StackTransitionType.CROSSFADE;
      _media_stack.add (_mm_widget);
      var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
      box.valign = Gtk.Align.CENTER;
      var label = new Gtk.Label (_("This tweet contains images marked as inappropriate"));
      label.margin_start = 12;
      label.margin_end = 12;
      label.wrap = true;
      label.wrap_mode = Pango.WrapMode.WORD_CHAR;
      box.add (label);

      var button = new Gtk.Button.with_label (_("Show anyway"));
      button.halign = Gtk.Align.CENTER;
      button.valign = Gtk.Align.CENTER;
      button.clicked.connect (() => { 
        _media_stack.visible_child = _mm_widget;
      });
      box.add (button);

      _media_stack.add_named (box, "nsfw");
      _media_stack.show_all ();
      if (Settings.hide_nsfw_content ())
        _media_stack.visible_child_name = "nsfw";
      else
        _media_stack.visible_child = _mm_widget;
      media_stack = _media_stack;
    } else {
      /* We will never have to hide mm_widget */
      _mm_widget.show_all ();
      media_stack = null;
    }
    mm_widget = _mm_widget;
    mm_widget.visible = (Settings.get_media_visiblity () == MediaVisibility.SHOW);
  }

  public override void get_preferred_height_for_width (int width, out int min, out int nat) {
    if ((width < Cawbird.RESPONSIVE_LIMIT) == (get_allocated_width() < Cawbird.RESPONSIVE_LIMIT)) {
      // We're staying the same side of the limit, so let GTK do everything
      base.get_preferred_height_for_width(width, out min, out nat);
      return;
    }

    // We're crossing the responsive threshold, so approximate a calculation.
    int margins = 0;
    var orig_width = width;
    var style = this.get_style_context();
    var style_margin = style.get_margin(0);
    var style_padding = style.get_padding(0);
    var style_borders = style.get_border(0);
    margins += style_margin.left + style_margin.right;
    margins += style_padding.left + style_padding.right;
    margins += style_borders.left + style_borders.right;
    GLib.Value val = GLib.Value(typeof(int));
    grid.get_property("margin-start", ref val);
    margins += val.get_int();
    grid.get_property("margin-end", ref val);
    margins += val.get_int();
    width -= margins;

    int avatar_min, avatar_nat;
    avatar_image.get_preferred_height_for_width(width, out avatar_min, out avatar_nat);

    int child_min, child_nat;
    min = nat = 0;

    int avatar_width;
    avatar_image.get_preferred_width (out avatar_width, out child_nat);

    // Name and reply label are always next to the avatar, no matter the scale
    name_label.get_preferred_height_for_width(width - avatar_width, out child_min, out child_nat);
    min += child_min;
    nat += child_nat;
    reply_label.get_preferred_height_for_width(width - avatar_width, out child_min, out child_nat);
    min += child_min;
    nat += child_nat;

    if (orig_width < Cawbird.RESPONSIVE_LIMIT) {
      // In "responsive" mode the text sits under the avatar, so take whichever is taller:
      // the avatar or the user's name and the "Replying to" line (if it was set)
      min = int.max(avatar_min, min);
      nat = int.max(avatar_nat, nat);
      // Subtract the extra margin we'll add during allocation
      width -= 6;
    }
    else {
      // All the other widgets don't fill the column under the avatar, so reduce the width
      // that they calculate from
      width -= avatar_width;
      // But pretend it is a little wider because they still have their margins until allocation
      width += 6;
    }

    scroller.get_preferred_height_for_width(width, out child_min, out child_nat);
    min += child_min;
    nat += child_nat;

    // If the text is short in "wide mode" then the avatar may still be the tallest thing
    // so check our minimums
    min = int.max(avatar_min, min);
    nat = int.max(avatar_nat, nat);

    if (mm_widget != null) {
      Gtk.Widget w = media_stack != null ? ((Gtk.Widget)media_stack) : ((Gtk.Widget)mm_widget);
      w.get_preferred_height_for_width(width, out child_min, out child_nat);
      min += child_min;
      nat += child_nat;
    }

    if (quote_grid != null) {
      quote_grid.get_preferred_height_for_width(width, out child_min, out child_nat);
      min += child_min;
      nat += child_nat;
    }

    if (rt_label.visible) {
      int child2_min, child2_nat;
      rt_label.get_preferred_height_for_width(width, out child_min, out child_nat);
      rt_image.get_preferred_height_for_width(width, out child2_min, out child2_nat);
      min += int.max(child_min, child2_min);
      nat += int.max(child_nat, child2_nat);
    }

    min = int.max(avatar_min, min);
    nat = int.max(avatar_nat, nat);

    // Add the vertical GTK margins
    grid.get_property("margin-top", ref val);
    min += val.get_int();
    nat += val.get_int();
    grid.get_property("margin-bottom", ref val);
    min += val.get_int();
    nat += val.get_int();

    // And any CSS values
    var css_extra_height = style_margin.top + style_margin.bottom + style_padding.top + style_padding.bottom + style_borders.top + style_borders.bottom;
    min += css_extra_height;
    nat += css_extra_height;
  }

  public override void size_allocate(Gtk.Allocation allocation) {
    if ((allocation.width < Cawbird.RESPONSIVE_LIMIT) != (get_allocated_width() < Cawbird.RESPONSIVE_LIMIT)) {
      // We've crossed the threshold, so reallocate as appropriate
      if (allocation.width < Cawbird.RESPONSIVE_LIMIT) {
        grid.child_set (avatar_image, "height", 2);
        grid.child_set (scroller, "left-attach", 0);
        grid.child_set (scroller, "width", 7);
        scroller.set ("margin-start", 6);
        grid.child_set (rt_image, "left-attach", 0);
        grid.child_set (rt_label, "left-attach", 1);
        if (mm_widget != null) {
          Gtk.Widget w = media_stack != null ? ((Gtk.Widget)media_stack) : ((Gtk.Widget)mm_widget);
          grid.child_set (w, "left-attach", 0);
          grid.child_set (w, "width", 7);
          w.set ("margin-start", 6);
        }
        if (quote_grid != null) {
          grid.child_set (quote_grid, "left-attach", 0);
          grid.child_set (quote_grid, "width", 7);
          quote_grid.set ("margin-start", 6);
        }
      } else {
        grid.child_set (avatar_image, "height", 3);
        grid.child_set (scroller, "left-attach", 2);
        grid.child_set (scroller, "width", 5);
        scroller.set ("margin-start", 0);
        grid.child_set (rt_image, "left-attach", 1);
        grid.child_set (rt_label, "left-attach", 2);
        if (mm_widget != null) {
          Gtk.Widget w = media_stack != null ? ((Gtk.Widget)media_stack) : ((Gtk.Widget)mm_widget);
          grid.child_set (w, "left-attach", 2);
          grid.child_set (w, "width", 5);
          w.set ("margin-start", 0);
        }
        if (quote_grid != null) {
          grid.child_set (quote_grid, "left-attach", 2);
          grid.child_set (quote_grid, "width", 5);
          quote_grid.set ("margin-start", 0);
        }
      }
    }
    base.size_allocate(allocation);
  }

  private bool quote_link_activated_cb (string uri) {
    if (this._read_only) {
      return false;
    }

    this.grab_focus ();

    return TweetUtils.activate_link (uri, main_window);
  }

  private void create_quote_grid (bool reply) {
    this.quote_grid = new Gtk.Grid ();
    quote_grid.margin_top = 6;
    quote_grid.margin_end = 6;
    quote_grid.get_style_context ().add_class ("quote");

    this.quote_name = new Gtk.Label ("");
    quote_name.halign = Gtk.Align.START;
    quote_name.valign = Gtk.Align.BASELINE;
    quote_name.margin_start = 12;
    quote_name.margin_end = 6;
    quote_name.ellipsize = Pango.EllipsizeMode.END;
    quote_name.activate_link.connect (quote_link_activated_cb);
    quote_name.get_style_context ().add_class ("name");
    quote_grid.attach (quote_name, 0, 0, 2, 1);

    if (reply) {
      this.quote_reply_label = new Gtk.Label ("");
      quote_reply_label.halign = Gtk.Align.START;
      quote_reply_label.set_use_markup (true);
      quote_reply_label.xalign = 0;
      quote_reply_label.set_margin_start (12);
      quote_reply_label.set_margin_bottom (4);
      quote_reply_label.activate_link.connect (quote_link_activated_cb);
      quote_reply_label.get_style_context ().add_class ("dim-label");
      quote_reply_label.get_style_context ().add_class ("invisible-links");
      quote_reply_label.set_no_show_all (true);
      quote_reply_label.wrap = true;

      quote_grid.attach (quote_reply_label, 0, 1, 3, 1);
    }

    this.quote_label = new Gtk.Label ("");
    quote_label.halign = Gtk.Align.START;
    quote_label.hexpand = true;
    quote_label.xalign = 0;
    quote_label.use_markup = true;
    quote_label.wrap = true;
    quote_label.wrap_mode = Pango.WrapMode.WORD_CHAR;
    quote_label.track_visited_links = false;
    quote_label.margin_start = 12;
    quote_label.activate_link.connect (quote_link_activated_cb);
    quote_label.populate_popup.connect (populate_popup_cb);
    var attrs = new Pango.AttrList ();
    attrs.insert (Pango.attr_style_new (Pango.Style.ITALIC));
    quote_label.set_attributes (attrs);
    if (reply)
      quote_grid.attach (quote_label, 0, 2, 3, 1);
    else
      quote_grid.attach (quote_label, 0, 1, 3, 1);

    this.quote_time_delta = new Gtk.Label ("");
    quote_time_delta.halign = Gtk.Align.END;
    quote_time_delta.set_use_markup (true);
    quote_grid.attach (quote_time_delta, 2, 0, 1, 1);

    quote_grid.show_all ();
    this.grid.attach (quote_grid, 2, 4, 5, 1);
  }
}
