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


enum Page {
  STREAM = 0,
  MENTIONS,
  FAVORITES,
  DM_THREADS,
  LISTS,
  FILTERS,
  SEARCH,
  PROFILE,
  TWEET_INFO,
  DM,
  LIST_STATUSES,

  PREVIOUS = 1024,
  NEXT = 2048
}

public Quark get_error_domain() {
  return Quark.from_string("cawbird-utils");
}

static Soup.Session SOUP_SESSION = null;

const int TRANSITION_DURATION = 200 * 1000;

public delegate void VadjustOverScroll (Gtk.ScrolledWindow parent, Gtk.ListBox list_box, int over_scroll);

#if DEBUG
public unowned string __class_name (GLib.Object o) {
  return GLib.Type.from_instance (o).name ();
}
#endif

void default_header_func (Gtk.ListBoxRow  row,
                          Gtk.ListBoxRow? row_before)
{
  if (row_before == null) {
    row.set_header (null);
    return;
  }

  Gtk.Widget? header = row.get_header ();
  if (header != null) {
    return;
  }

  header = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
  header.show ();
  row.set_header (header);
}

int twitter_item_sort_func (Gtk.ListBoxRow a, Gtk.ListBoxRow b) {
  if(((Cb.TwitterItem)a).get_sort_factor () < ((Cb.TwitterItem)b).get_sort_factor ())
    return 1;
  return -1;
}

int twitter_item_sort_func_inv (Gtk.ListBoxRow a, Gtk.ListBoxRow b) {
  if(((Cb.TwitterItem)a).get_sort_factor () < ((Cb.TwitterItem)b).get_sort_factor ())
    return -1;
  return 1;
}

Cairo.Surface? load_surface (string path)
{
  try {
    var p = new Gdk.Pixbuf.from_file (path);
    var s = Gdk.cairo_surface_create_from_pixbuf (p, 1, null);
    return s;
  } catch (GLib.Error e) {
    warning (e.message);
    return null;
  }
}

Cairo.Surface create_video_placeholder_surface ()
{
  try {
    Gdk.Pixbuf pixbuf;
    try {
      pixbuf = Gtk.IconTheme.get_default().load_icon("video-x-generic", 512, 0);
    }
    catch (GLib.Error e) {
      pixbuf = new Gdk.Pixbuf.from_resource("/uk/co/ibboard/cawbird/data/symbolic/apps/cawbird-video-placeholder.svg");
    }
    return Gdk.cairo_surface_create_from_pixbuf (pixbuf, 1, null);
  }
  catch (GLib.Error e) {
    warning("Failed to load video icon *and* fallback resource!");
    return new Cairo.ImageSurface(Cairo.Format.RGB24, 512, 512);
  }
}

Cairo.Surface? load_surface_for_video (string path)
{
  try {
    // Based on https://gitlab.freedesktop.org/gstreamer/gst-plugins-base/-/blob/master/tests/examples/snapshot/snapshot.c
    var playbin = Gst.parse_launch("uridecodebin uri=file://%s ! videoconvert ! videoscale ! appsink name=sink caps=\"video/x-raw,format=BGRx,pixel-aspect-ratio=1/1\"".printf(path));
    playbin.set_state(Gst.State.PAUSED);
    // Wait for the state change
    playbin.get_state(null, null, 5 * Gst.SECOND);
    playbin.seek_simple(Gst.Format.TIME, Gst.SeekFlags.KEY_UNIT | Gst.SeekFlags.FLUSH, 1000);
    var sink = ((Gst.Bin)playbin).get_by_name("sink");
    Gst.Sample sample;
    Signal.emit_by_name(sink, "pull-preroll", out sample, null);
    if(sample == null) {
      throw new GLib.Error(get_error_domain(), 1, "Null GStreamer sample");
    }
    var sample_caps = sample.get_caps();
    if(sample_caps == null) {
      throw new GLib.Error(get_error_domain(), 2, "Null GStreamer sample caps");
    }
    unowned Gst.Structure structure = sample_caps.get_structure(0);
    int width = structure.get_value("width").get_int();
    int height = structure.get_value("height").get_int();
    var buffer = sample.get_buffer();
    size_t offset;
    size_t max_size;
    var size = buffer.get_sizes(out offset, out max_size);
    uint8[] data;
    buffer.extract_dup(offset, size, out data);
    // Paint one surface on to another so that we don't have to keep the byte array around
    var screencap_surface = new Cairo.ImageSurface.for_data(data, Cairo.Format.RGB24, width, height, Cairo.Format.RGB24.stride_for_width(width));
    var surface = new Cairo.ImageSurface(Cairo.Format.RGB24, width, height);
    var context = new Cairo.Context(surface);
    context.set_source_surface(screencap_surface, 0, 0);
    context.paint();
    return surface;
  }
  catch (GLib.Error e) {
    warning("Error creating thumbnail from video for %s: %s", path, e.message);
    return create_video_placeholder_surface();
  }
}


void write_surface (Cairo.Surface surface,
                    string        path)
{
  var status = surface.write_to_png (path);

  if (status != Cairo.Status.SUCCESS) {
    warning ("Could not write surface to '%s': %s", path, status.to_string ());
  }
}

Cairo.Surface scale_surface (Cairo.ImageSurface input,
                             int                output_width,
                             int                output_height)
{
  int old_width  = input.get_width ();
  int old_height = input.get_height ();

  if (old_width == output_width && old_height == output_height)
    return input;

  Cairo.Surface new_surface = new Cairo.Surface.similar_image (input, Cairo.Format.ARGB32,
                                                               output_width, output_height);


  /* http://lists.cairographics.org/archives/cairo/2006-January/006178.html */

  Cairo.Context ct = new Cairo.Context (new_surface);

  ct.scale ((double)output_width / old_width, (double)output_height / old_height);
  ct.set_source_surface (input, 0, 0);
  ct.get_source ().set_extend (Cairo.Extend.PAD);
  ct.set_operator (Cairo.Operator.SOURCE);
  ct.paint ();

  return new_surface;
}


inline double ease_out_cubic (double t) {
  double p = t - 1;
  return p * p * p +1;
}

public delegate TARGET MapFunction<SOURCE, TARGET>(SOURCE src);

TARGET[] map<SOURCE, TARGET>(SOURCE[] arr, MapFunction<SOURCE, TARGET> map_func) {
  var mapped = new GenericArray<TARGET>(arr.length);
  foreach (SOURCE src in arr) {
    mapped.add(map_func(src));
  }
  return mapped.data;
}

namespace Utils {
  /**
   * Removes the retweet flag from a tweet in a model based on a new "un-retweeted" message
   */
  public void unrt_tweet (Json.Node obj, Cb.TweetModel model) {
    int64 tweet_id = obj.get_object ().get_int_member ("id");

    Cb.Tweet? existing_tweet = model.get_for_id (tweet_id, 0);
    if (existing_tweet != null) {
      model.unset_tweet_flag (existing_tweet, Cb.TweetState.RETWEETED);
    }
  }

  /**
   * Sets the retweet flag for a tweet in a model based on a new tweet message
   */
  public void set_rt_from_tweet (Json.Node root, Cb.TweetModel model, Account account) {
    var obj = root.get_object ();

    if (!obj.has_member ("retweeted_status")) {
      return;
    }

    var rt_status = obj.get_object_member ("retweeted_status");
    var rt_author = rt_status.get_object_member ("user").get_int_member ("id");

    if (rt_author != account.id) {
      return;
    }
    
    int64 tweet_id = rt_status.get_int_member ("id");

    Cb.Tweet? existing_tweet = model.get_for_id (tweet_id, 0);
    if (existing_tweet != null) {
      model.set_tweet_flag (existing_tweet, Cb.TweetState.RETWEETED);
    }
  }
  /**
   * Calculates an easily human-readable version of the time difference between
   * time and now.
   * Example: "5m" or "3h" or "26m" or "16 Nov"
   *
   * Passing `extended` returns "minutes ago" or "hours ago" and full months instead of "h" or "m"
   * and abbreviated months
   */
  public string get_time_delta (GLib.DateTime time, GLib.DateTime now, bool extended = false) {
    //diff is the time difference in microseconds
    GLib.TimeSpan diff = now.difference (time);

    int minutes = (int)(diff / 1000.0 / 1000.0 / 60.0);
    if (minutes == 0) {
      return _("Now");
    } else if (minutes < 60) {
      if (extended) {
        return ngettext("%d minute ago", "%d minutes ago", minutes).printf (minutes);
      } else {
        // TRANSLATORS: short-form "x minutes ago"
        return _("%dm").printf (minutes);
      }
    }

    int hours = (int)(minutes / 60.0);
    if (hours < 24) {
      if (extended) {
        return ngettext("%d hour ago", "%d hours ago", hours).printf (hours);
      } else {
        // TRANSLATORS: short-form "x hours ago"
        return _("%dh").printf (hours);
      }
    }

    string date_format;

    if (time.get_year () == now.get_year ()) {
      if (extended) {
        // TRANSLATORS: Full-text date format for tweets from this year - see https://valadoc.org/glib-2.0/GLib.DateTime.format.html
        date_format = _("%e %B");
      } else {
        // TRANSLATORS: Short date format for tweets from this year - see https://valadoc.org/glib-2.0/GLib.DateTime.format.html
        date_format = _("%e %b");
      }
    } else {
      if (extended) {
        // TRANSLATORS: Full-text date format for tweets from previous years - see https://valadoc.org/glib-2.0/GLib.DateTime.format.html
        date_format = _("%e %B %Y");
      } else {
        // TRANSLATORS: Short date format for tweets from previous years - see https://valadoc.org/glib-2.0/GLib.DateTime.format.html
        date_format = _("%e %b %Y");
      }
    }
    return time.format(date_format);
  }

  /**
   * Shows an error dialog for a given GLib error
   * (Unless it is "Operation was cancelled", and then we ignore it)
   *
   * @param e The error to show
   */
  void show_error_dialog (GLib.Error e, Gtk.Window? transient_for = null, string? file = null, int line = 0) {
    if (e is GLib.IOError.CANCELLED) {
      // It's not really an error, so don't show it
      return;
    }


    string message;
    if (e.domain == TweetUtils.get_error_domain()) {
      message = TweetUtils.code_to_message(e.code, e.message);
    } else {
      message = e.message;
    }

    // Log the original message rather than the translation
    if (file != null) {
      warning ("Exception %s:%d: %s in %s:%d", e.domain.to_string(), e.code, e.message, file, line);
    } else {
      warning ("Exception %s:%d: %s", e.domain.to_string(), e.code, e.message);
    }

    var dialog = new Gtk.MessageDialog (transient_for, Gtk.DialogFlags.DESTROY_WITH_PARENT,
                                        Gtk.MessageType.ERROR, Gtk.ButtonsType.OK,
                                        "%s", message);

    dialog.set_modal (true);

    /* Hacky way to get the label selectable */
    ((Gtk.Label)(((Gtk.Container)dialog.get_message_area ()).get_children ().nth_data (0))).set_selectable (true);

    dialog.response.connect ((id) => {
      if (id == Gtk.ResponseType.OK)
        dialog.destroy ();
    });

    dialog.show ();
  }

  async Gdk.Pixbuf? download_pixbuf (string            url,
                                     GLib.Cancellable? cancellable = null) {

    Gdk.Pixbuf? result = null;
    var msg = new Soup.Message ("GET", url);
    GLib.SourceFunc cb = download_pixbuf.callback;

    SOUP_SESSION.queue_message (msg, (_s, _msg) => {
      if (cancellable.is_cancelled ()) {
        cb ();
        return;
      }
      try {
        var in_stream = new MemoryInputStream.from_data (_msg.response_body.data,
                                                         GLib.g_free);
        result = new Gdk.Pixbuf.from_stream (in_stream, cancellable);
      } catch (GLib.Error e) {
        warning (e.message);
      } finally {
        cb ();
      }
    });
    yield;

    return result;
  }

  string unescape_html (string input) {
    string back = input.replace ("&lt;", "<");
    back = back.replace ("&gt;", ">");
    back = back.replace ("&amp;", "&");
    return back;
  }

  /**
   * Gets the word string (and matching begin/end iterators) around the cursor in the buffer (terminated by whitespace)
   */
  public string get_cursor_word (Gtk.TextBuffer buffer, out Gtk.TextIter start_iter, out Gtk.TextIter end_iter) {
    Gtk.TextMark cursor_mark = buffer.get_insert ();
    Gtk.TextIter cursor_iter;
    buffer.get_iter_at_mark (out cursor_iter, cursor_mark);

    start_iter = end_iter = cursor_iter;

    for (;;) {
      Gtk.TextIter left_iter = start_iter;
      left_iter.backward_char ();

      unichar c = left_iter.get_char();

      if (c.isspace()) {
        break;
      }

      start_iter = left_iter;

      if (start_iter.is_start()) {
        break;
      }
    }

    for (;;) {
      unichar c = end_iter.get_char();

      if (c == 0 || c.isspace()) {
        break;
      }

      end_iter.forward_char ();
    }

    return buffer.get_text (start_iter, end_iter, false);
  }

  /**
   * Gets the @-mention string (and matching begin/end iterators) around the cursor in the buffer, ignoring preceding and
   * following punctiation
   */
  public string get_cursor_mention_word (Gtk.TextBuffer buffer, out Gtk.TextIter start_iter, out Gtk.TextIter end_iter) {
    string cursor_word = get_cursor_word (buffer, out start_iter, out end_iter);
    bool changed = false;

    for (;;) {
      unichar c = start_iter.get_char();

      if (c == 0 || c == '@') {
        break;
      }
      else if (c.ispunct()) {
        changed = true;
        start_iter.forward_char();
      }
      else {
        cursor_word = "";
        end_iter = start_iter;
        break;
      }
    }

    for (;;) {
      if (end_iter.get_offset() <= start_iter.get_offset()) {
        break;
      }

      Gtk.TextIter prev_iter = end_iter;
      prev_iter.backward_char();
      unichar c = prev_iter.get_char();

      if (!c.ispunct()) {
        break;
      }

      end_iter = prev_iter;
      changed = true;

      if (end_iter.is_start()) {
        break;
      }
    }

    if (changed) {
      cursor_word = buffer.get_text(start_iter, end_iter, false);
    }

    return cursor_word;
  }

  public void load_custom_icons () {
    var icon_theme  = Gtk.IconTheme.get_default ();
    icon_theme.add_resource_path ("/uk/co/ibboard/cawbird/data/");
  }

  public void load_custom_css () {
    var provider = new Gtk.CssProvider ();
    provider.load_from_resource ("/uk/co/ibboard/cawbird/ui/style.css");
    Gtk.StyleContext.add_provider_for_screen ((!)Gdk.Screen.get_default (),
                                              provider,
                                              Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
  }

  public void init_soup_session () {
    assert (SOUP_SESSION == null);
    SOUP_SESSION = new Soup.Session ();
  }

  string capitalize (string s) {
    string back = s;
    if (s.get_char (0).islower ()) {
      back = s.get_char (0).toupper ().to_string () + s.substring (1);
    }
    return back;
  }

  /**
   * Checks if @value is existing in @node and if it is, non-null.
   *
   * Returns TRUE if the @value does both exist and is non-null.
   */
  public bool usable_json_value (Json.Object node, string value_name) {
    if (!node.has_member (value_name))
        return false;
    return !node.get_null_member (value_name);
  }

  public void update_startup_account (string old_screen_name,
                                      string new_screen_name) {
    string[] startup_accounts = Settings.get ().get_strv ("startup-accounts");
    string[] new_startup_accounts = new string[startup_accounts.length];

    for (int i = 0; i < startup_accounts.length; i ++) {
      if (startup_accounts[i] != old_screen_name)
        new_startup_accounts[i] = startup_accounts[i];
      else
        new_startup_accounts[i] = new_screen_name;
    }

    Settings.get ().set_strv ("startup-accounts", new_startup_accounts);
  }


  public Cb.Filter create_persistent_filter (string content, Account account) {
    int id = (int)account.db.insert ("filters")
                               .val ("content", content)
                               .run();
    Cb.Filter f = new Cb.Filter (content);
    f.set_id (id);
    account.add_filter (f);

    return f;
  }

  public string get_media_display_name (Cb.Media media) {
    unowned string url = media.target_url ?? media.url;
    int last_slash_index = url.last_index_of_char ('/');

    string filename = url.substring (last_slash_index + 1);
    filename = filename.replace (":orig", "");

    int last_dot_index = filename.last_index_of_char ('.');
    if (last_dot_index == -1) {
      // No file extension, guess!
      if (media.is_video ()) {
        filename += ".mp4";
      } else {
        filename += ".jpg";
      }
    }

    return filename;
  }

  public async void download_file (string url, GLib.OutputStream out_stream) {
    var msg = new Soup.Message ("GET", url);
    GLib.SourceFunc cb = download_file.callback;

    SOUP_SESSION.queue_message (msg, (_s, _msg) => {
      try {
        var in_stream = new MemoryInputStream.from_data (_msg.response_body.data,
                                                         GLib.g_free);

        out_stream.splice (in_stream,
                           GLib.OutputStreamSpliceFlags.CLOSE_SOURCE |
                           GLib.OutputStreamSpliceFlags.CLOSE_TARGET,
                           null);
      } catch (GLib.Error e) {
        warning (e.message);
      } finally {
        cb ();
      }
    });
    yield;
  }

  public string linkify_user (Cb.UserIdentity user, bool boldify = false) {
    var username = GLib.Markup.escape_text(user.user_name);
    var buff = new StringBuilder ();
    if (boldify) {
      buff.append("<b>");
    }
    buff.append ("<span underline='none'><a href=\"@")
        .append (user.id.to_string ())
        .append ("/@")
        .append (user.screen_name)
        .append ("\" title=\"")
        .append (GLib.Markup.escape_text(username))
        .append ("\">")
        .append (username)
        .append ("</a></span>");
    if (boldify) {
      buff.append("</b>");
    }
    return buff.str;
  }

  public void connect_vadjustment (Gtk.ScrolledWindow parent, Gtk.ListBox list_box, VadjustOverScroll? scroll_past_top_func = null) {
    // Ideally we'd just do:
    // list_box.set_focus_vadjustment(parent.get_vadjustment())
    // but that gives no way of doing an offset, so we've got to
    // do all of the calculations ourselves.
    // https://stackoverflow.com/a/8912336/283242
    list_box.set_focus_child.connect((focussed_child) => {
      if (focussed_child == null) {
        return;
      }
  
      double widget_left, widget_top;
      focussed_child.translate_coordinates(parent, 0, 0, out widget_left, out widget_top);
      // The coordinate translation doesn't take into account the existing vadjustment! So add it back.
      widget_top += parent.vadjustment.value;
      Gtk.Allocation alloc;
      focussed_child.get_allocation(out alloc);
      var widget_bottom = widget_top + alloc.height;
      var viewport_top = parent.vadjustment.value;
      var viewport_bottom = viewport_top + parent.vadjustment.page_size;
  
      if (parent.vadjustment.value == 0 && widget_top < 0) {
        if (scroll_past_top_func != null) {
          scroll_past_top_func (parent, list_box, (int)Math.ceil(-widget_top));
        }
      }
      else if (widget_top < viewport_top) {
        parent.vadjustment.value = widget_top;
      }
      else if (widget_bottom > viewport_bottom) {
        parent.vadjustment.value = widget_bottom - parent.vadjustment.page_size;
      }
    });
  }

  public bool set_pointer_on_mouseover(Gdk.EventCrossing event){
    if (event.type == Gdk.EventType.ENTER_NOTIFY) {
      event.window.set_cursor(new Gdk.Cursor.from_name(event.window.get_display(), "pointer"));
    }
    else if (event.type == Gdk.EventType.LEAVE_NOTIFY) {
      event.window.set_cursor(null);
    }
    return Gdk.EVENT_PROPAGATE;
  }

  public bool is_animated_gif(string filepath) {
    if (filepath.has_suffix(".gif")) {
      // Be lazy and light-weight and assume GIFs are ".gif" rather than doing proper type checking
      try {
        var gif = new Gdk.PixbufAnimation.from_file(filepath);
        return !gif.is_static_image();
      }
      catch (GLib.Error e) {
        return false;
      }
    }
    else {
      return false;
    }
  }
}