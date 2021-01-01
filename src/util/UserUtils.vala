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

const uint FRIENDSHIP_FOLLOWED_BY   = 1 << 0;
const uint FRIENDSHIP_FOLLOWING     = 1 << 1;
const uint FRIENDSHIP_WANT_RETWEETS = 1 << 2;
const uint FRIENDSHIP_BLOCKING      = 1 << 3;
const uint FRIENDSHIP_MUTING        = 1 << 4;
const uint FRIENDSHIP_CAN_DM        = 1 << 5;

struct JsonCursor {
  int64 next_cursor;
  bool full;
  Json.Node? json_object;
}


namespace UserUtils {
  async uint load_friendship (Account account,
                              int64   user_id,
                              string  screen_name)
  {
    var call = account.proxy.new_call ();
    call.set_function ("1.1/friendships/show.json");
    call.set_method ("GET");
    call.add_param ("source_id", account.id.to_string ());

    if (user_id != 0)
      call.add_param ("target_id", user_id.to_string ());
    else
      call.add_param ("target_screen_name", screen_name);


    Json.Node? root = null;
    try {
      root = yield Cb.Utils.load_threaded_async (call, null);
    } catch (GLib.Error e) {
      warning (e.message);
      return 0;
    }

    var relationship = root.get_object ().get_object_member ("relationship");
    var target = relationship.get_object_member ("target");
    var source = relationship.get_object_member ("source");

    uint friendship = 0;

    if (target.get_boolean_member ("following"))
      friendship |= FRIENDSHIP_FOLLOWED_BY;

    if (target.get_boolean_member ("followed_by"))
      friendship |= FRIENDSHIP_FOLLOWING;

    if (source.get_boolean_member ("want_retweets"))
      friendship |= FRIENDSHIP_WANT_RETWEETS;

    if (source.get_boolean_member ("blocking"))
      friendship |= FRIENDSHIP_BLOCKING;
    
    if (source.get_boolean_member ("muting"))
      friendship |= FRIENDSHIP_MUTING;

    if (source.get_boolean_member ("can_dm"))
      friendship |= FRIENDSHIP_CAN_DM;

    return friendship;
  }

  async JsonCursor? load_followers (Account account,
                                int64   user_id,
                                JsonCursor? old_cursor)
  {
    const int requested = 25;
    var call = account.proxy.new_call ();
    call.set_function ("1.1/followers/list.json");
    call.set_method ("GET");
    call.add_param ("user_id", user_id.to_string ());
    call.add_param ("count", requested.to_string ());
    call.add_param ("skip_status", "true");
    call.add_param ("include_user_entities", "false");

    if (old_cursor != null)
      call.add_param ("cursor", old_cursor.next_cursor.to_string ());

    Json.Node? root = null;
    try {
      root = yield Cb.Utils.load_threaded_async (call, null);
    } catch (GLib.Error e) {
      warning (e.message);
      return null;
    }

    var root_obj = root.get_object ();

    var user_array = root_obj.get_array_member ("users");

    JsonCursor cursor = JsonCursor ();
    cursor.next_cursor = root_obj.get_int_member ("next_cursor");
    cursor.full = (user_array.get_length () < requested);
    cursor.json_object = root_obj.get_member ("users");

    return cursor;
  }

  async JsonCursor? load_following (Account account,
                                int64   user_id,
                                JsonCursor? old_cursor)
  {
    const int requested = 25;
    var call = account.proxy.new_call ();
    call.set_function ("1.1/friends/list.json");
    call.set_method ("GET");
    call.add_param ("user_id", user_id.to_string ());
    call.add_param ("count", requested.to_string ());
    call.add_param ("skip_status", "true");
    call.add_param ("include_user_entities", "false");

    if (old_cursor != null)
      call.add_param ("cursor", old_cursor.next_cursor.to_string ());

    Json.Node? root = null;
    try {
      root = yield Cb.Utils.load_threaded_async (call, null);
    } catch (GLib.Error e) {
      warning (e.message);
      return null;
    }

    var root_obj = root.get_object ();

    var user_array = root_obj.get_array_member ("users");

    JsonCursor cursor = JsonCursor ();
    cursor.next_cursor = root_obj.get_int_member ("next_cursor");
    cursor.full = (user_array.get_length () < requested);
    cursor.json_object = root_obj.get_member ("users");

    return cursor;
  }

  async void mute_user (Account account,
                        int64   to_block,
                        bool    setting) throws GLib.Error {
    var call = account.proxy.new_call ();
    call.set_method ("POST");
    if (setting) {
      call.set_function ("1.1/mutes/users/create.json");
      call.add_param ("include_entities", "false");
      call.add_param ("skip_status", "true");
    } else {
      call.set_function ("1.1/mutes/users/destroy.json");
    }

    call.add_param ("user_id", to_block.to_string ());
    GLib.Error? err = null;
    
    call.invoke_async.begin (null, (obj, res) => {
      try {
        call.invoke_async.end (res);
        if (setting) {
          TweetUtils.inject_user_mute(call.get_payload(), account);
        }
        else {
          TweetUtils.inject_user_unmute(call.get_payload(), account);
        }
      } catch (GLib.Error e) {
        var tmp_err = TweetUtils.failed_request_to_error (call, e);

        // Muting muted users fails silently, so errors are important, but code 272 means
        // we unmuted someone who was already unmuted
        if (setting || tmp_err.domain != TweetUtils.get_error_domain() || tmp_err.code != 272) {
          err = tmp_err;
        }
      }
      mute_user.callback();
    });
    yield;
    if (err != null) {
      throw err;
    }
  }

  async void block_user (Account account,
                        int64   to_block,
                        bool    setting) throws GLib.Error {
    var call = account.proxy.new_call ();
    call.set_method ("POST");
    if (setting) {
      call.set_function ("1.1/blocks/create.json");
    } else {
      call.set_function ("1.1/blocks/destroy.json");
    }

    call.add_param ("user_id", to_block.to_string ());
    call.add_param ("include_entities", "false");
    call.add_param ("skip_status", "true");
    GLib.Error? err = null;
    
    call.invoke_async.begin (null, (obj, res) => {
      try {
        call.invoke_async.end (res);
        if (setting) {
          TweetUtils.inject_user_block(call.get_payload(), account);
        }
        else {
          TweetUtils.inject_user_unblock(call.get_payload(), account);
        }
      } catch (GLib.Error e) {
        var tmp_err = TweetUtils.failed_request_to_error (call, e);
        debug("Error: %s", tmp_err.message);

        // Muting muted users fails silently, so errors are important, but code 272 means
        // we unmuted someone who was already unmuted
        if (setting || tmp_err.domain != TweetUtils.get_error_domain() || tmp_err.code != 272) {
          err = tmp_err;
        }
      }
      block_user.callback();
    });
    yield;
    if (err != null) {
      throw err;
    }
  }
}