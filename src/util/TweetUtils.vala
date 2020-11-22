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
  public Quark get_error_domain() {
    return Quark.from_string("tweet-action");
  }
  /**
   * Turns Twitter's JSON error messages into a GLib.Error object, unless
   * the exception was caused by a libsoup error
   *
   * Example JSON:
   * {"errors":[{"message":"Sorry, that page does not exist","code":34}]}
   */
  public GLib.Error failed_request_to_error (Rest.ProxyCall call, GLib.Error e) {
    if (e.code < 100) {
      // Special case for _handle_error_from_message in rest-proxy-call.c
      // All libsoup errors are below the HTTP response code range
      // so return the error and don't bother with the payload
      return e;
    }

    unowned string json = call.get_payload();

    try {
      // TODO: The Utils function used to have the following to handle multiple errors:
      /*
       *   if (errors.get_length () == 1) {
       *     var err = errors.get_object_element (0);
       *     sb.append (err.get_int_member ("code").to_string ()).append (": ")
       *       .append (err.get_string_member ("message"))
       *       .append ("(").append (file).append (":").append (line.to_string ()).append (")");
       *   } else if (errors.get_length () > 1) {
       *     sb.append ("<ul>");
       *     errors.foreach_element ((arr, index, node) => {
       *       var obj = node.get_object ();
       *       sb.append ("<li>").append (obj.get_int_member ("code").to_string ())
       *         .append (": ")
       *         .append (obj.get_string_member ("message")).append ("</li>");
       *     });
       *     sb.append ("</ul>");
       *   }
       */
      var parser = new Json.Parser();
      parser.load_from_data (json);
      var node = parser.get_root();
      if (node == null) {
          return new GLib.Error (get_error_domain(), 0, "Twitter error is not valid JSON: %s", json);
      }
      var obj = node.get_object();
      var errors = obj.get_array_member("errors");
      // Assume there's always at least one, and we just take the first
      var error = errors.get_element(0).get_object();
      // Twitter's error codes don't go above three digits - https://developer.twitter.com/en/docs/basics/response-codes
      var code = (int)error.get_int_member("code");
      var message = error.get_string_member("message");
      return new GLib.Error.literal (get_error_domain(), code, message);
    } catch (GLib.Error e) {
      return e;
    }
  }

  /*
   * Turns a Twitter error code into a translated message for the user, or uses the default message
   * if we haven't seen the code before
   */
  string code_to_message(int code, string default_message){
    // TODO: Remove the magic numbers (including error handling in this class)
    // Codes and default messages taken from https://developer.twitter.com/en/docs/basics/response-codes
    // Some lines commented out to avoid work for the translators for strings we aren't likely to hit
    switch (code) {
      //case 3: return _("Invalid coordinates."); // We don't do locations
      //case 13: return _("No location associated with the specified IP address."); // We don't do locations
      //case 17: return _("No user matches for specified terms."); // We don't use the users/lookup endpoint
      case 32: return _("Could not authenticate you");
      case 34: return _("Sorry, that page does not exist");
      //case 36: return _("You cannot report yourself for spam."); // We don't do spam reports
      //case 38: return _("<named> parameter is missing."); // We should always be constructing valid queries!
      //case 44: return _("attachment_url parameter is invalid"); // We control attachment URLs, so they should be valid
      case 50: return _("User not found.");
      case 63: return _("User has been suspended.");
      case 64: return _("Your account is suspended and is not permitted to access this feature");
      //case 68: return _("The Twitter REST API v1 is no longer active. Please migrate to API v1.1."); // We're never going to go back to v1.0!
      //case 87: return _("Client is not permitted to perform this action."); // We shouldn't have UI for the not permitted tasks
      case 88: return _("Rate limit exceeded");
      case 89: return _("Invalid or expired token"); // 
      //case 93: return _("This application is not allowed to access or delete your direct messages"); // We request the DM permission
      //case 99: return _("Unable to verify your credentials."); // Not relevant to posting
      case 109: return _("The specified user is not a subscriber of this list."); // Not listed in the docs
      case 110: return _("The user you are trying to remove from the list is not a member."); // Not listed in the docs
      case 120: return _("Account update failed: value is too long."); // XXX: This should say how long it can be, and possibly which field ("value")
      case 130: return _("Over capacity");
      case 131: return _("Internal error");
      case 135: return _("Could not authenticate you");
      case 139: return _("You have already favorited this status.");
      case 144: return _("No status found with that ID.");
      case 150: return _("You cannot send messages to users who are not following you.");
      case 151: return _("There was an error sending your message."); // XXX: There should be a reason here
      case 160: return _("You've already requested to follow this user."); // XXX: There should be a username here
      case 161: return _("You are unable to follow more people at this time");
      case 179: return _("Sorry, you are not authorized to see this status");
      case 185: return _("User is over daily status update limit");
      case 186: return _("Tweet needs to be a bit shorter.");
      case 187: return _("Status is a duplicate");
      //case 195: return _("Missing or invalid url parameter"); // We should always be constructing valid queries!
      //case 205: return _("You are over the limit for spam reports."); // We don't do spam reports
      case 214: return _("Owner must allow dms from anyone.");
      case 215: return _("Bad authentication data");
      case 220: return _("Your credentials do not allow access to this resource.");
      case 226: return _("This request looks like it might be automated. To protect our users from spam and other malicious activity, we can’t complete this action right now.");
      case 231: return _("User must verify login");
      case 261: return _("Application cannot perform write actions.");
      case 271: return _("You can’t mute yourself.");
      case 272: return _("You are not muting the specified user.");
      case 323: return _("Animated GIFs are not allowed when uploading multiple images.");
      case 324: return _("The validation of media ids failed.");
      case 325: return _("A media id was not found.");
      case 326: return _("To protect our users from spam and other malicious activity, this account is temporarily locked.");
      case 327: return _("You have already retweeted this Tweet.");
      case 349: return _("You cannot send messages to this user.");
      case 354: return _("The text of your direct message is over the max character limit.");
      case 355: return _("Subscription already exists.");
      case 385: return _("You attempted to reply to a Tweet that is deleted or not visible to you.");
      case 386: return _("The Tweet exceeds the number of allowed attachment types.");
      case 407: return _("The given URL is invalid.");
      case 416: return _("Invalid / suspended application");
      // Experimental "permissions" feature: https://twittercommunity.com/t/our-experiment-with-new-tweet-settings-for-replies/137953
      case 433: return _("The original Tweet author restricted who can reply to this Tweet.");
      // Else fall back to Twitter's (probably English) message
      default: return default_message;
    }
  }

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
    call.add_param ("include_ext_alt_text", "true");
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
        err = failed_request_to_error (call, e);
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
        var tmp_error = failed_request_to_error (call, e);
        if (tmp_error.code != 144) {
          err = tmp_error;
          debug("Delete failed: %d", err.code);
          delete_tweet.callback ();
          return;
        }
      }
      inject_deletion (tweet.id, account);
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
        var tmp_error = failed_request_to_error (call, e);
        // If we can handle it cleanly, pretend it worked
        if ((status && tmp_error.code != 139) // Faving and we didn't get "already Faved"
           ||
            (!status && tmp_error.code != 144)) { // or un-Faving and didn't get "no such status"
          err = tmp_error;
          set_favorite_status.callback ();
          return;
        }
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
      call.set_function (@"1.1/statuses/unretweet/$(tweet.my_retweet).json");
    call.add_param ("tweet_mode", "extended");
    call.add_param ("include_my_retweet", "true");
    call.add_param ("include_ext_alt_text", "true");

    var success = false;
    GLib.Error? err = null;
    call.invoke_async.begin (null, (obj, res) => {
      try{
        call.invoke_async.end (res);
      } catch (GLib.Error e) {
        var tmp_error = failed_request_to_error (call, e);
        // If we can handle it cleanly, pretend it worked
        if ((status && tmp_error.code == 327) // RTing and we got "already RTed"
           ||
            (!status && tmp_error.code == 144)) { // or un-RTing and got "no such status"
            // Note: We don't inject the tweet because we don't have it
            // But we *should* pick it up on the next poll so it will be delayed rather than lost
            debug("Succeeded by %d", tmp_error.code);
            if (status) {
              tweet.set_flag (Cb.TweetState.RETWEETED);
            } else {
              tweet.unset_flag (Cb.TweetState.RETWEETED);
            }
            success = true;
        } else {
          debug("Failed with %d", tmp_error.code);
          err = tmp_error;
        }
        set_retweet_status.callback ();
        return;
      }
      unowned string back = call.get_payload();
      var parser = new Json.Parser ();
      try {
        parser.load_from_data (back);
        string message = back;
        Cb.StreamMessageType message_type;
        if (status) {
          int64 new_id = parser.get_root ().get_object ().get_int_member ("id");
          tweet.my_retweet = new_id;
          tweet.set_flag (Cb.TweetState.RETWEETED);
          message_type = Cb.StreamMessageType.TWEET;
        } else {
          inject_deletion(tweet.my_retweet, account);
          tweet.my_retweet = 0;
          tweet.unset_flag (Cb.TweetState.RETWEETED);
          message_type = Cb.StreamMessageType.RT_DELETE;
        }

        account.user_stream.inject_tweet(message_type, message);
      } catch (GLib.Error e) {
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

  async List<unowned Json.Node> search_for_tweets_json(Account account, string search_query, int64 max_id = -1, int64 since_id = -1, uint count = 35, GLib.Cancellable? cancellable = null) throws GLib.Error {
    var search_call = account.proxy.new_call ();
    search_call.set_function ("1.1/search/tweets.json");
    search_call.set_method ("GET");
    search_call.add_param ("q", search_query);
    if (max_id > 0) {
      search_call.add_param ("max_id", (max_id - 1).to_string ());
    }
    else if (since_id > 0) {
      search_call.add_param ("since_id", since_id.to_string());
    }
    search_call.add_param ("include_entities", "false");
    search_call.add_param ("count", count.to_string());

    List<unowned Json.Node>? statuses = null;
    GLib.Error? err = null;

    Cb.Utils.load_threaded_async.begin (search_call, cancellable, (_, res) => {
      Json.Node? search_root = null;
      try {
        search_root = Cb.Utils.load_threaded_async.end (res);
      } catch (GLib.Error e) {
        err = e;
        search_for_tweets_json.callback();
        return;
      }

      if (search_root == null) {
        search_for_tweets_json.callback();
        return;
      }

      var search_statuses = search_root.get_object().get_array_member("statuses");

      if (search_statuses.get_length() == 0) {
        search_for_tweets_json.callback();
        return;
      }

      string[] ids = {};
      search_statuses.foreach_element ((array, index, node) => {
        ids += node.get_object().get_string_member("id_str");
      });

      var call = account.proxy.new_call ();
      call.set_function ("1.1/statuses/lookup.json");
      call.set_method ("POST");
      call.add_param ("id", string.joinv(",", ids));
      call.add_param ("include_entities", "true");
      call.add_param ("tweet_mode", "extended");
      call.add_param ("include_ext_alt_text", "true");

      Cb.Utils.load_threaded_async.begin (call, cancellable, (_, res) => {
        Json.Node? root = null;
        try {
          root = Cb.Utils.load_threaded_async.end (res);
        } catch (GLib.Error e) {
          err = e;
          search_for_tweets_json.callback();
          return;
        }

        if (root == null) {
          debug ("load tweets: root is null");
          search_for_tweets_json.callback();
          return;
        }

        statuses = root.get_array().get_elements();
        statuses.sort((a, b) => {
          var a_id = a.get_object().get_string_member("id_str");
          var b_id = b.get_object().get_string_member("id_str");
          // Return values in the same order as search/tweets.json - newest first
          return GLib.strcmp (b_id, a_id);
        });
        search_for_tweets_json.callback();
      });
    });
    yield;
    if (err != null) {
      throw err;
    }

    return statuses == null ? new List<unowned Json.Node>() : statuses.copy();
  }

  void set_tweet_hidden_flags(Cb.Tweet t, Account account) {
    if (account.filter_matches (t)) {
      t.set_flag (Cb.TweetState.HIDDEN_FILTERED);
    }
    if (t.retweeted_tweet != null) {
      if (account.is_blocked (t.source_tweet.author.id)) {
        t.set_flag (Cb.TweetState.HIDDEN_RETWEETER_BLOCKED);
      }
      if (account.is_muted (t.source_tweet.author.id)) {
        t.set_flag (Cb.TweetState.HIDDEN_RETWEETER_MUTED);
      }
      if (account.is_blocked (t.retweeted_tweet.author.id)) {
        t.set_flag (Cb.TweetState.HIDDEN_AUTHOR_BLOCKED);
      }
      if (account.is_muted (t.retweeted_tweet.author.id)) {
        t.set_flag (Cb.TweetState.HIDDEN_AUTHOR_MUTED);
      }
      foreach (int64 id in account.disabled_rts) {
        if (id == t.source_tweet.author.id) {
          t.set_flag(Cb.TweetState.HIDDEN_RTS_DISABLED);
          break;
        }
      }
    }
    else {
      if (account.is_blocked (t.source_tweet.author.id)) {
        t.set_flag (Cb.TweetState.HIDDEN_AUTHOR_BLOCKED);
      }
      if (account.is_muted (t.source_tweet.author.id)) {
        t.set_flag (Cb.TweetState.HIDDEN_AUTHOR_MUTED);
      }
    }
  }

  async Cb.Tweet[] search_for_tweets(Account account, string search_query, int64 max_id = -1, int64 since_id = -1, uint count = 35, GLib.Cancellable? cancellable = null) throws GLib.Error {
    var statuses = yield search_for_tweets_json(account, search_query, max_id, since_id, count, cancellable);
    Cb.Tweet[] tweets = {};
    var now = new GLib.DateTime.now_local ();

    statuses.foreach ((node) => {
      var tweet = new Cb.Tweet ();
      tweet.load_from_json (node, account.id, now);
      set_tweet_hidden_flags(tweet, account);
      tweets += tweet;
    });

    return tweets;
  }

  private void inject_deletion (int64 id, Account account) {
    var message = @"{ \"delete\":{ \"status\":{ \"id\":$(id), \"id_str\":\"$(id)\", \"user_id\":$(account.id), \"user_id_str\":\"$(account.id)\" } } }";
    account.user_stream.inject_tweet(Cb.StreamMessageType.DELETE, message);
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

      set_tweet_hidden_flags(tweet, account);

      tweet_list.model.add (tweet);
    }
  }


  public void handle_media_click (Cb.Media[] media,
                                  MainWindow window,
                                  int        index) {
    Gdk.Display default_display = Gdk.Display.get_default();
    Gdk.Monitor current_monitor = default_display.get_monitor_at_window(window.get_window());
    Gdk.Rectangle workarea = current_monitor.get_workarea();
    Gdk.Rectangle max_dimensions = { 0, 0, (int)Math.round(workarea.width * 0.95), (int)Math.round(workarea.height * 0.95) };
    MediaDialog media_dialog = new MediaDialog (media, index, max_dimensions);
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

  public void log_tweet (Cb.Tweet tweet) {
#if DEBUG
    stdout.printf (tweet.json_data+"\n");
#endif
    message ("Seen      : %s", tweet.get_seen ().to_string ());
    message ("My retweet: %s", tweet.my_retweet.to_string ());
    message ("Retweeted: %s", tweet.is_flag_set (Cb.TweetState.RETWEETED).to_string ());
    message ("Favorited: %s", tweet.is_flag_set (Cb.TweetState.FAVORITED).to_string ());
    message ("Protected: %s", tweet.is_flag_set (Cb.TweetState.PROTECTED).to_string ());
    message ("State    : %s", tweet.state.to_string ());
    message ("Source tweet author id: %s", tweet.source_tweet.author.id.to_string ());
    message ("Source tweet author screen_name: %s", tweet.source_tweet.author.screen_name);
    if (tweet.retweeted_tweet != null) {
      message ("Retweet!");
      message ("Retweet author id: %s", tweet.retweeted_tweet.author.id.to_string ());
      message ("Retweet author screen_name: %s", tweet.retweeted_tweet.author.screen_name);
    }
    if (tweet.has_inline_media ()) {
      foreach (Cb.Media m in tweet.get_medias ()) {
        message ("Media: %p", m);
      }
    }
  }
}
