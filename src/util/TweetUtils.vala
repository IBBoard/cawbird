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

namespace TweetUtils {
  /**
   * Fetches the given tweet by ID.
   *
   * Note: This should not be used frequently as we should (in most situations)
   * have all of the information that we need already.
   *
   * @param account The account to fetch the tweet as
   * @param tweet_id The ID of the tweet to fetch
   * @return the tweet object or null if it failed
   */
  async Cb.Tweet? get_tweet (Account account, int64 tweet_id) throws GLib.Error {
    if (tweet_id <= 0) {
      return null;
    }

    var call = account.proxy.new_call ();
    call.set_method ("GET");
    call.set_function ("1.1/statuses/show.json");
    call.add_param ("id", tweet_id.to_string ());
    call.add_param ("include_my_retweet", "true");
    call.add_param ("tweet_mode", "extended");
    Cb.Tweet? tweet = null;
    GLib.Error? err = null;

    call.invoke_async.begin (null, (obj, res) => {
      try {
        call.invoke_async.end (res);
        unowned string content = call.get_payload();
        var parser = new Json.Parser ();
        debug ("Load tweet got: %s", content);
        parser.load_from_data (content);
        var now = new GLib.DateTime.now_local ();
        tweet = new Cb.Tweet ();
        tweet.load_from_json (parser.get_root (), account.id, now);
        get_tweet.callback ();
      } catch (GLib.Error e) {
        err = e;
        get_tweet.callback ();
        return;
      }
    });
    yield;
    if (err != null) {
      throw err;
    }
    return tweet;
  }

  /**
   * Deletes the given tweet.
   *
   * @param account The account to delete the tweet from
   * @param tweet the tweet to delete
   * @return True if tweet was successfully deleted, else False
   */
  async bool delete_tweet (Account account, Cb.Tweet tweet) throws GLib.Error {
    var call = account.proxy.new_call ();
    call.set_method ("POST");
    call.set_function ("1.1/statuses/destroy/"+tweet.id.to_string ()+".json");
    call.add_param ("id", tweet.id.to_string ());
    var success = false;
    GLib.Error? err = null;
    call.invoke_async.begin (null, (obj, res) => {
      try {
        call.invoke_async.end (res);
      } catch (GLib.Error e) {
        warning ("Exception: %s in %s:%d", e.message, GLib.Log.FILE, GLib.Log.LINE);
        err = e;
        delete_tweet.callback ();
        return;
      }
      // TODO: Inject a deletion
      success = true;
      delete_tweet.callback ();
    });
    yield;
    if (err != null) {
      throw err;
    }
    return success;
  }

  /**
   * (Un)favorites the given tweet.
   *
   * @param account The account to (un)favorite from
   * @param tweet The tweet to (un)favorite
   * @param status %true to favorite the tweet, %false to unfavorite it.
   * @return True if favourited status was successfully changed, else False
   */
  async bool set_favorite_status (Account account, Cb.Tweet tweet, bool status) throws GLib.Error {
    if (tweet.is_flag_set (Cb.TweetState.FAVORITED) == status) {
      // We are already in the right state, so we didn't change it
      return false;
    }

    var call = account.proxy.new_call();
    if (status)
      call.set_function ("1.1/favorites/create.json");
    else
      call.set_function ("1.1/favorites/destroy.json");

    call.set_method ("POST");
    call.add_param ("id", tweet.id.to_string ());

    var success = false;
    GLib.Error? err = null;
    call.invoke_async.begin (null, (obj, res) => {
      try {
        call.invoke_async.end (res);
      } catch (GLib.Error e) {
        warning ("Exception: %s in %s:%d", e.message, GLib.Log.FILE, GLib.Log.LINE);
        err = e;
        set_favorite_status.callback ();
        return;
      }
      if (status)
        tweet.set_flag (Cb.TweetState.FAVORITED);
      else
        tweet.unset_flag (Cb.TweetState.FAVORITED);

      success = true;
      set_favorite_status.callback ();
    });
    yield;
    if (err != null) {
      throw err;
    }
    return success;
  }

  /**
   * (Un)retweets the given tweet.
   *
   * @param account The account to (un)retweet from
   * @param tweet The tweet to (un)retweet
   * @param status %true to retweet it, false to unretweet it.
   * @return True if retweet status was successfully changed, else False
   */
  async bool set_retweet_status (Account account, Cb.Tweet tweet, bool status) throws GLib.Error {
    if (tweet.is_flag_set (Cb.TweetState.RETWEETED) == status) {
      // We are already in the right state, so we didn't change it
      return false;
    }
    
    var call = account.proxy.new_call ();
    call.set_method ("POST");
    if (status)
      call.set_function (@"1.1/statuses/retweet/$(tweet.id).json");
    else
      call.set_function (@"1.1/statuses/destroy/$(tweet.my_retweet).json");

    var success = false;
    GLib.Error? err = null;
    call.invoke_async.begin (null, (obj, res) => {
      try{
        call.invoke_async.end (res);
      } catch (GLib.Error e) {
        warning ("Exception: %s in %s:%d", e.message, GLib.Log.FILE, GLib.Log.LINE);
        err = e;
        set_retweet_status.callback ();
        return;
      }
      unowned string back = call.get_payload();
      var parser = new Json.Parser ();
      try {
        parser.load_from_data (back);
        if (status) {
          int64 new_id = parser.get_root ().get_object ().get_int_member ("id");
          tweet.my_retweet = new_id;
        } else {
          tweet.my_retweet = 0;
        }
        if (status)
          tweet.set_flag (Cb.TweetState.RETWEETED);
        else
          tweet.unset_flag (Cb.TweetState.RETWEETED);
      } catch (GLib.Error e) {
        warning ("Exception: %s in %s:%d", e.message, GLib.Log.FILE, GLib.Log.LINE);
        info (back);
        err = e;
        return;
      }
      success = true;
      set_retweet_status.callback ();
    });
    yield;
    if (err != null) {
      throw err;
    }
    return success;
  }

  /**
   * Downloads the avatar from the given url.
   *
   * @param avatar_url The avatar url to download
   *
   * @return The loaded avatar.
   */
  async Gdk.Pixbuf? download_avatar (string avatar_url, int size = 48,
                                     GLib.Cancellable? cancellable = null) throws GLib.Error {
    Gdk.Pixbuf? avatar = null;
    var msg     = new Soup.Message ("GET", avatar_url);
    if (cancellable != null)
      cancellable.cancelled.connect (() => { SOUP_SESSION.cancel_message (msg, Soup.Status.CANCELLED); });

    GLib.Error? err = null;
    SOUP_SESSION.queue_message (msg, (s, _msg) => {
      if (_msg.status_code != Soup.Status.OK) {
        avatar = null;
        download_avatar.callback ();
        return;
      }
      var memory_stream = new MemoryInputStream.from_data(_msg.response_body.data,
                                                          GLib.g_free);
      try {
        avatar = new Gdk.Pixbuf.from_stream_at_scale (memory_stream,
                                                      size, size,
                                                      false);
      } catch (GLib.Error e) {
        err = e;
      }
      download_avatar.callback ();
    });
    yield;
    if (err != null) {
      throw err;
    }
    return avatar;
  }

  bool activate_link (string uri, MainWindow window) {
    debug ("Activating '%s'", uri);
    uri = uri._strip ();
    string term = uri.substring (1);

    if (uri.has_prefix ("@")) {
      int slash_index = uri.index_of ("/");
      var bundle = new Cb.Bundle ();
      if (slash_index == -1) {
        bundle.put_int64 (ProfilePage.KEY_USER_ID, int64.parse (term));
        window.main_widget.switch_page (Page.PROFILE, bundle);
      } else {
        bundle.put_int64 (ProfilePage.KEY_USER_ID, int64.parse (term.substring (0, slash_index - 1)));
        bundle.put_string (ProfilePage.KEY_SCREEN_NAME,
                           term.substring (slash_index + 1, term.length - slash_index - 1));
        window.main_widget.switch_page (Page.PROFILE, bundle);
      }
      return true;
    } else if (uri.has_prefix ("#")) {
      var bundle = new Cb.Bundle ();
      bundle.put_string (SearchPage.KEY_QUERY, uri);
      window.main_widget.switch_page (Page.SEARCH, bundle);
      return true;
    } else if (uri.has_prefix ("https://twitter.com/")) {
      // https://twitter.com/baedert/status/321423423423
      string[] parts = uri.split ("/");
      if (parts[4] == "status") {
        /* Treat it as a tweet link and hope it'll work out */
        int64 tweet_id = int64.parse (parts[5]);
        var bundle = new Cb.Bundle ();
        bundle.put_int (TweetInfoPage.KEY_MODE, TweetInfoPage.BY_ID);
        bundle.put_int64 (TweetInfoPage.KEY_TWEET_ID, tweet_id);
        bundle.put_string (TweetInfoPage.KEY_SCREEN_NAME, parts[3]);
        window.main_widget.switch_page (Page.TWEET_INFO,
                                        bundle);
        return true;
      }
    }
    return false;
  }


  void work_array (Json.Array   json_array,
                   TweetListBox tweet_list,
                   Account      account) {
    uint n_tweets = json_array.get_length ();
    /* If the request returned no results at all, we don't
       need to do all the later stuff */
    if (n_tweets == 0) {
      return;
    }

    var now = new GLib.DateTime.now_local ();
    for (uint i = 0; i < n_tweets; i++) {
      var tweet = new Cb.Tweet ();
      tweet.load_from_json (json_array.get_element (i), account.id, now);
      if (account.user_counter == null ||
          tweet_list == null ||
          !(tweet_list.get_toplevel () is Gtk.Window))
        break;

      account.user_counter.id_seen (ref tweet.source_tweet.author);
      if (tweet.retweeted_tweet != null)
        account.user_counter.id_seen (ref tweet.retweeted_tweet.author);

      if (account.filter_matches (tweet))
        tweet.set_flag (Cb.TweetState.HIDDEN_FILTERED);

      tweet_list.model.add (tweet);
    }
  }


  public void handle_media_click (Cb.Tweet   t,
                                  MainWindow window,
                                  int        index,
                                  double     px = 0.0,
                                  double     py = 0.0) {
    MediaDialog media_dialog = new MediaDialog (t, index, px, py);
    media_dialog.set_transient_for (window);
    media_dialog.set_modal (true);
    media_dialog.show ();
  }

  public void sort_entities (ref Cb.TextEntity[] entities) {
    /* Just use bubblesort here. Our n is very small (< 15 maybe?) */

    for (int i = 0; i < entities.length; i ++) {
      for (int k = 0; k < entities.length; k ++) {
        if (entities[i].from < entities[k].from) {
          Cb.TextEntity c = entities[i];
          entities[i] = entities[k];
          entities[k] = c;
        }
      }
    }
  }
}
