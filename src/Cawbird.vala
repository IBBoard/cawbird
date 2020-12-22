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

bool STRESSTEST = false;

public class Cawbird : Gtk.Application {
  public static int RESPONSIVE_LIMIT = 440;
  public static Sql.Database db;
  public static Cb.SnippetManager snippet_manager;
  public signal void account_added (Account acc);
  public signal void account_removed (Account acc);
  public signal void account_window_changed (int64? old_id, int64 new_id);

  private SettingsDialog? settings_dialog = null;
  private GLib.GenericArray<Account> active_accounts;
  private bool started_as_service = false;

  const GLib.ActionEntry[] app_entries = {
    {"show-settings",     show_settings_activated          },
    {"show-shortcuts",    show_shortcuts_activated         },
    {"quit",              quit_application                 },
    {"show-about-dialog", about_activated                  },
    {"show-dm-thread",    show_dm_thread,           "(xx)" },
    {"show-window",       show_window,              "x"    },
    {"mark-read",         mark_read_activated,      "(xx)" },
    {"reply-to-tweet",    reply_to_tweet_activated, "(xx)" },
#if DEBUG
    {"post-json",         post_json,                "(ss)" },
#endif
  };



  public Cawbird () {
    GLib.Object(application_id:   "uk.co.ibboard.cawbird");
    active_accounts = new GLib.GenericArray<Account> ();

    /* Create the directories here already since the database below needs it */
    Dirs.create_dirs ();
    db = new Sql.Database (Dirs.config ("Cawbird.db"),
                           Sql.CAWBIRD_INIT_FILE,
                           Sql.CAWBIRD_SQL_VERSION);

    var migrations = db.select ("info") .count ("key") .where_eq ("key", "migration").once_i64 ();

    if (migrations == 0) {
      var corebird_db_path = Dirs.corebird_config (@"Corebird.db");

      if (GLib.FileUtils.test (corebird_db_path, GLib.FileTest.EXISTS)) {
        var corebird_db = new Sql.Database (corebird_db_path, "", 1); // Use version 1 to prevent updating

        // Snippet IDs could change if people made new ones, so we just work with content
        corebird_db.select ("snippets").cols ("key", "value").run ((vals) => {
          var snippet_match_count = db.select ("snippets").count ("id").where_eq ("key", vals[0]).once_i64 ();

          if (snippet_match_count == 0) {
            db.insert ("snippets") .val ("key", vals[0]).val ("value", vals[1]). run();
          }
          //Else the user recreated the snippet already

          return true;
        });
      }

      db.insert_ignore ("info").val ("key", "migration").val ("value", GLib.get_real_time ().to_string ()).run ();
    }
    try {
      var favourites_path = Dirs.config ("image-favorites/");
      var favourites_dir = GLib.Dir.open (favourites_path);
      var has_favs = false;
      string? name = null;

      while ((name = favourites_dir.read_name ()) != null) {
        has_favs = true;
        break;
      }

      if (!has_favs) {
        // No current favourites - transfer any old ones
        var corebird_favourites_path = Dirs.corebird_config ("image-favorites/");
        
        if (GLib.FileUtils.test (corebird_favourites_path, GLib.FileTest.EXISTS)) {
          var corebird_favourites_dir = GLib.Dir.open (corebird_favourites_path);
          
          while ((name = corebird_favourites_dir.read_name ()) != null) {
            GLib.File old_file = File.new_for_path (Path.build_filename (corebird_favourites_path, name));
            GLib.File new_file = File.new_for_path (Path.build_filename (favourites_path, name));
            try {
              debug ("Transferring favourite image %s to %s", old_file.get_path(), new_file.get_path());
              old_file.copy(new_file, 0, null, null);
            } catch (Error e) {
              warning ("Error: %s\n", e.message);
            }
          }
        }
      }
    } catch (GLib.FileError e) {
      error ("Error: %s", e.message);
    }

    snippet_manager = new Cb.SnippetManager (db.get_sqlite_db ());

    OptionEntry[] options = new OptionEntry[7];
    // TRANSLATORS: Description of the `--tweet` option for the command-line
    options[0] = {"tweet", 't', 0, OptionArg.STRING, null, _("Shows only the 'compose tweet' window for the given account, nothing else."), 
                  // TRANSLATORS: Used as the placeholder for the account name in the `--help` output
                  _("account-name") };
    // TRANSLATORS: Description of the `--start-service` option for the command-line
    options[1] = {"start-service", 's', 0, OptionArg.NONE, null, _("Start service"), null};
    // TRANSLATORS: Description of the `--stop-service` option for the command-line
    options[2] = {"stop-service", 'p', 0, OptionArg.NONE, null, _("Stop service, if it has been started as a service"), null};
    // TRANSLATORS: Description of the `--print-startup-accounts` option for the command-line
    options[3] = {"print-startup-accounts", 'a', 0, OptionArg.NONE, null, _("Print configured startup accounts"), null};
    // TRANSLATORS: Description of the `--account` option for the command-line
    options[4] = {"account", 'c', 0, OptionArg.STRING, null, _("Open the window for the given account"), _("account-name")};
    options[5] = {"stresstest", 'r', GLib.OptionFlags.HIDDEN, OptionArg.NONE, null, "Debugging only.", null};
    options[6] = {null};
    this.add_main_option_entries(options);
#if VIDEO
    this.add_option_group (Gst.init_get_option_group ());
#endif
    this.handle_local_options.connect(handle_handle_local_options);
    this.command_line.connect(handle_handle_global_options);
    this.activate.connect(handle_activate);
    this.startup.connect(handle_startup);
    this.shutdown.connect(handle_shutdown);
  }

  private int handle_handle_local_options(GLib.VariantDict options) {
    if (options.contains("print-startup-accounts")) {
      string[] startup_accounts = Settings.get ().get_strv ("startup-accounts");
      foreach (unowned string acc in startup_accounts) {
        stdout.printf ("%s\n", acc);
      }
      return 0;
    }
    return -1;
  }

  private int handle_handle_global_options (GLib.ApplicationCommandLine cmd_line) {
    var name = null;
    var options = cmd_line.get_options_dict();
    if (options.contains("stop-service")) {
      if (this.started_as_service) {
        debug ("Stopping service");
        /* Starting as a service adds an extra hold() */
        this.release ();
      } else {
        warning ("--stop-service passed, but cawbird has not been started as a service");
      }
      return 0;
    } else if (options.contains("start-service")) {
      if (!this.started_as_service) {
        this.started_as_service = true;
      }
      return 0;
    } else if (options.lookup("tweet", "s", ref name)) {
      open_startup_windows (name, null);        
      return 0;
    }
    else if (options.lookup("account", "s", ref name)) {
      open_startup_windows(null, name);
      return 0;
    }

    return 0;
  }

  private void handle_activate () {
    if (started_as_service) {
      this.hold ();

      string[] startup_accounts = Settings.get ().get_strv ("startup-accounts");
      if (startup_accounts.length == 1 && startup_accounts[0] == "")
        startup_accounts.resize (0);

      debug ("Configured startup accounts: %d", startup_accounts.length);
      uint n_accounts = Account.get_n ();
      debug ("Configured accounts: %u", n_accounts);

      foreach (unowned string screen_name in startup_accounts) {
        Account? acc = Account.query_account (screen_name);
        if (acc != null) {
          debug ("Service: Starting account %s...", screen_name);
          this.start_account (acc);
        } else {
          warning ("Invalid startup account: '%s'", screen_name);
        }
      }
    } else {
      open_startup_windows (null, null);
    }
  }

  private void show_settings_activated () {
    /* We don't set the settings dialog transient to
       any window because we already save its size */
    if (this.settings_dialog != null)
      return;

    var dialog = new SettingsDialog (this);
    var action = (GLib.SimpleAction)this.lookup_action ("show-settings");
    action.set_enabled (false);
    dialog.delete_event.connect (() => {
      action.set_enabled (true);
      this.settings_dialog = null;
      return Gdk.EVENT_PROPAGATE;
    });
    dialog.show ();
  }

  private void about_activated () {
    var active_window = get_active_window ();
    var ad = new AboutDialog ();
    ad.modal = true;
    ad.set_transient_for (active_window);
    ad.show_all ();
  }

  private void show_shortcuts_activated () {
    var builder = new Gtk.Builder.from_resource ("/uk/co/ibboard/cawbird/ui/shortcuts-window.ui");
    var shortcuts_window = (Gtk.Window) builder.get_object ("shortcuts_window");
    shortcuts_window.show ();
  }

  private void handle_startup () {
    this.set_resource_base_path ("/uk/co/ibboard/cawbird");

    typeof (LazyMenuButton).ensure ();
    typeof (FavImageView).ensure ();
    typeof (Cb.EmojiChooser).ensure ();
    typeof (ChildSizedScroller).ensure ();

#if DEBUG
    GLib.Environment.set_variable ("G_MESSAGES_DEBUG", "cawbird", true);
#endif

    debug ("startup");
    // Setup gettext
    GLib.Intl.setlocale (GLib.LocaleCategory.ALL, Config.DATADIR + "/locale");
    GLib.Intl.bindtextdomain (Config.GETTEXT_PACKAGE, null);
    GLib.Intl.bind_textdomain_codeset (Config.GETTEXT_PACKAGE, "UTF-8");
    GLib.Intl.textdomain (Config.GETTEXT_PACKAGE);



    Utils.load_custom_css ();
    Utils.load_custom_icons ();
    Utils.init_soup_session ();
    Twitter.get ().init ();

    this.set_accels_for_action ("win.compose-tweet", {Settings.get_accel ("compose-tweet")});
    this.set_accels_for_action ("win.toggle-topbar", {Settings.get_accel ("toggle-sidebar")});
    this.set_accels_for_action ("win.switch-page(0)", {"<Alt>1"});
    this.set_accels_for_action ("win.switch-page(1)", {"<Alt>2"});
    this.set_accels_for_action ("win.switch-page(2)", {"<Alt>3"});
    this.set_accels_for_action ("win.switch-page(3)", {"<Alt>4"});
    this.set_accels_for_action ("win.switch-page(4)", {"<Alt>5"});
    this.set_accels_for_action ("win.switch-page(5)", {"<Alt>6"});
    this.set_accels_for_action ("win.switch-page(6)", {"<Alt>7"});
    this.set_accels_for_action ("app.show-settings", {Settings.get_accel ("show-settings")});
    this.set_accels_for_action ("app.quit", {"<Primary>Q"});
    this.set_accels_for_action ("app.show-shortcuts", {"<Primary>question", "<Primary>F1"});
    this.set_accels_for_action ("win.show-account-dialog", {Settings.get_accel ("show-account-dialog")});
    this.set_accels_for_action ("win.show-account-list", {Settings.get_accel ("show-account-list")});
    this.set_accels_for_action ("win.previous", {"<Alt>Left", "Back"});
    this.set_accels_for_action ("win.next", {"<Alt>Right", "Forward"});

    // TweetInfoPage
    this.set_accels_for_action ("tweet.reply",    {"r"});
    this.set_accels_for_action ("tweet.favorite", {"f"});

    this.add_action_entries (app_entries, this);

    // If the user wants the dark theme, apply it
    var gtk_s = Gtk.Settings.get_default ();
    if (Settings.use_dark_theme ()) {
      gtk_s.gtk_application_prefer_dark_theme = true;
    }

    if (gtk_s.gtk_decoration_layout.contains ("menu")) {
      gtk_s.gtk_decoration_layout = gtk_s.gtk_decoration_layout.replace ("menu", "");
    }

  }

  private void handle_shutdown () {
    Cb.MediaDownloader.get_default ().shutdown ();
  }

  /**
   * Open startup windows.
   * Semantics: Open a window for every account in the startup-accounts array.
   * If that array is empty, look at all the account and if there is one, open that one.
   * If there is none, open a MainWindow with a null account.
   */
  private void open_startup_windows (string? compose_screen_name, string? account_name) {
    /* Explicitly prefer compose-name over account-name */
    if (compose_screen_name != null && account_name != null) {
      account_name = null;
    }

    if (compose_screen_name != null) {
      Account? acc = Account.query_account (compose_screen_name);
      if (acc == null) {
        critical ("No account named `%s` is configured. Exiting.",
                  account_name);
        return;
      }
      acc.init_proxy ();
      acc.query_user_info_by_screen_name.begin ();
      var cw = new ComposeTweetWindow (null, acc, null,
                                       ComposeTweetWindow.Mode.NORMAL);
      cw.show ();
      this.add_window (cw);
      return;
    }

    if (account_name != null) {
      Account? acc = Account.query_account (account_name);
      if (acc == null) {
        critical ("No account named `%s` is configured. Exiting.",
                  account_name);
        return;
      }

      acc.init_proxy ();
      acc.query_user_info_by_screen_name.begin ();
      add_window_for_account (acc);
      return;
    }

    string[] startup_accounts = Settings.get ().get_strv ("startup-accounts");
    /* Handle the stupid case where only one item is in the array but it's empty */
    if (startup_accounts.length == 1 && startup_accounts[0] == "")
      startup_accounts.resize (0);

    uint n_accounts = Account.get_n ();

    if (startup_accounts.length == 0) {
      if (n_accounts == 1) {
        add_window_for_screen_name (Account.get_nth (0).screen_name);
      } else if (n_accounts == 0) {
        var window = new MainWindow (this, null);
        add_window (window);
        window.show_all ();
      } else {
        /* We have multiple configured accounts but still none in autostart.
           This should never happen but we handle the case anyway by just opening
           the first one. */
        add_window_for_screen_name (Account.get_nth (0).screen_name);
      }
    } else {
      bool opened_window = false;
      foreach (unowned string account in startup_accounts) {
        if (!is_window_open_for_screen_name (account, null)) {
          if (add_window_for_screen_name (account)) {
            opened_window = true;
          }
        }
      }
      /* If we did not open any window at all since all windows for every account
         in the startups-account array were already open, just open a new window with a null account */
      if (!opened_window) {
        if (n_accounts > 0) {
          /* Check if *any* of the configured accounts (not just startup-accounts)
             is not opened in a window */
          for (uint i = 0; i < Account.get_n (); i ++) {
            var account = Account.get_nth (i);
            if (!is_window_open_for_user_id (account.id, null)) {
              add_window_for_account (account);
              return;
            }
          }
        }
        foreach (Gtk.Window w in this.get_windows ())
          if (((MainWindow)w).account.screen_name == Account.DUMMY) {
            return;
          }

        var m = new MainWindow (this, null);
        add_window (m);
        m.show_all ();
      }
    }
  }

  /**
   * Adds a new MainWindow instance with the account that
   * has the given screen name.
   * Note that this only works if the account is already properly
   * set up and won't warn or fail if if isn't.
   *
   * @param screen_name The screen name of the account to add a
   *                    MainWindow for.
   *
   * @return true if a window has been opened, false otherwise
   */
  public bool add_window_for_screen_name (string screen_name) {
    Account? acc = Account.query_account (screen_name);
    if (acc != null) {
      add_window_for_account (acc);
      return true;
    }

    warning ("Could not add window for account '%s'", screen_name);
    return false;
  }

  public void add_window_for_account (Account account) {
    var window = new MainWindow (this, account);
    this.add_window (window);
    window.show_all ();
  }

  /**
   * Checks if there's currently a MainWindow instance open that has a
   * reference to the account with the given screen name.
   * (This makes a linear search over all open windows, with a text comparison
   * in each iteration)
   *
   * @param screen_name The screen name to search for
   * @return TRUE if a window with the account associated to the given
   *         screen name is open, FALSE otherwise.
   */
  public bool is_window_open_for_screen_name (string screen_name,
                                              out MainWindow? window = null) {
    unowned GLib.List<Gtk.Window> windows = this.get_windows ();
    foreach (Gtk.Window win in windows) {
      if (win is MainWindow) {
        if (((MainWindow)win).account.screen_name == screen_name) {
          window = (MainWindow)win;
          return true;
        }
      }
    }
    window = null;
    return false;
  }

  public bool is_window_open_for_user_id (int64 user_id,
                                          out MainWindow? window = null) {
    unowned GLib.List<Gtk.Window> windows = this.get_windows ();
    foreach (Gtk.Window win in windows) {
      if (win is MainWindow) {
        if (((MainWindow)win).account.id == user_id) {
          window = (MainWindow)win;
          return true;
        }
      }
    }
    window = null;
    return false;
  }

  /**
   * Quits the application, saving all open windows and their geometries.
   */
  private void quit_application () {
    unowned GLib.List<Gtk.Window> windows = this.get_windows ();
    string[] startup_accounts = Settings.get ().get_strv ("startup-accounts");
    if (startup_accounts.length == 1 && startup_accounts[0] == "")
      startup_accounts.resize (0);


    if (startup_accounts.length != 0) {
      base.quit ();
      return;
    }

    string[] account_names = new string[windows.length ()];
    int index = 0;
    foreach (var win in windows) {
      if (!(win is MainWindow))
        continue;
      var mw = (MainWindow)win;
      string screen_name = mw.account.screen_name;
      mw.save_geometry ();
      account_names[index] = screen_name;
      index ++;
    }
    account_names.resize (index + 1);
    Settings.get ().set_strv ("startup-accounts", account_names);
    base.quit ();
  }

  public void start_account (Account acc) {
    for (int i = 0; i < this.active_accounts.length; i ++) {
      var account = this.active_accounts.get (i);
      if (acc == account) {
        /* This can very well happen when we've been started as a service */
        debug ("Account %s is already active", acc.screen_name);
        return;
      }
    }

    acc.init_proxy ();
    acc.user_stream.start ();
    acc.init_information.begin ();

    this.active_accounts.add (acc);
  }

  public void stop_account (Account acc) {
    bool found = false;
    for (int i = 0; i < this.active_accounts.length; i ++) {
      var account = this.active_accounts.get (i);
      if (account == acc) {
        found = true;
        break;
      }
    }

    if (!found) {
      warning ("Can't stop account %s since it's not in the list of active accounts",
               acc.screen_name);
      return;
    }

    /* If we got started as a service and the given account is in the
     * startup accounts, don't stop it here */
    string[] startup_accounts = Settings.get ().get_strv ("startup-accounts");
    if (this.started_as_service && acc.screen_name in startup_accounts) {
      // Don't stop account
    } else {
      acc.uninit ();
      this.active_accounts.remove (acc);
    }
  }

  /********************************************************/

  private void show_dm_thread (GLib.SimpleAction a, GLib.Variant? value) {
    // Values: Account id, sender_id
    int64 account_id = value.get_child_value (0).get_int64 ();
    int64 sender_id  = value.get_child_value (1).get_int64 ();
    MainWindow main_window;
    if (is_window_open_for_user_id (account_id, out main_window)) {
      var bundle = new Cb.Bundle ();
      bundle.put_int64 (DMPage.KEY_SENDER_ID, sender_id);
      main_window.main_widget.switch_page (Page.DM, bundle);
      main_window.present ();
    } else {
      var account = Account.query_account_by_id (account_id);
      if (account == null) {
        /* Security measure, should never happen. */
        critical ("No account with id %s found", account_id.to_string ());
        return;
      }
      main_window = new MainWindow (this, account);
      this.add_window (main_window);
      var bundle = new Cb.Bundle ();
      bundle.put_int64 (DMPage.KEY_SENDER_ID, sender_id);
      main_window.main_widget.switch_page (Page.DM, bundle);

      main_window.show_all ();
    }
  }

  private void show_window (GLib.SimpleAction a, GLib.Variant? value) {
    int64 user_id = value.get_int64 ();
    MainWindow main_window;
    if (is_window_open_for_user_id (user_id, out main_window)) {
      main_window.present ();
    } else {
      var account = Account.query_account_by_id (user_id);
      if (account == null) {
        /* Security measure, should never happen. */
        critical ("No account with id %s found", user_id.to_string ());
        return;
      }
      main_window = new MainWindow (this, account);
      this.add_window (main_window);
      main_window.show_all ();
    }
  }

  private void mark_read_activated (GLib.SimpleAction a, GLib.Variant? v) {
    int64 account_id = v.get_child_value (0).get_int64 ();
    int64 tweet_id   = v.get_child_value (1).get_int64 ();
    MainWindow main_window;

    if (is_window_open_for_user_id (account_id, out main_window)) {
      main_window.mark_tweet_as_read (tweet_id);
    }
  }

  private void reply_to_tweet_activated (GLib.SimpleAction a, GLib.Variant? v) {
    int64 account_id = v.get_child_value (0).get_int64 ();
    int64 tweet_id   = v.get_child_value (1).get_int64 ();
    MainWindow main_window;

    if (is_window_open_for_user_id (account_id, out main_window)) {
      main_window.reply_to_tweet (tweet_id);
      main_window.present ();
    }
  }

#if DEBUG
  private void post_json (GLib.SimpleAction a, GLib.Variant? value) {
    string screen_name = value.get_child_value (0).get_string ();
    string json = value.get_child_value (1).get_string ();
    json += "\r\n";

    for (int i = 0; i < this.active_accounts.length; i ++) {
      var acc = this.active_accounts.get (i);
      if (acc.screen_name == screen_name) {
        acc.user_stream.push_data (json);
        return;
      }
    }

    error ("Account @%s is not active.", screen_name);
  }
#endif
}
