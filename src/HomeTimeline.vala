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

public class HomeTimeline : Cb.MessageReceiver, DefaultTimeline {
  private int64 last_tweet_id = 0;

  protected override string function {
    get {
      return "1.1/statuses/home_timeline.json";
    }
  }

  protected override string accessibility_name {
    get {
      return _("Home timeline");
    }
  }

  public HomeTimeline(int id, Account account) {
    base (id);
    this.account = account;
    this.tweet_list.account = account;
  }

  protected override void stream_message_received (Cb.StreamMessageType type, Json.Node root) {
    if (type == Cb.StreamMessageType.TWEET) {
      add_tweet (root);
    }
    else if (type == Cb.StreamMessageType.TIMELINE_LOADED) {
      this.preload_is_complete = true;
    }
    else if (type == Cb.StreamMessageType.EVENT_UNFOLLOW) {
      hide_tweets_from (root, Cb.TweetState.HIDDEN_UNFOLLOWED);
    }
    else if (type == Cb.StreamMessageType.EVENT_FOLLOW) {
      show_tweets_from (root, Cb.TweetState.HIDDEN_UNFOLLOWED);
    }
    else {
      base.stream_message_received (type, root);
    }
  }

  protected void add_tweet (Json.Node obj) {
    GLib.DateTime now = new GLib.DateTime.now_local ();
    Cb.Tweet t = new Cb.Tweet ();
    t.load_from_json (obj, this.account.id, now);

    /* We don't use the set_state version from Cb.TweetModel here since
       we just decide the initial visibility of the tweet */
    if (t.retweeted_tweet != null) {
      if (t.source_tweet.author.id == account.id) {
        // Don't show our own RTs if we inject them, because Twitter
        // doesn't provide them in a normal home timeline request.
        // But we should update the RT status.
        Utils.set_rt_from_tweet (obj, this.tweet_list.model, this.account);
        return;
      }

      t.set_flag (get_rt_flags (t));
    }

    TweetUtils.set_tweet_hidden_flags(t, account);

    bool auto_scroll = Settings.auto_scroll_on_new_tweets ();
    bool is_new_unread = false;

    if (t.id < last_tweet_id && !tweet_list.model.contains_id (t.id)) {
      int64 age_diff = (int64)(((last_tweet_id >> 22) / 1000) - ((t.id >> 22) / 1000));
      debug("Loaded missing tweet %lld (%lld seconds older than %lld)", t.id, age_diff, last_tweet_id);
      is_new_unread = true;
    }
    else if (t.id > last_tweet_id && t.source_tweet.author.id != account.id) {
      // Keep track of the last ID we saw.
      // Ignore our own tweets because they get injected and come out of sequence.
      // This is also the reason we can't just use the model's max_id
      last_tweet_id = t.id;
      is_new_unread = true;
    }
    // Else we've seen it before, so change nothing

    t.set_seen (t.source_tweet.author.id == account.id ||
                (t.retweeted_tweet != null && t.retweeted_tweet.author.id == account.id) ||
                (this.scrolled_up  &&
                 main_window.cur_page_id == this.id &&
                 auto_scroll) ||
                ! preload_is_complete);

    bool focused = tweet_list.get_first_visible_row () != null &&
                   tweet_list.get_first_visible_row ().is_focus;

    bool should_focus = (focused && this.scrolled_up);

    tweet_list.model.add (t);

    if (!t.is_hidden ()) {
      if (auto_scroll) {
        base.scroll_up (t);
      } else if (preload_is_complete) {
        /* We need to balance even if we don't scroll up, in case
          auto-scroll-on-new-tweets is disabled */
        this.balance_next_upper_change (TOP);
      }

      if (!t.get_seen () && preload_is_complete && is_new_unread) {
        this.unread_count ++;
      }
    } else {
      t.set_seen (true);
    }

    if (should_focus) {
      tweet_list.get_first_visible_row ().grab_focus ();
    }

    /* The rest of this function deals with notifications which we certainly
       don't want to show for invisible tweets */
    if (t.is_hidden ())
      return;

    // We never show any notifications if auto-scroll-on-new-tweet is enabled
    // or if it's our tweet or an initial load
    int stack_size = Settings.get_tweet_stack_count ();
    if (t.get_user_id () == account.id || auto_scroll || !preload_is_complete)
      return;

    if (stack_size == 1 && !auto_scroll) {
      string summary = "";
      if (t.retweeted_tweet != null){
        summary = _("%s retweeted %s").printf (t.source_tweet.author.user_name,
                                               t.retweeted_tweet.author.user_name);
      } else {
        summary = _("%s tweeted").printf (t.source_tweet.author.user_name);
      }
      string id_suffix = "tweet-%s".printf (t.id.to_string ());
      t.notification_id = account.notifications.send (summary,
                                                      t.get_real_text (),
                                                      id_suffix);

    } else if(stack_size != 0 && unread_count % stack_size == 0
              && unread_count > 0) {
      string summary = ngettext("%d new Tweet!",
                                "%d new Tweets!", unread_count).printf (unread_count);
      account.notifications.send (summary, "");
    }
  }

  public override string get_title () {
    return "@" + account.screen_name;
  }

  public override void create_radio_button (Gtk.RadioButton? group) {
    radio_button = new BadgeRadioButton(group, "cawbird-user-home-symbolic", _("Home"));
  }
}
