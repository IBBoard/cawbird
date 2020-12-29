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

public class TweetListBox : ListBox {
  public Cb.DeltaUpdater delta_updater;
  public unowned Account account;
  public Cb.TweetModel model = new Cb.TweetModel ();
  private Gtk.GestureMultiPress press_gesture;
  private TweetListEntry? _action_entry;
  public TweetListEntry? action_entry {
    get {
      return _action_entry;
    }
  }
  public MainWindow main_window { private get; set; }

  public TweetListBox () {
  }

  construct {
    this.press_gesture = new Gtk.GestureMultiPress (this);
    this.press_gesture.set_button (0);
    this.press_gesture.set_propagation_phase (Gtk.PropagationPhase.BUBBLE);
    this.press_gesture.pressed.connect (gesture_pressed_cb);
    this.delta_updater = new Cb.DeltaUpdater (this);

    Cb.Utils.bind_model (this, this.model, widget_create_func);
  }

  public void set_thread_mode (bool thread_mode) {
    this.model.set_thread_mode (thread_mode);
  }

  private Gtk.Widget widget_create_func (GLib.Object obj) {
    assert (obj is Cb.Tweet);

    var row = new TweetListEntry ((Cb.Tweet) obj,
                                  main_window,
                                  this.account);
    row.fade_in ();
    return row;
  }

  private void gesture_pressed_cb (int    n_press,
                                   double x,
                                   double y) {
    Gdk.EventSequence sequence = this.press_gesture.get_current_sequence ();
    Gdk.EventButton event = (Gdk.EventButton)this.press_gesture.get_last_event (sequence);

    if (event.triggers_context_menu ()) {
      /* From gtklistbox.c */
      Gdk.Window? event_window = event.window;
      Gdk.Window window = this.get_window ();
      double relative_y = event.y;
      double parent_y;

      while ((event_window != null) && (event_window != window)) {
        event_window.coords_to_parent (0, relative_y, null, out parent_y);
        relative_y = parent_y;
        event_window = event_window.get_effective_parent ();
      }
      Gtk.Widget row = this.get_row_at_y ((int)relative_y);
      if (row is TweetListEntry && row.sensitive) {
        var tle = (TweetListEntry) row;
        if (tle != this._action_entry && this._action_entry != null &&
            this._action_entry.shows_actions) {
          this._action_entry.toggle_mode ();
        }
        tle.toggle_mode ();
        if (tle.shows_actions)
          set_action_entry (tle);
        else
          set_action_entry (null);

        this.press_gesture.set_state (Gtk.EventSequenceState.CLAIMED);
      }
    }
  }

  private void set_action_entry (TweetListEntry? entry) {
    if (this._action_entry != null) {
      this._action_entry.destroy.disconnect (action_entry_destroyed_cb);
      this._action_entry = null;
    }

    if (entry != null) {
      this._action_entry = entry;
      this._action_entry.destroy.connect (action_entry_destroyed_cb);
    }
  }

  private void action_entry_destroyed_cb () {
    this._action_entry = null;
  }

  public new void remove_all () {
    this.model.clear();
  }

  public void hide_tweets_from (int64 user_id, Cb.TweetState reason) {
    model.toggle_flag_on_user_tweets (user_id, reason, true);
  }

  public void show_tweets_from (int64 user_id, Cb.TweetState reason) {
    model.toggle_flag_on_user_tweets (user_id, reason, false);
  }

  public void hide_retweets_from (int64 user_id, Cb.TweetState reason) {
    model.toggle_flag_on_user_retweets (user_id, reason, true);
  }

  public void show_retweets_from (int64 user_id, Cb.TweetState reason) {
    model.toggle_flag_on_user_retweets (user_id, reason, false);
  }
}
