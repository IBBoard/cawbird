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

[GtkTemplate (ui = "/uk/co/ibboard/cawbird/ui/compose-window.ui")]
class ComposeTweetWindow : Gtk.ApplicationWindow {
  const int DEFAULT_WIDTH = 450;
  public enum Mode {
    NORMAL,
    REPLY,
    QUOTE
  }
  [GtkChild]
  private AvatarWidget avatar_image;
  [GtkChild]
  private Gtk.Grid content_grid;
  [GtkChild]
  private CompletionTextView tweet_text;
  [GtkChild]
  private Gtk.Label length_label;
  [GtkChild]
  private Gtk.Button send_button;
  [GtkChild]
  private Gtk.Spinner title_spinner;
  [GtkChild]
  private Gtk.Label title_label;
  [GtkChild]
  private Gtk.Stack title_stack;
  [GtkChild]
  private ComposeImageManager compose_image_manager;
  [GtkChild]
  private Gtk.Button add_image_button;
  [GtkChild]
  private Gtk.Stack stack;
  [GtkChild]
  private Gtk.Grid image_error_grid;
  [GtkChild]
  private Gtk.Label image_error_label;
  [GtkChild]
  private Gtk.Button cancel_button;
  [GtkChild]
  private FavImageView fav_image_view;
  [GtkChild]
  private Gtk.Button fav_image_button;
  [GtkChild]
  private Gtk.Revealer completion_revealer;
  [GtkChild]
  private Gtk.ListBox completion_list;
  [GtkChild]
  private Gtk.Box add_button_box;
  private Cb.EmojiChooser? emoji_chooser = null;
  private Gtk.Button? emoji_button = null;
  private unowned Account account;
  private unowned MainWindow main_window;
  private Cb.Tweet reply_to;
  private int64 reply_to_id = 0;
  private bool reply_to_loaded = false;
  private Mode mode;
  private GLib.Cancellable? cancellable;
  private Gtk.ListBox? reply_list = null;
  private Cb.ComposeJob compose_job;


  public ComposeTweetWindow (MainWindow? parent,
                             Account     acc,
                             Cb.Tweet?   reply_to = null,
                             Mode        mode = Mode.NORMAL) {
    this.set_show_menubar (false);
    this.main_window = parent;
    this.account = acc;
    this.reply_to = reply_to;
    this.mode = mode;
    this.tweet_text.set_account (acc);
    this.application = (Gtk.Application)GLib.Application.get_default ();

    this.cancellable = new GLib.Cancellable ();
    var upload_proxy = new Rest.OAuthProxy (Settings.get_consumer_key (),
                                            Settings.get_consumer_secret (),
                                            "https://upload.twitter.com/",
                                            false);
    upload_proxy.token = account.proxy.token;
    upload_proxy.token_secret = account.proxy.token_secret;
    this.compose_job = new Cb.ComposeJob (account.user_stream,
                                          account.proxy,
                                          upload_proxy,
                                          this.cancellable);

    this.compose_job.image_upload_progress.connect ((path, progress) => {
      this.compose_image_manager.set_image_progress (path, progress);
    });
    this.compose_job.image_upload_finished.connect ((path, error_msg) => {
      debug ("%s Finished!", path);
      this.compose_image_manager.end_progress (path, error_msg);
    });

    length_label.label = Cb.Tweet.MAX_LENGTH.to_string ();
    load_tweet.begin ();

    avatar_image.surface = acc.avatar;
    acc.notify["avatar"].connect (() => {
      avatar_image.surface = account.avatar;
    });

    GLib.NetworkMonitor.get_default ().notify["network-available"].connect (update_send_button_sensitivity);

    tweet_text.buffer.changed.connect (update_send_button_sensitivity);

    if (parent != null) {
      this.set_transient_for (parent);
      this.set_modal (true);
    }

    /* Let the text view immediately grab the keyboard focus */
    tweet_text.grab_focus ();
    tweet_text.completion_listbox = this.completion_list;
    tweet_text.show_completion.connect (() => {
      completion_revealer.reveal_child = true;
    });
    tweet_text.hide_completion.connect (() => {
      completion_revealer.reveal_child = false;
    });

    Gtk.AccelGroup ag = new Gtk.AccelGroup ();
    ag.connect (Gdk.Key.Escape, 0, Gtk.AccelFlags.LOCKED, escape_pressed_cb);
    ag.connect (Gdk.Key.Return, Gdk.ModifierType.CONTROL_MASK, Gtk.AccelFlags.LOCKED,
        () => {start_send_tweet (); return true;});
    ag.connect (Gdk.Key.E, Gdk.ModifierType.CONTROL_MASK, Gtk.AccelFlags.LOCKED,
        () => {show_emoji_chooser (); return true;});


    this.compose_image_manager.image_removed.connect ((path) => {
      this.compose_job.abort_image_upload (path);

      if (!this.compose_image_manager.full) {
        this.add_image_button.sensitive = true;
        this.fav_image_button.sensitive = true;
      }

      if (path.down ().has_suffix (".gif")) {
        fav_image_view.set_gifs_enabled (true);
        this.add_image_button.sensitive = true;
        this.fav_image_button.sensitive = true;
      }

      if (this.compose_image_manager.n_images == 0) {
        this.compose_image_manager.hide ();
        fav_image_view.set_gifs_enabled (true);
      }

      update_send_button_sensitivity ();
    });

    this.compose_image_manager.image_reloaded.connect ((path) => {
      this.compose_job.abort_image_upload (path);
      this.compose_job.upload_image_async (path);
    });

    this.add_accel_group (ag);

    var image_target_list = new Gtk.TargetList (null);
    image_target_list.add_text_targets (0);

    /* The GTK+ version might not have this emoji data variant */
    try {
      if (GLib.resources_get_info ("/org/gtk/libgtk/emoji/emoji.data",
                                   GLib.ResourceLookupFlags.NONE, null, null)) {
        setup_emoji_chooser ();
      }
    } catch (GLib.Error e) {
      // Ignore, just don't show the emoji chooser
    }

    this.set_default_size (DEFAULT_WIDTH, (int)(DEFAULT_WIDTH / 2.5));
  }

  private async void load_tweet () {
    string? last_tweet = account.db.select ("info").cols ("last_tweet").once_string ();
    if (last_tweet != null && last_tweet.length > 0 &&
        tweet_text.get_buffer ().text.length == 0) {
      this.tweet_text.get_buffer ().text = last_tweet;
    }

    string[] failed_paths = {};

    for (uint i = 0; i < Cb.ComposeJob.MAX_UPLOADS; i++) {
      string? image_path = account.db.select ("info").cols ("last_tweet_image_%u".printf(i + 1)).once_string ();

      if (image_path != null && image_path.length > 0){
        try {
          load_image (image_path);
        }
        catch (GLib.Error e) {
          failed_paths += image_path;
        }
      }
    }

    if (failed_paths.length > 0) {      
      // It would have been nice to do this in one string, but using format positions to
      // let translations skip the image count results in `*** invalid %N$ use detected ***`

      stack.visible_child = image_error_grid;
      var failed_to_log_str = ngettext("Failed to load image", "Failed to load %u images", failed_paths.length).printf(failed_paths.length);
      // TRANSLATORS: Combine plural "Failed to load image" and list of failed paths
      // to make "Failed to load image: <path>" or "Failed to load 3 images: <path>, <path>, <path>"
      image_error_label.label = _("%s: %s").printf(failed_to_log_str, string.joinv(", ", failed_paths));

      cancel_button.label = _("Back");
    }

    int64 last_reply_id = account.db.select ("info").cols ("last_tweet_reply_id").once_i64 ();
    int64 last_quote_id = account.db.select ("info").cols ("last_tweet_quote_id").once_i64 ();
    var candidate_mode = Mode.NORMAL;

    if (this.reply_to != null) {
      this.reply_to_id = this.reply_to.id;
      this.reply_to_loaded = true;
    }
    else if (last_reply_id != 0) {
      this.reply_to_id = last_reply_id;
      candidate_mode = Mode.REPLY;
    }
    else if (last_quote_id != 0){
      this.reply_to_id = last_quote_id;
      candidate_mode = Mode.QUOTE;
    }
    // Else it's a new tweet

    if (this.reply_to == null && this.reply_to_id > 0) {
      string error_reason = "Unknown error";

      try {
        this.reply_to = yield TweetUtils.get_tweet (account, this.reply_to_id);
      }
      catch (GLib.Error e) {
        error_reason = e.message;
        warning (e.message);
      }

      if (this.reply_to == null) {
        string message = candidate_mode == Mode.QUOTE ? "Error fetching quoted tweet: %s\n\nSave unsent tweet?" :
                                                        "Error fetching reply tweet: %s\n\nSave unsent tweet?";
        var messagedialog = new Gtk.MessageDialog (this,
                                                  Gtk.DialogFlags.MODAL,
                                                  Gtk.MessageType.WARNING,
                                                  Gtk.ButtonsType.YES_NO,
                                                  message.printf (error_reason));
        messagedialog.set_default_response (Gtk.ResponseType.YES);
        int response = messagedialog.run ();
        messagedialog.destroy ();

        if (response == Gtk.ResponseType.NO) {
          set_text ("");
          this.reply_to_id = 0;
          clear_last_tweet ();
        }
        else {
          // We're in an invalid state - all we can do is close and let the user try again later
          this.close ();
        }
      }
      else {
        // Don't set the mode until now in case fetching the tweet fails
        // If we set it earlier then we get segfaults when code assumes this.reply_to is set.
        this.mode = candidate_mode;
        this.reply_to_loaded = true;
      }
    }

    if (this.mode == Mode.REPLY)
      this.compose_job.set_reply_id (this.reply_to.id);
    else if (this.mode == Mode.QUOTE)
      this.compose_job.set_quoted_tweet (this.reply_to);

    if (mode != Mode.NORMAL) {
      reply_list = new Gtk.ListBox ();
      reply_list.selection_mode = Gtk.SelectionMode.NONE;
      TweetListEntry reply_entry = new TweetListEntry (reply_to, main_window, account, true);
      reply_entry.activatable = false;
      reply_entry.read_only = true;
      reply_entry.show ();
      reply_list.add (reply_entry);
      reply_list.show ();
      content_grid.attach (reply_list, 0, 0, 2, 1);
    }

    if (mode == Mode.QUOTE) {
      assert (reply_to != null);
      this.title_label.label = _("Quote tweet");
    }

    this.update_send_button_sensitivity ();
  }

  private void update_send_button_sensitivity () {
    Gtk.TextIter start, end;
    tweet_text.buffer.get_bounds (out start, out end);
    string text = tweet_text.buffer.get_text (start, end, true);

    int length = (int)Tl.count_weighted_characters (text);
    if (compose_image_manager.n_images > 0 && mode == Mode.QUOTE)
      length += 1 + Twitter.short_url_length;
    length_label.label = (Cb.Tweet.MAX_LENGTH - length).to_string ();

    if (length > 0 && length <= Cb.Tweet.MAX_LENGTH ||
        (length == 0 && compose_image_manager.n_images > 0)) {
      bool network_reachable = GLib.NetworkMonitor.get_default ().network_available;
      send_button.sensitive = network_reachable;
    } else {
      send_button.sensitive = false;
    }
  }

  private void set_sending_state (bool sending) {
    if (sending) {
      title_stack.visible_child = title_spinner;
      title_spinner.start ();
      compose_image_manager.insensitivize_buttons ();
      send_button.sensitive = false;
    } else {
      title_stack.visible_child = title_label;
      title_spinner.stop ();
      compose_image_manager.sensitivize_buttons ();
      update_send_button_sensitivity ();
    }

    tweet_text.sensitive = !sending;
    fav_image_button.sensitive = !sending;
    add_image_button.sensitive = !sending;

    if (emoji_button != null)
    {
      emoji_button.sensitive = !sending;
    }
  }

  [GtkCallback]
  private void start_send_tweet () {
    if (!send_button.sensitive)
      return;

    set_sending_state (true);
    Gtk.TextIter start, end;
    tweet_text.buffer.get_start_iter (out start);
    tweet_text.buffer.get_end_iter (out end);
    this.compose_job.set_text (tweet_text.buffer.get_text (start, end, true));

    /* Save the tweet in case sending fails */
    this.save_last_tweet ();

    this.compose_job.send_async.begin (this.cancellable, (obj, res) => {
      bool success = false;
      try {
       success = this.compose_job.send_async.end (res);
      } catch (GLib.Error e) {
        Utils.show_error_object (this.compose_job.response_payload, e.message,
                                 GLib.Log.LINE, GLib.Log.FILE, this);
        set_sending_state (false);
        return;
      }
      debug ("Tweet sent.");
      if (success) {
        this.clear_last_tweet ();
        this.destroy ();
      } else {
        set_sending_state (false);
        // FIXME: Translate
        Utils.show_error_dialog ("Failed to send tweet", this);
      }
    });
  }

  private void save_last_tweet () {
    int64 last_reply_id = 0;
    int64 last_quote_id = 0;

    // FIXME: If the tweet failed to load then these modes aren't set!
    if (this.mode == Mode.REPLY) {
      last_reply_id = this.reply_to_id;
    }
    else if (this.mode == Mode.QUOTE) {
      last_quote_id = this.reply_to_id;
    }

    string text = tweet_text.buffer.text;
    var query = account.db.update ("info").val ("last_tweet", text);
    var image_count = compose_job.get_n_filepaths ();

    for (var i = 0; i < image_count; i++) {
      query.val ("last_tweet_image_%u".printf(i + 1), compose_job.get_filepath (i));
    }
    for (var i = image_count; i < Twitter.max_media_per_upload; i++) {
      query.val ("last_tweet_image_%u".printf(i + 1), "");
    }

    if (reply_to_loaded) {
      // Only overwrite the last_tweet_{reply,quote}_id if it loaded properly
      query.vali64 ("last_tweet_reply_id", last_reply_id)
           .vali64 ("last_tweet_quote_id", last_quote_id);
    }

    query.run();
  }

  private void clear_last_tweet () {
    account.db.update ("info").val ("last_tweet", "")
                              .vali64 ("last_tweet_reply_id", 0)
                              .vali64 ("last_tweet_quote_id", 0)
                              .val ("last_tweet_image_1", "")
                              .val ("last_tweet_image_2", "")
                              .val ("last_tweet_image_3", "")
                              .val ("last_tweet_image_4", "")
                              .run ();
  }

  [GtkCallback]
  private void cancel_clicked () {
    if (stack.visible_child == image_error_grid ||
        stack.visible_child == emoji_chooser ||
        stack.visible_child_name == "fav-images") {
      stack.visible_child = content_grid;
      cancel_button.label = _("Cancel");
      /* Use this instead of just setting send_button.sensitive to true to avoid
         sending tweets with 0 length */
      this.update_send_button_sensitivity ();
    } else {
      if (this.cancellable != null) {
        this.cancellable.cancel ();
      }

      Gtk.TextIter start, end;
      tweet_text.buffer.get_bounds (out start, out end);
      string text = tweet_text.buffer.get_text (start, end, true);

      if (text != "" || compose_job.get_n_filepaths () > 0) {
          save_last_tweet ();
      }
      else {
        clear_last_tweet ();
      }

      destroy ();
    }
  }

  private bool escape_pressed_cb () {
    this.cancel_clicked ();
    return Gdk.EVENT_STOP;
  }

  public void set_text (string text) {
    tweet_text.buffer.text = text;
  }

  [GtkCallback]
  private void add_image_clicked_cb (Gtk.Button source) {
    var filechooser = new Gtk.FileChooserNative (_("Select Image"),
                                                 this,
                                                 Gtk.FileChooserAction.OPEN,
                                                 _("Open"),
                                                 _("Cancel"));


    var filter = new Gtk.FileFilter ();
    filter.add_mime_type ("image/png");
    filter.add_mime_type ("image/jpeg");
    filter.add_mime_type ("image/gif");
    filechooser.set_filter (filter);

    if (filechooser.run () == Gtk.ResponseType.ACCEPT) {
      var filename = filechooser.get_filename ();
      try {
        load_image (filename);
      }
      catch (GLib.Error e) {
        // TODO: Proper error checking/reporting
        // But it shouldn't happen because we only just picked it, so the file info
        // should just work
        warning ("%s (%s)", e.message, filename);
      }
    }

    update_send_button_sensitivity ();
  }

  private void load_image (string filename) throws GLib.Error {
    debug ("Loading %s", filename);

    /* Get file size */
    var file = GLib.File.new_for_path (filename);
    GLib.FileInfo info = file.query_info (GLib.FileAttribute.STANDARD_TYPE + "," +
                                          GLib.FileAttribute.STANDARD_CONTENT_TYPE + "," +
                                          GLib.FileAttribute.STANDARD_SIZE, 0);

    if (!info.get_content_type ().has_prefix ("image/")) {
      stack.visible_child = image_error_grid;
      image_error_label.label = _("Selected file is not an image.");
      cancel_button.label = _("Back");
      send_button.sensitive = false;
    } else if (info.get_size () > Twitter.MAX_BYTES_PER_IMAGE) {
      stack.visible_child = image_error_grid;
      image_error_label.label = _("The selected image is too big. The maximum file size per image is %'d MB")
                                .printf (Twitter.MAX_BYTES_PER_IMAGE / 1024 / 1024);
      cancel_button.label = _("Back");
      send_button.sensitive = false;
    } else if (filename.has_suffix (".gif") &&
               this.compose_image_manager.n_images > 0) {
      stack.visible_child = image_error_grid;
      image_error_label.label = _("Only one GIF file per tweet is allowed.");
      cancel_button.label = _("Back");
      send_button.sensitive = false;
    } else {
      this.compose_image_manager.show ();
      this.compose_image_manager.load_image (filename, null);
      this.compose_job.upload_image_async (filename);
      if (this.compose_image_manager.n_images > 0) {
        fav_image_view.set_gifs_enabled (false);
      }
      if (this.compose_image_manager.full) {
        this.add_image_button.sensitive = false;
        this.fav_image_button.sensitive = false;
      }
    }
  }

  [GtkCallback]
  public void fav_image_button_clicked_cb () {
    cancel_button.label = _("Back");
    stack.visible_child_name = "fav-images";
    this.fav_image_view.load_images ();
  }

  [GtkCallback]
  public void favorite_image_selected_cb (string path) {
    cancel_clicked ();
    this.compose_image_manager.show ();
    this.compose_image_manager.load_image (path, null);
    this.compose_job.upload_image_async (path);
    if (this.compose_image_manager.full) {
      this.add_image_button.sensitive = false;
      this.fav_image_button.sensitive = false;
    }

    if (this.compose_image_manager.n_images > 0)
      fav_image_view.set_gifs_enabled (false);

    update_send_button_sensitivity ();
  }

  [GtkCallback]
  public void tweet_text_populate_popup_cb (Gtk.Menu popup) {
    if (this.emoji_chooser == null)
      return;

    var menuitem = new Gtk.MenuItem.with_label (_("Insert Emoji"));
    menuitem.activate.connect (show_emoji_chooser);
    menuitem.show ();
    popup.add (menuitem);
  }

  private void show_emoji_chooser () {
    if (this.emoji_chooser == null)
      return;

    this.emoji_button.clicked ();
  }

  private void setup_emoji_chooser () {
    this.emoji_chooser = new Cb.EmojiChooser ();

    if (!emoji_chooser.try_init ()) {
      this.emoji_chooser = null;
      return;
    }

    emoji_chooser.emoji_picked.connect ((text) => {
      this.tweet_text.insert_at_cursor (text);
      cancel_clicked ();
    });
    emoji_chooser.show_all ();
    stack.add (emoji_chooser);

    this.emoji_button = new Gtk.Button.with_label ("🐧");
    emoji_button.clicked.connect (() => {
      this.emoji_chooser.populate ();
      this.stack.visible_child = this.emoji_chooser;
      cancel_button.label = _("Back");
    });

    emoji_button.show_all ();
    add_button_box.add (emoji_button);
  }
}
