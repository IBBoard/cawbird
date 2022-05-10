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

public class MultiMediaWidget : Gtk.Box {
  public const int MAX_HEIGHT = 180;
  private bool __restrict_height = false;
  public bool restrict_height{
    get {
      return this.__restrict_height;
    }
    set {
      this.__restrict_height = value;
      this.set_size_request(-1, value ? MAX_HEIGHT : -1);
    }
  }
  private MediaButton[] media_buttons;
  private int media_count = 0;

  public signal void media_clicked (Cb.Media m, int index, double px, double py);
  private bool media_invalid_fired = false;
  public signal void media_invalid ();

  construct {
    this.orientation = Gtk.Orientation.HORIZONTAL;
    this.homogeneous = true;
    this.spacing = 2;
  }

  public MultiMediaWidget () {
    this.notify["visible"].connect(() => {
      if (!this.visible) {
        return;
      }

      for (int i = 0; i < media_count; i ++) {
        if (media_buttons[i] != null) {
          var media = media_buttons[i].media;
          if (!media.loaded && !media.loading) {
            Cb.MediaDownloader.get_default().load_async.begin (media);
          }
        }
      }
    });
  }

  public void set_all_media (Cb.Media[] medias) {
    this.remove_all ();
    this.media_buttons = new MediaButton[medias.length];
    this.media_count = medias.length;

    for (int i = 0; i < medias.length; i++) {
      assert (medias[i] != null);
      set_media (i, medias[i]);
    }
  }

  private void remove_all () {
    this.get_children ().foreach ((w) => {
      this.remove (w);
    });
  }

  public void set_media (int index, Cb.Media media) {
    assert (index < media_count);

    if (media.loaded && media.invalid)
      return;

    var button = new MediaButton (media, this.restrict_height);
    button.set_data ("pos", index);
    button.halign = Gtk.Align.CENTER;
    button.valign = Gtk.Align.END;
    media_buttons[index] = button;

    if (!media.loaded) {
      media.progress.connect (media_loaded_cb);

      if (!media.loading && this.visible) {
        Cb.MediaDownloader.get_default().load_async.begin (media);
      }
    }
    button.visible = true;
    button.clicked.connect (button_clicked_cb);
    this.pack_start (button, true, true);
    this.queue_draw ();
  }

  private void button_clicked_cb (MediaButton source, double px, double py) {
    if (source.media != null && source.media.loaded) {
      int index = source.get_data ("pos");
      media_clicked (source.media, index, px, py);
    }
  }


  private void media_loaded_cb (Cb.Media source) {
    if (source.percent_loaded < 1)
      return;

    if (source.invalid) {
      if (!media_invalid_fired) {
        media_invalid ();
        media_invalid_fired = true;
      }
      return;
    }

    for (int i = 0; i < media_count; i ++) {
      if (media_buttons[i] != null && media_buttons[i].media == source) {
        media_buttons[i].queue_draw ();
        break;
      }
    }
  }

}

