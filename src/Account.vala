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

public class Account : GLib.Object {
  public int64 id;
  public int64 migration_date;
  public bool suppress_dm_notifications;
  public bool suppress_mention_notifications;
  public Sql.Database db;
  public string screen_name;
  public string name;
  public string avatar_url;
  public string? banner_url;
  public string? website;
  public string? description;
  public Cairo.Surface avatar_small {public get; public set;}
  public Cairo.Surface avatar       {public get; public set;}
  public Rest.OAuthProxy proxy;
  public Cb.UserStream user_stream;
  public Cb.UserCounter user_counter;
  private UserEventReceiver event_receiver;
  public NotificationManager notifications;
  public int64[] friends;
  public int64[] blocked;
  public int64[] muted;
  public int64[] disabled_rts;
  public GLib.GenericArray<Cb.Filter> filters;
  private bool proxy_load_fallback = false;
  public signal void info_changed (string screen_name, string name,
                                   Cairo.Surface avatar_small, Cairo.Surface avatar);

  public Account (int64 id, string screen_name, string name) {
    this.id = id;
    this.screen_name = screen_name;
    this.name = name;
    this.migration_date = -1;
    this.filters = new GLib.GenericArray<Cb.Filter> ();
    this.event_receiver = new UserEventReceiver (this);
    this.notifications = new NotificationManager (this);
  }

  /**
   * Initializes the database. All account databases are VersionedDatabases
   * and are stored in accounts/ID.db.
   *
   */
  public void init_database () {
    if (db != null)
      return;

    this.db = new Sql.Database (Dirs.config (@"accounts/$id.db"),
                                Sql.ACCOUNTS_INIT_FILE,
                                Sql.ACCOUNTS_SQL_VERSION);
    user_counter = new Cb.UserCounter ();
    this.load_filters ();

    if (this.migration_date < 0 && Cawbird.db != null) {
      this.migration_date = Cawbird.db.select ("accounts") .cols ("migrated") .where_eqi ("id", this.id) .once_i64 ();
    }

    if (this.migration_date == 0) {
      this.migrate_from_corebird ();
    }
  }

  /**
   * Initializes the RestProxy object with loaded secrets.
   */
  public void init_proxy () {
    if (proxy != null)
      return;

    var proxy_values = get_proxy_values();

    if (proxy_values.length != 4) {
      critical ("Could not load token{_secret} for user %s", this.screen_name);
    }

    create_proxy(proxy_values[0], proxy_values[1], proxy_values[2], proxy_values[3]);

    this.user_stream = new Cb.UserStream (this.screen_name, proxy);
    this.user_stream.register (this.event_receiver);
  }

  public string[] get_proxy_values() {
    var proxy_values = new string[0];
    init_database ();
    Cawbird.db.select ("accounts").cols ("consumer_key", "consumer_secret", "token", "token_secret")
                                  .where_eqi ("id", id)
                                  .run ((vals) => {
      proxy_values = vals;
      return false; //stop
    });

    if (proxy_values[0] == null) {
      this.proxy_load_fallback = true;
      db.select ("common").cols ("token", "token_secret")
                                    .run((vals) => {
        proxy_values = { Settings.get_consumer_key (Cawbird.old_consumer_k),
                         Settings.get_consumer_secret (Cawbird.old_consumer_s),
                         vals[0], vals[1] };
        return false; // stop
      });
    }
    return proxy_values;
  }

  private void create_proxy(string consumer_key, string consumer_secret, string token, string token_secret){
    proxy = new Rest.OAuthProxy (consumer_key, consumer_secret, "https://api.twitter.com/", false);
    proxy.token = token;
    proxy.token_secret = token_secret;
  }

  public void uninit () {
    this.proxy = null;
    this.user_counter.save (this.db.get_sqlite_db ());
    this.user_stream.unregister (this.event_receiver);
    this.user_stream.stop ();
    this.user_stream = null;
  }

  /**
   * Loads the small and normally sized avatars from disk.
   * Normal: accounts/ID.png
   * Small:  accounts/ID_small.png
   */
  public void load_avatar () {
    string path = Dirs.config (@"accounts/$(id).png");
    string small_path = Dirs.config (@"accounts/$(id)_small.png");

    if (!GLib.FileUtils.test (path, GLib.FileTest.EXISTS) ||
        !GLib.FileUtils.test (small_path,  GLib.FileTest.EXISTS)) {
      update_avatar.begin(this.avatar_url, () => {
        this.avatar       = load_surface (path);
        this.avatar_small = load_surface (small_path);
        info_changed (screen_name, name, avatar, avatar_small);
      });
    }
    else {
      this.avatar       = load_surface (path);
      this.avatar_small = load_surface (small_path);
      info_changed (screen_name, name, avatar, avatar_small);
    }
  }

  public void set_new_avatar (Cairo.Surface new_avatar) {
    string path       = Dirs.config (@"accounts/$(id).png");
    string small_path = Dirs.config (@"accounts/$(id)_small.png");


    Cairo.Surface avatar = scale_surface ((Cairo.ImageSurface)new_avatar, 48, 48);
    Cairo.Surface avatar_small = scale_surface ((Cairo.ImageSurface)new_avatar, 24, 24);


    write_surface (avatar, path);
    write_surface (avatar_small, small_path);

    this.avatar = avatar;
    this.avatar_small = avatar_small;
  }

  /**
   * Download the appropriate user info from the Twitter server,
   * updating the local information stored in this class' local variables
   * and the information stored in the account's database file.
   *
   * @param screen_name The screen name to use for the API call or null in
   *                    which case the ID will be used.
   */
  public async void query_user_info () {
    UserInfo user_info;
    try {
      user_info = yield Twitter.get().get_own_user_info(proxy);
    } catch (GLib.Error e) {
      warning (e.message);
      return;
    }

    bool values_changed = false;

    this.id = user_info.id;
    if (this.name != user_info.name) {
      this.name = user_info.name;
      values_changed = true;
    }
    if (this.screen_name != user_info.screen_name) {
      string old_screen_name = this.screen_name;
      this.screen_name = user_info.screen_name;
      Utils.update_startup_account (old_screen_name, this.screen_name);
      values_changed = true;
    }

    this.description = user_info.description;


    this.banner_url = user_info.banner_url;

    /* Website URL */
    this.website = user_info.website;


    string avatar_url = user_info.avatar_url;
    values_changed |= yield update_avatar (avatar_url);

    if (values_changed || proxy_load_fallback) {
      proxy_load_fallback = false;
      if (this.db != null)
        this.save_info ();

      info_changed (this.screen_name,
                    this.name,
                    this.avatar_small,
                    this.avatar);
    }
  }

  public async void init_information () {
    var collect_obj = new Collect (4);
    collect_obj.finished.connect (() => {
      init_information.callback ();
    });

    query_user_info.begin (() => {
      collect_obj.emit ();
    });

    load_id_array.begin (collect_obj, "1.1/friendships/no_retweets/ids.json", true, (obj, res) => {
      Json.Array? arr = load_id_array.end (res);
      if (arr != null) {
        this.set_disabled_rts (arr);
        collect_obj.emit ();
      }
    });
    load_id_array.begin (collect_obj, "1.1/blocks/ids.json", false, (obj, res) => {
      Json.Array? arr = load_id_array.end (res);
      if (arr != null) {
        this.set_blocked (arr);
        collect_obj.emit ();
      }
    });
    load_id_array.begin (collect_obj, "1.1/mutes/users/ids.json", false, (obj, res) => {
      Json.Array? arr = load_id_array.end (res);
      if (arr != null) {
        this.set_muted (arr);
        collect_obj.emit ();
      }
    });

    yield;
  }

  private async Json.Array? load_id_array (Collect collect_obj,
                                           string  function,
                                           bool    direct) {
    var call = this.proxy.new_call ();
    call.set_function (function);
    call.set_method ("GET");

    Json.Node? root = null;
    try {
      root = yield Cb.Utils.load_threaded_async (call, null);
    } catch (GLib.Error e) {
      warning (e.message);
      collect_obj.emit ();
      return null;
    }

    if (direct)
      return root.get_array ();
    else
      return root.get_object ().get_array_member ("ids");
  }

  /**
   * Updates the account's avatar picture.
   * This means that the new avatar will be downloaded if necessary and
   * scaled appropriately.
   *
   * @param url The url of the (possibly) new avatar(optional).
   */
  private async bool update_avatar (string url = "") {
    string dest_path = Dirs.config (@"accounts/$(id)_small.png");
    string big_dest  = Dirs.config (@"accounts/$(id).png");



    if (url.length > 0 && url == this.avatar_url) {
      if (GLib.FileUtils.test (dest_path, GLib.FileTest.EXISTS) &&
          GLib.FileUtils.test (big_dest,  GLib.FileTest.EXISTS))
      return false;
    }

    debug ("Using %s to update the avatar(old: %s)", url, this.avatar_url);

    if (url.length > 0) {
      var msg = new Soup.Message ("GET", url);
      SOUP_SESSION.queue_message (msg, (_s, _msg) => {
        var data_stream = new MemoryInputStream.from_data (msg.response_body.data, GLib.g_free);
        string type = Cb.Utils.get_file_type (url);
        Gdk.Pixbuf pixbuf;
        try {
          pixbuf = new Gdk.Pixbuf.from_stream(data_stream);
          pixbuf.save(big_dest, type);
          data_stream.close ();
          double scale_x = 24.0 / pixbuf.get_width();
          double scale_y = 24.0 / pixbuf.get_height();
          var scaled_pixbuf = new Gdk.Pixbuf(Gdk.Colorspace.RGB,
                                             pixbuf.has_alpha, 8, 24, 24);
          pixbuf.scale(scaled_pixbuf, 0, 0, 24, 24, 0, 0, scale_x, scale_y, Gdk.InterpType.HYPER);
          scaled_pixbuf.save(dest_path, type);
          debug ("saving to %s", dest_path);
          this.avatar_small = Gdk.cairo_surface_create_from_pixbuf (scaled_pixbuf, 1, null);
          this.avatar = Gdk.cairo_surface_create_from_pixbuf (pixbuf, 1, null);
        } catch (GLib.Error e) {
          critical (e.message);
        }
        this.avatar_url = url;
        Cawbird.db.update ("accounts").val ("avatar_url", url).where_eqi ("id", id).run ();
        update_avatar.callback ();
      });
      yield;
      return true;
    } else {
      critical ("Not implemented yet");
    }

    return false;
  }

  /**
   * Saves the account info both in the account's database and in the
   * global one.
   */
  public void save_info () {
    db.replace ("info").vali64 ("id", id)
                       .val ("screen_name", screen_name)
                       .val ("name", name)
                       .run ();
    Cawbird.db.replace ("accounts").vali64 ("id", id)
                                    .val ("screen_name", screen_name)
                                    .val ("name", name)
                                    .val ("avatar_url", avatar_url)
                                    .val ("consumer_key", proxy.consumer_key)
                                    .val ("consumer_secret", proxy.consumer_secret)
                                    .val ("token", proxy.token)
                                    .val ("token_secret", proxy.token_secret)
                                    .run ();
  }

  /**
   * Load all the filters from the database.
   */
  private void load_filters () {
    this.db.select ("filters").cols ("content", "id")
              .order ("id").run ((cols) => {
      Cb.Filter f = new Cb.Filter (cols[0]);
      f.set_id (int.parse (cols[1]));
      filters.add (f);
      return true;
    });
  }

  public void add_filter (owned Cb.Filter f) {
    this.filters.add (f);
  }

  public bool disabled_rts_for (int64 user_id) {
    foreach (int64 id in disabled_rts) {
      if (id == user_id) {
        return true;
      }
    }
    return false;
  }

  /**
   * Checks if any of the filters associated to this acount match
   * the given tweet.
   *
   * @param t The tweet to check for
   *
   * @return true iff at least one of the filters match, false otherwise.
   */
  public bool filter_matches (Cb.Tweet t) {
    if (t.source_tweet.author.id == this.id)
      return false;

    string text = t.get_filter_text ();
    for (int i = 0; i < filters.length; i ++) {
      var f = this.filters.get (i);
      if (f.matches (text)) {
        return true;
      }
    }
    return false;
  }

  public void set_friends (Json.Array friends_array) {
    this.friends = new int64[friends_array.get_length ()];
    debug ("Adding %d friends...", friends.length);
    for (int i = 0; i < friends_array.get_length (); i ++) {
      this.friends[i] = friends_array.get_int_element (i);
    }
  }

  public bool follows_id (int64 user_id) {
    foreach (int64 id in this.friends)
      if (id == user_id)
        return true;

    return false;
  }

  public void follow_id (int64 user_id) {
    this.friends.resize (this.friends.length + 1);
    this.friends[this.friends.length - 1] = user_id;
  }

  public void unfollow_id (int64 user_id) {
    if (this.friends == null || this.friends.length == 0) {
      warning ("friends == null");
      return;
    }

    int64[] new_friends = new int64[this.friends.length];

    int o = 0;
    bool found = false;
    for (int i = 0; i < this.friends.length; i++) {
      if (this.friends[i] == user_id) {
        found = true;
        continue;
      }
      new_friends[o] = this.friends[i];
      o ++;
    }
    if (found)
      new_friends.resize (new_friends.length - 1);
    this.friends = new_friends;
  }

  public void set_muted (Json.Array muted_array) {
    this.muted = new int64[muted_array.get_length ()];
    debug ("Add %d muted ids", this.muted.length);
    for (int i = 0; i < this.muted.length; i ++) {
      this.muted[i] = muted_array.get_int_element (i);
    }
  }

  public void mute_id (int64 id) {
    this.muted.resize (this.muted.length + 1);
    this.muted[this.muted.length - 1] = id;
  }

  public void unmute_id (int64 id) {
    if (this.muted == null || this.muted.length == 0) {
      warning ("muted == null");
      return;
    }
    int64[] new_muted = new int64[this.muted.length - 1];

    int o = 0;
    for (int i = 0; i < this.muted.length; i++) {
      if (this.muted[i] == id) {
        continue;
      }
      new_muted[o] = this.muted[i];
      o ++;
    }
    this.muted = new_muted;
  }

  public void set_blocked (Json.Array blocked_array) {
    this.blocked = new int64[blocked_array.get_length ()];
    debug ("Add %d blocked ids", this.blocked.length);
    for (int i = 0; i < this.blocked.length; i ++) {
      this.blocked[i] = blocked_array.get_int_element (i);
    }
  }

  public void block_id (int64 id) {
    this.blocked.resize (this.blocked.length + 1);
    this.blocked[this.blocked.length - 1] = id;
  }

  public void unblock_id (int64 id) {
    if (this.blocked == null || this.blocked.length == 0) {
      warning ("blocked == null");
      return;
    }
    int64[] new_blocked = new int64[this.blocked.length - 1];

    int o = 0;
    for (int i = 0; i < this.blocked.length; i++) {
      if (this.blocked[i] == id) {
        continue;
      }
      new_blocked[o] = this.blocked[i];
      o ++;
    }
    this.blocked = new_blocked;
  }

  public void set_disabled_rts (Json.Array disabled_rts_array) {
    this.disabled_rts = new int64[disabled_rts_array.get_length ()];
    debug ("Add %d disabled_rts ids", this.disabled_rts.length);
    for (int i = 0; i < this.disabled_rts.length; i ++) {
      this.disabled_rts[i] = disabled_rts_array.get_int_element (i);
    }
  }

  public void add_disabled_rts_id (int64 user_id) {
    this.disabled_rts.resize (this.disabled_rts.length + 1);
    this.disabled_rts[this.disabled_rts.length - 1] = user_id;
  }

  public void remove_disabled_rts_id (int64 user_id) {
    if (this.disabled_rts == null || this.disabled_rts.length == 0) {
      warning ("disabled_rts == null");
      return;
    }
    int64[] new_disabled_rts = new int64[this.disabled_rts.length - 1];

    int o = 0;
    for (int i = 0; i < this.disabled_rts.length; i++) {
      if (this.disabled_rts[i] == user_id) {
        continue;
      }
      new_disabled_rts[o] = this.disabled_rts[i];
      o ++;
    }
    this.disabled_rts = new_disabled_rts;
  }

  public bool blocked_or_muted (int64 user_id) {
    foreach (int64 id in this.muted)
      if (id == user_id)
        return true;

    foreach (int64 id in this.blocked)
      if (id == user_id)
        return true;

    return false;
  }

  public bool is_blocked (int64 user_id) {
    foreach (int64 id in this.blocked)
      if (id == user_id)
        return true;

    return false;
  }

  public bool is_muted (int64 user_id) {
    foreach (int64 id in this.muted)
      if (id == user_id)
        return true;

    return false;
  }

  private void migrate_from_corebird () {
    var corebird_db_path = Dirs.corebird_config (@"accounts/$id.db");

    if (GLib.FileUtils.test (corebird_db_path, GLib.FileTest.EXISTS)) {
      var corebird_db = new Sql.Database (corebird_db_path, "", 1); // Use version 1 to prevent updating

      // Migrate DM history - they're unique by ID
      // But avatar URLs can be (always are?) null so we need to null-coallesce them
      corebird_db.select ("dm_threads").cols ("user_id", "name", "screen_name", "last_message", "last_message_id", "avatar_url").run ((vals) => {
        this.db.insert_ignore ("dm_threads").vali64 ("user_id", int64.parse(vals[0]))
                                            .val ("name", vals[1])
                                            .val ("screen_name", vals[2])
                                            .val ("last_message", vals[3])
                                            .vali64 ("last_message_id", int64.parse(vals[4]))
                                            .val ("avatar_url", vals[5] ?? "")
                                            .run ();
        return true;
      });
      corebird_db.select ("dms").cols ("from_id", "to_id", "from_screen_name", "to_screen_name", "from_name", "to_name", "timestamp", "avatar_url", "id", "text").run ((vals) => {
        this.db.insert_ignore ("dms").vali64 ("from_id", int64.parse(vals[0]))
                                     .vali64 ("to_id", int64.parse(vals[1]))
                                     .val ("from_screen_name", vals[2])
                                     .val ("to_screen_name", vals[3])
                                     .val ("from_name", vals[4])
                                     .val ("to_name", vals[5])
                                     .vali ("timestamp", int.parse(vals[6]))
                                     .val ("avatar_url", vals[7] ?? "")
                                     .vali64 ("id", int64.parse(vals[8]))
                                     .val ("text", vals[9])
                                     .run ();
        return true;
      });

      // Filter IDs could change if people made new ones, so we just work with content
      corebird_db.select ("filters").cols ("content").run ((vals) => {
        var filter_match_count = this.db.select ("filters") .count ("id") .where_eq ("content", vals[0]).once_i64 ();

        if (filter_match_count == 0) {
          Utils.create_persistent_filter (vals[0], this);
        }
        //Else the user put the filter back already

        return true;
      });

      // Common is common and pre-populated
      // Info is account info, which is pre-populated
      // User_cache can be rebuilt
    }
    // Else no Corebird account to migrate

    // Set the migrated value so that we don't try again
    Cawbird.db.update ("accounts").vali64 ("migrated", GLib.get_real_time ()).where_eqi ("id", this.id).run ();
  }

  // Notification suppression is used for first creation so that users don't get swamped
  // with notifications. Unsurpressing is done in two parts because we fetch notifications
  // and DMs separately and so one can be finished before the other.
  public void suppress_notifications() {
    this.suppress_dm_notifications = true;
    this.suppress_mention_notifications = true;
  }

  public void unsuppress_dm_notifications() {
    this.suppress_dm_notifications = false;
  }

  public void unsuppress_mention_notifications() {
    this.suppress_mention_notifications = false;
  }

  /** Static stuff ********************************************************************/
  private static GLib.GenericArray<Account>? accounts = null;

  public static Account get_nth (uint index) {
    if (GLib.unlikely (accounts == null))
      lookup_accounts ();

    return accounts.get (index);
  }

  public static uint get_n () {
    if (GLib.unlikely (accounts == null))
      lookup_accounts ();

    return accounts.length;
  }

  public static void update_api_details(int64 id, Rest.OAuthProxy proxy) {
    Cawbird.db.update ("accounts").val ("consumer_key", proxy.consumer_key)
                                  .val ("consumer_secret", proxy.consumer_secret)
                                  .val ("token", proxy.token)
                                  .val ("token_secret", proxy.token_secret)
                                  .where_eqi ("id", id)
                                  .run ();
  }

  private static Account construct_from_details(int64 id, string screen_name, string name, string avatar_url, int64 migrated) {
    Account acc = new Account(id, screen_name, name);
    acc.avatar_url = avatar_url;
    acc.load_avatar();
    acc.migration_date = migrated;
    return acc;
  }

  public static Account create_account (UserInfo user_info, Rest.OAuthProxy proxy) {
    var migrated = GLib.get_real_time ();
    Cawbird.db.insert ("accounts").vali64 ("id", user_info.id)
                                    .val ("screen_name", user_info.screen_name)
                                    .val ("name", user_info.name)
                                    .val ("avatar_url", user_info.avatar_url)
                                    .val ("consumer_key", proxy.consumer_key)
                                    .val ("consumer_secret", proxy.consumer_secret)
                                    .val ("token", proxy.token)
                                    .val ("token_secret", proxy.token_secret)
                                    .vali64 ("migrated", migrated)
                                    .run ();
    Account acc = construct_from_details (user_info.id, user_info.screen_name, user_info.name, user_info.avatar_url, migrated);
    Account.add_account(acc);
    return acc;
  }

  /**
   * Look up the accounts. Each account has a <id>.db in ~/.config/cawbird/accounts/
   * The accounts are initialized with only their screen_name and their ID.
   */
  private static void lookup_accounts () {
    assert (accounts == null);
    accounts = new GLib.GenericArray<Account> ();
    Cawbird.db.select ("accounts").cols ("id", "screen_name", "name", "avatar_url", "migrated").run ((vals) => {
      Account acc = construct_from_details (int64.parse(vals[0]), vals[1], vals[2], vals[3], int64.parse(vals[4]));
      accounts.add (acc);
      return true;
    });
  }

  /**
   * Adds the given account to the end of the current account list.
   *
   * @param acc The account to add.
   */
  public static void add_account (Account acc) {
    accounts.add (acc);
  }

  /**
   * Removes the acccunt with th given screen name from the account list.
   *
   * @param screen_name The screen name of the account to remove.
   */
  public static void remove_account (string screen_name) {
    if (GLib.unlikely (accounts == null))
      lookup_accounts ();

    for (uint i = 0; i < accounts.length; i ++) {
      var a = accounts.get (i);
      if (a.screen_name == screen_name) {
        accounts.remove (a);
        return;
      }
    }
  }

  /**
   * Returns an unowned reference to the account with the given screen name.
   *
   * @param screen_name The screen name of the account to return
   * @return An unowned reference to the account object with the given screen name or
   *         null of no such instance could be found.
   */
  public static unowned Account? query_account (string screen_name) {
    if (GLib.unlikely (accounts == null))
      lookup_accounts ();

    var lower_screen_name = screen_name.down();

    for (uint i = 0; i < accounts.length; i ++) {
      unowned Account a = accounts.get (i);

      var acct_screen_name = a.screen_name.down();

      if (lower_screen_name == acct_screen_name ||
          lower_screen_name == "@" + acct_screen_name)
        return a;
    }
    return null;
  }

  public static unowned Account? query_account_by_id (int64 id) {
    if (GLib.unlikely (accounts == null))
      lookup_accounts ();

    for (uint i = 0; i < accounts.length; i ++) {
      unowned Account a = accounts.get (i);
      if (id == a.id)
        return a;
    }
    return null;
  }
}
