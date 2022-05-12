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

 private class MediaButtonSurface : Gtk.Widget {
    private const int PLAY_ICON_SIZE = 32;
    private const int MAX_HEIGHT     = 200;
    /* We use MIN_ constants in case the media has not yet been loaded */
    private const int MIN_WIDTH      = 40;
    private Gdk.Window? event_window = null;
    private Cb.Media? _media = null;
    private static Cairo.Surface[] play_icons;
    public Cb.Media? media {
      get {
        return _media;
      }
      set {
        if (_media != null) {
          _media.progress.disconnect (media_progress_cb);
        }
        _media = value;
        if (value != null) {
          if (!media.loaded) {
            _media.progress.connect (media_progress_cb);
          } else {
            this.media_alpha = 1.0;
          }
        }
      }
    }
    private Pango.Layout layout;
    private Gtk.GestureMultiPress press_gesture;
    private bool restrict_height = false;
    private int64 fade_start_time;
    private double media_alpha = 0.0;

    public signal void clicked (MediaButtonSurface source, double px, double py);

    static construct {
      try {
        play_icons = {
          Gdk.cairo_surface_create_from_pixbuf (
            new Gdk.Pixbuf.from_resource ("/uk/co/ibboard/cawbird/data/play.png"), 1, null),
          Gdk.cairo_surface_create_from_pixbuf (
            new Gdk.Pixbuf.from_resource ("/uk/co/ibboard/cawbird/data/play@2.png"), 2, null),
        };
      } catch (GLib.Error e) {
        critical (e.message);
      }
    }

    construct {
      this.set_has_window (false);
    }

    ~MediaButtonSurface () {
      if (_media != null) {
        _media.progress.disconnect (media_progress_cb);
      }
    }

    public MediaButtonSurface (Cb.Media? media, bool restrict_height = false) {
      this.media = media;
      this.restrict_height = restrict_height;
      this.get_style_context ().add_class ("inline-media");

      this.layout = this.create_pango_layout ("0%");
      this.press_gesture = new Gtk.GestureMultiPress (this);
      this.press_gesture.set_exclusive (true);
      this.press_gesture.set_button (0);
      this.press_gesture.released.connect (gesture_released_cb);
      this.enter_notify_event.connect(Utils.set_pointer_on_mouseover);
      this.leave_notify_event.connect(Utils.set_pointer_on_mouseover);
    }

    private void media_progress_cb () {
      this.queue_draw ();

      if (this._media.loaded) {
        if (!_media.invalid && _media.surface != null) {
          this.start_fade ();
        }

        this.queue_resize ();
      }
    }

    private bool fade_in_cb (Gtk.Widget widget, Gdk.FrameClock frame_clock) {
      if (!this.get_mapped ()) {
        this.media_alpha = 1.0;
        return GLib.Source.REMOVE;
      }

      int64 now = frame_clock.get_frame_time ();
      double t = 1.0;
      if (now < this.fade_start_time + TRANSITION_DURATION)
        t = (now - fade_start_time) / (double)(TRANSITION_DURATION );

      t = ease_out_cubic (t);

      this.media_alpha = t;
      this.queue_draw ();
      if (t >= 1.0) {
        this.media_alpha = 1.0;
        return GLib.Source.REMOVE;
      }

      return GLib.Source.CONTINUE;
    }

    private void start_fade () {
      assert (this.media != null);
      assert (this.media.surface != null);

      if (!this.get_realized () || !this.get_mapped () ||
          !Gtk.Settings.get_default ().gtk_enable_animations) {
        this.media_alpha = 1.0;
        return;
      }

      this.fade_start_time = this.get_frame_clock ().get_frame_time ();
      this.add_tick_callback (fade_in_cb);
    }

    public override bool draw (Cairo.Context ct) {
      int widget_width = get_allocated_width ();
      int widget_height = get_allocated_height ();

      if (_media != null && _media.invalid) {
        return base.draw(ct);
      }
      else if (_media != null && _media.surface != null && _media.loaded) {
        /* Draw thumbnail */
        int draw_x, draw_y;
        double scale;
        Utils.calculate_draw_offset (_media.thumb_width, _media.thumb_height,
                                     get_allocated_width(), get_allocated_height(),
                                     out draw_x, out draw_y, out scale);

        var draw_width = get_allocated_width() - draw_x;
        var draw_height = get_allocated_height() - draw_y;

        ct.save ();
        ct.rectangle (0, 0, widget_width, widget_height);
        ct.scale (scale, scale);
        ct.set_source_surface (media.surface, draw_x / scale, draw_y / scale);
        ct.paint_with_alpha (this.media_alpha);
        ct.restore ();
        ct.new_path ();

        /*
         * If image got moved off the top, we cropped it. Indicate that.
         * Currently trying a gradient overlay top and bottom
         */
        if (draw_y < 0) {
          Cairo.Pattern pattern = new Cairo.Pattern.linear (0.0, 0.0, 0, widget_height);
          pattern.add_color_stop_rgba (0.01, 0.3, 0.3, 0.3, 1);
          pattern.add_color_stop_rgba (0.1, 0.7, 0.7, 0.7, 0);
          pattern.add_color_stop_rgba (0.9, 0.7, 0.7, 0.7, 0);
          pattern.add_color_stop_rgba (0.99, 0.3, 0.3, 0.3, 1);
          ct.rectangle (0, 0, widget_width, widget_height);
          ct.set_source (pattern);
          ct.fill ();
        }

        /* Draw play indicator */
        if (_media.is_video ()) {
          int x = (widget_width  / 2) - (PLAY_ICON_SIZE / 2);
          int y = (widget_height / 2) - (PLAY_ICON_SIZE / 2);

          ct.save ();
          ct.rectangle (x, y, PLAY_ICON_SIZE, PLAY_ICON_SIZE);
          ct.set_source_surface (play_icons[this.get_scale_factor () == 1 ? 0 : 1], x, y);
          ct.paint_with_alpha (this.media_alpha);
          ct.restore ();
          ct.new_path ();
        }

        if (media.alt_text != null && media.alt_text != "") {
          Gtk.IconTheme icon_theme = Gtk.IconTheme.get_default();
          int icon_size = 24;
          try {
            Gdk.Pixbuf pixbuf = icon_theme.load_icon_for_scale ("dialog-information", icon_size, this.get_scale_factor(), Gtk.IconLookupFlags.USE_BUILTIN);
            var icon = Gdk.cairo_surface_create_from_pixbuf (pixbuf, this.get_scale_factor(), null);
            ct.set_source_surface (icon, draw_x / scale, widget_height - icon_size * this.get_scale_factor());
            ct.paint();
          } catch (GLib.Error e) {
            warning(e.message);
          }
        }

        var sc = this.get_style_context ();
        sc.render_background (ct, draw_x, 0, draw_width, draw_height);
        sc.render_frame      (ct, draw_x, 0, draw_width, draw_height);

        if (this.has_visible_focus ()) {
          sc.render_focus (ct, draw_x + 2, 2, draw_width - 4, draw_height - 4);
        }
      } else {
        var sc = this.get_style_context ();
        double layout_x, layout_y;
        int layout_w, layout_h;
        layout.set_text ("%d%%".printf ((int)(_media.percent_loaded * 100)), -1);
        layout.get_size (out layout_w, out layout_h);
        layout_x = (widget_width / 2.0) - (layout_w / Pango.SCALE / 2.0);
        layout_y = (widget_height / 2.0) - (layout_h / Pango.SCALE / 2.0);
        sc.render_layout (ct, layout_x, layout_y, layout);
      }

      return Gdk.EVENT_PROPAGATE;
    }

    public override Gtk.SizeRequestMode get_request_mode () {
      return Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH;
    }

    public override void get_preferred_height (out int minimum,
                                               out int natural) {
      int media_height;
      if (this._media == null || this._media.thumb_height == -1) {
        media_height = 1;
      } else {
        media_height = this._media.thumb_height;
      }

      if (restrict_height) {
        minimum = int.min (media_height, MAX_HEIGHT);
      }
      else {
        minimum = media_height;
      }

      natural = media_height;
    }

    public override void get_preferred_height_for_width (int width,
                                                         out int minimum,
                                                         out int natural) {
      int media_width;
      int media_height;

      if (this._media == null || this._media.thumb_width == -1 || this._media.thumb_height == -1) {
        media_width = MIN_WIDTH;
        media_height = MAX_HEIGHT;
      } else {
        media_width = this._media.thumb_width;
        media_height = this._media.thumb_height;
      }

      double scale = width / (double) media_width;

      int height = 0;

      if (scale >= 1) {
        height = int.min (media_height, (int) Math.floor ((width / 9.0) * 16));
      } else {
        height = (int) Math.floor (double.min (media_height * scale, (media_width * scale / 9.0) * 16));
      }

      if (restrict_height) {
        height = int.min (height, MAX_HEIGHT);
      }

      minimum = natural = height;
    }

    public override void get_preferred_width_for_height (int height,
                                                         out int minimum,
                                                         out int natural) {
      int media_width;
      int media_height;

      if (this._media == null || this._media.thumb_width == -1 || this._media.thumb_height == -1) {
        media_width = MIN_WIDTH;
        media_height = MAX_HEIGHT;
      } else {
        media_width = this._media.thumb_width;
        media_height = this._media.thumb_height;
      }

      int max_width = (int) Math.floor ((height / 16.0) * 9);
      int width = int.min (media_width, max_width);
      minimum = MIN_WIDTH;
      natural = int.max (width, minimum);
    }

    public override void get_preferred_width (out int minimum,
                                              out int natural) {
      int media_width;
      if (this._media == null || this._media.thumb_width == -1) {
        media_width = 1;
      } else {
        media_width = this._media.thumb_width;
      }

      minimum = int.min (media_width, MIN_WIDTH);
      natural = media_width;
    }

    public override void realize () {
      this.set_realized (true);

      Gdk.WindowAttr attr = {};
      attr.x = 0;
      attr.y = 0;
      attr.width = get_allocated_width();
      attr.height = get_allocated_height();
      attr.window_type = Gdk.WindowType.CHILD;
      attr.visual = this.get_visual ();
      attr.wclass = Gdk.WindowWindowClass.INPUT_ONLY;
      attr.event_mask = this.get_events () |
                        Gdk.EventMask.BUTTON_PRESS_MASK |
                        Gdk.EventMask.BUTTON_RELEASE_MASK |
                        Gdk.EventMask.TOUCH_MASK |
                        Gdk.EventMask.ENTER_NOTIFY_MASK |
                        Gdk.EventMask.LEAVE_NOTIFY_MASK;

      Gdk.WindowAttributesType attr_mask = Gdk.WindowAttributesType.X |
                                           Gdk.WindowAttributesType.Y;
      Gdk.Window window = this.get_parent_window ();
      this.set_window (window);
      window.ref ();

      this.event_window = new Gdk.Window (window, attr, attr_mask);
      this.register_window (this.event_window);
    }

    public override void unrealize () {
      if (this.event_window != null) {
        this.unregister_window (this.event_window);
        this.event_window.destroy ();
        this.event_window = null;
      }
      base.unrealize ();
    }

    public override void map () {
      base.map ();

      if (this.event_window != null)
        this.event_window.show ();
    }

    public override void unmap () {

      if (this.event_window != null)
        this.event_window.hide ();

      base.unmap ();
    }

    public override void size_allocate (Gtk.Allocation alloc) {
      base.size_allocate (alloc);

      if (this.get_realized ()) {
        this.event_window.move_resize (alloc.x, alloc.y, alloc.width, alloc.height);
      }
    }

    public override bool enter_notify_event (Gdk.EventCrossing evt) {
      if (evt.window == this.event_window &&
          evt.detail != Gdk.NotifyType.INFERIOR) {
        this.set_state_flags (this.get_state_flags () | Gtk.StateFlags.PRELIGHT,
                              true);
      }

      return Gdk.EVENT_PROPAGATE;
    }

    public override bool leave_notify_event (Gdk.EventCrossing evt) {
      if (evt.window == this.event_window &&
          evt.detail != Gdk.NotifyType.INFERIOR) {
        this.set_state_flags (this.get_state_flags () & ~Gtk.StateFlags.PRELIGHT,
                              true);
      }

      return Gdk.EVENT_PROPAGATE;
    }

    private void gesture_released_cb (int    n_press,
                                      double x,
                                      double y) {
      Gdk.EventSequence sequence = this.press_gesture.get_current_sequence ();
      Gdk.Event event = this.press_gesture.get_last_event (sequence);
      uint button = this.press_gesture.get_current_button ();

      if (this._media == null || event == null)
        return;

      if (button == Gdk.BUTTON_PRIMARY) {
        this.press_gesture.set_state (Gtk.EventSequenceState.CLAIMED);
        double px = x / (double)this.get_allocated_width ();
        double py = y / (double)this.get_allocated_height ();
        this.clicked (this, px, py);
      }
    }

    public override bool key_press_event (Gdk.EventKey event) {
      if (event.keyval == Gdk.Key.Return ||
          event.keyval == Gdk.Key.KP_Enter) {
        this.clicked (this, 0.5, 0.5);
        return Gdk.EVENT_STOP;
      }

      return Gdk.EVENT_PROPAGATE;
    }
  }
