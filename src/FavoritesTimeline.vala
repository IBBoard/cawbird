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

class FavoritesTimeline : Cb.MessageReceiver, DefaultTimeline {
  protected override string function {
    get {
      return "1.1/favorites/list.json";
    }
  }

  protected override string accessibility_name {
    get {
      return _("Favourites timeline");
    }
  }

  public FavoritesTimeline (int id, Account account) {
    base (id);
    this.account = account;
    this.tweet_list.account = account;
  }

  protected override void stream_message_received (Cb.StreamMessageType type, Json.Node root) {
    if (type == Cb.StreamMessageType.TWEET) {    
      if (root.get_object ().has_member ("retweeted_status")) {
        Utils.set_rt_from_tweet (root, this.tweet_list.model, this.account);
      }      
    } else if (type == Cb.StreamMessageType.DELETE) {
      int64 id = root.get_object ().get_object_member ("delete")
                     .get_object_member ("status").get_int_member ("id");
      delete_tweet (id);
    } else if (type == Cb.StreamMessageType.RT_DELETE) {
      Utils.unrt_tweet (root, this.tweet_list.model);
    } else if (type == Cb.StreamMessageType.EVENT_FAVORITE) {
      Json.Node tweet_obj = root;
      int64 tweet_id = tweet_obj.get_object ().get_int_member ("id");

      Cb.Tweet? existing_tweet = this.tweet_list.model.get_for_id (tweet_id, 0);
      if (existing_tweet != null) {
        /* This tweet is already in the model, so just mark it as favorited */
        tweet_list.model.set_tweet_flag (existing_tweet, Cb.TweetState.FAVORITED);
        return;
      }

      var tweet = new Cb.Tweet ();
      tweet.load_from_json (tweet_obj, account.id, new GLib.DateTime.now_local ());
      tweet.set_flag (Cb.TweetState.FAVORITED);
      this.tweet_list.model.add (tweet);
    } else if (type == Cb.StreamMessageType.EVENT_UNFAVORITE) {
      int64 id = root.get_object ().get_object_member ("target_object").get_int_member ("id");
      toggle_favorite (id, false);
    }
    else {
      // We don't do a full fall back to DefaultTimeline here because we want to keep content
      // we liked from people we then blocked/muted so that we can remove it
      handle_core_stream_messages (type, root);
    }
  }


  public override void on_leave () {
    for (uint i = 0; i < tweet_list.model.get_n_items (); i ++) {
      var tweet = (Cb.Tweet) tweet_list.model.get_item (i);
      if (!tweet.is_flag_set (Cb.TweetState.FAVORITED)) {
        tweet_list.model.remove_tweet (tweet);
        i --;
      }
    }

    base.on_leave ();
  }

  public override string get_title () {
    return _("Favorites");
  }

  public override void create_radio_button (Gtk.RadioButton? group) {
    radio_button = new BadgeRadioButton(group, "cawbird-favorite-symbolic", _("Favorites"));
  }
}
