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

class ComposeImageManager : Gtk.Container {
  private const int BUTTON_DELTA = 10;
  private const int BUTTON_SPACING = 12;
  private GLib.GenericArray<AddImageButton> buttons;
  private GLib.GenericArray<MediaUpload> uploads;
  private GLib.GenericArray<Gtk.Button> close_buttons;
  private GLib.GenericArray<Gtk.Button> desc_buttons;
  private GLib.GenericArray<Gtk.ProgressBar> progress_bars;

  public Rest.OAuthProxy proxy;

  public int n_images {
    get {
      return this.buttons.length;
    }
  }

  public int max_images { get; set; default = Twitter.max_media_per_upload; }

  // Is there an *animated* GIF?
  public bool has_gif {
    get {
      for (int i = 0; i < uploads.length; i ++) {
        if (uploads.get (i).media_category.has_suffix("gif")) {
          return true;
        }
      }
      return false;

    }
  }
  public bool has_video {
    get {
      for (int i = 0; i < uploads.length; i ++) {
        if (uploads.get (i).media_category.has_suffix("video")) {
          return true;
        }
      }
      return false;

    }
  }
  public bool full {
    get {
      return this.buttons.length == max_images ||
             this.has_gif || this.has_video;
    }
  }

  public signal void image_removed (MediaUpload upload);
  public signal void image_reloaded (MediaUpload upload);
  public signal void image_uploaded (MediaUpload upload);

  construct {
    this.buttons = new GLib.GenericArray<AddImageButton> ();
    this.uploads = new GLib.GenericArray<MediaUpload> ();
    this.close_buttons = new GLib.GenericArray<Gtk.Button> ();
    this.desc_buttons = new GLib.GenericArray<Gtk.Button> ();
    this.progress_bars = new GLib.GenericArray<Gtk.ProgressBar> ();
    this.set_has_window (false);
  }

  public MediaUpload[] get_uploads() {
    return uploads.data;
  }

  public void clear() {
    for (int i = this.buttons.length - 1; i >= 0; i--) {
      remove_index(i, false);
    }
  }

  private void remove_index (int index, bool animate) {
    this.close_buttons.get (index).hide ();
    this.desc_buttons.get (index).hide ();
    this.progress_bars.get (index).hide ();

    AddImageButton aib = (AddImageButton) this.buttons.get (index);
    aib.deleted.connect (() => {
      this.buttons.remove_index (index);
      var upload = this.uploads.get(index);
      this.uploads.remove_index (index);
      this.close_buttons.remove_index (index);
      this.desc_buttons.remove_index (index);
      this.progress_bars.remove_index (index);
      this.queue_draw ();
      this.image_removed (upload);
    });

    this.uploads.get(index).cancellable.cancel();
    if (animate) {
      aib.start_remove ();
    }
    else {
      aib.deleted();
    }
  }

  private void remove_clicked_cb (Gtk.Button source) {
    int index = -1;

    for (int i = 0; i < this.close_buttons.length; i ++) {
      if (close_buttons.get (i) == source) {
        index = i;
        break;
      }
    }
    assert (index >= 0);
    remove_index(index, true);
  }

  private void image_description_button_clicked(Gtk.Button source) {
    int index = -1;

    for (int i = 0; i < this.desc_buttons.length; i ++) {
      if (desc_buttons.get (i) == source) {
        index = i;
        break;
      }
    }
    assert (index >= 0);
    
    var image_button = this.buttons.get(index);
    assert (image_button.surface != null);
    ImageDescriptionWindow description_window = new ImageDescriptionWindow((Gtk.Window)this.get_toplevel(), proxy, image_button.media_id, image_button.description, image_button.surface);
    description_window.description_updated.connect((media_id, description) => { image_button.description = description; });
    description_window.hide.connect(() => { description_window.destroy(); });
    description_window.show();
  }

  private void reupload_image_cb (Gtk.Button source) {
    AddImageButton aib = (AddImageButton) source;
    if (!aib.get_style_context ().has_class ("image-error")) {
      return;
    }

    int index = -1;

    for (int i = 0; i < this.desc_buttons.length; i ++) {
      if (desc_buttons.get (i) == source) {
        index = i;
        break;
      }
    }
    assert (index >= 0);

    aib.clicked.disconnect (reupload_image_cb);
    this.image_reloaded (uploads.get(index));
  }

  // GtkContainer API {{{
  public override void forall_internal (bool include_internals, Gtk.Callback cb) {
    assert (buttons.length == close_buttons.length);
    assert (buttons.length == desc_buttons.length);
    assert (buttons.length == progress_bars.length);

    for (int i = 0; i < this.close_buttons.length;) {
      int size_before = this.close_buttons.length;
      cb (close_buttons.get (i));

      i += this.close_buttons.length - size_before + 1;
    }

    for (int i = 0; i < this.desc_buttons.length;) {
      int size_before = this.desc_buttons.length;
      cb (desc_buttons.get (i));

      i += this.desc_buttons.length - size_before + 1;
    }

    for (int i = 0; i < this.progress_bars.length;) {
      int size_before = this.progress_bars.length;
      cb (progress_bars.get (i));

      i += this.progress_bars.length - size_before + 1;
    }

    for (int i = 0; i < this.buttons.length;) {
      int size_before = this.buttons.length;
      cb (buttons.get (i));

      i += this.buttons.length - size_before + 1;
    }
  }

  public override void add (Gtk.Widget widget) {
    widget.set_parent (this);
    this.buttons.add ((AddImageButton)widget);
    var btn = new Gtk.Button.from_icon_name ("window-close-symbolic");
    btn.set_parent (this);
    btn.get_style_context ().add_class ("image-button");
    btn.get_style_context ().add_class ("close-button");
    btn.get_accessible().set_name(_("Remove image"));
    btn.clicked.connect (remove_clicked_cb);
    btn.show ();
    this.close_buttons.add (btn);

    var bar = new Gtk.ProgressBar ();
    bar.set_parent (this);
    bar.get_accessible().set_name(_("Image upload progress"));
    bar.show_all ();
    this.progress_bars.add (bar);

    var desc_btn = new Gtk.Button.from_icon_name("cawbird-compose-symbolic");
    desc_btn.set_parent(this);
    desc_btn.get_style_context ().add_class ("image-button");
    desc_btn.get_accessible().set_name(_("Describe image"));
    desc_btn.clicked.connect(image_description_button_clicked);
    desc_btn.sensitive = false;
    desc_btn.show();
    this.desc_buttons.add(desc_btn);
  }

  public override void remove (Gtk.Widget widget) {
    widget.unparent ();
    if (widget is AddImageButton)
      this.buttons.remove ((AddImageButton)widget);
    else if (widget is Gtk.Button) {
      // We only have up to four widgets, so be lazy and try removing from both lists.
      this.close_buttons.remove ((Gtk.Button)widget);
      this.desc_buttons.remove((Gtk.Button) widget);
    }
    else
      this.progress_bars.remove ((Gtk.ProgressBar)widget);
  }
  // }}}

  // GtkWidget API {{{
  public override Gtk.SizeRequestMode get_request_mode () {
    return Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH;
  }

  public override void size_allocate (Gtk.Allocation allocation) {
    base.size_allocate (allocation);
    Gtk.Allocation child_allocation = {};

    if (this.buttons.length == 0) return;


    int default_button_width = (allocation.width - (buttons.length * BUTTON_SPACING)) /
                               buttons.length;

    child_allocation.x = allocation.x;
    child_allocation.y = allocation.y + BUTTON_DELTA;
    child_allocation.height = int.max (allocation.height - 2 * BUTTON_DELTA, 0);

    Gtk.Allocation close_allocation = {};
    close_allocation.y = allocation.y;
    Gtk.Allocation desc_allocation = {};

    for (int i = 0, p = this.buttons.length; i < p; i ++) {
      int min, nat;

      /* Actual image button */
      AddImageButton aib = this.buttons.get (i);
      aib.get_preferred_width_for_height (child_allocation.height, out min, out nat);

      child_allocation.width = int.min (default_button_width, nat);
      aib.size_allocate (child_allocation);


      /* Remove button */
      int n;
      Gtk.Widget btn = this.close_buttons.get (i);
      btn.get_preferred_width (out close_allocation.width, out n);
      btn.get_preferred_height (out close_allocation.height, out n);
      close_allocation.x = child_allocation.x + child_allocation.width
                           - close_allocation.width + BUTTON_DELTA;
      btn.size_allocate (close_allocation);

      Gtk.Widget desc_btn = this.desc_buttons.get (i);
      desc_btn.get_preferred_width (out desc_allocation.width, out n);
      desc_btn.get_preferred_height (out desc_allocation.height, out n);
      desc_allocation.x = child_allocation.x + child_allocation.width
                           - desc_allocation.width + BUTTON_DELTA;
      desc_allocation.y = allocation.y + allocation.height - desc_allocation.height;
      desc_btn.size_allocate (desc_allocation);

      /* Progress bar */
      int button_width, button_height;
      double scale;
      aib.get_draw_size (out button_width, out button_height, out scale);
      Gtk.Widget bar = this.progress_bars.get (i);
      Gtk.Allocation bar_allocation = {0};
      bar_allocation.x = child_allocation.x + 6;
      bar.get_preferred_width (out bar_allocation.width, out n);
      bar_allocation.width = int.max (button_width - 12, bar_allocation.width);
      bar.get_preferred_height (out bar_allocation.height, out n);
      bar_allocation.y = child_allocation.y + (child_allocation.height + bar_allocation.height) / 2;

      bar.size_allocate (bar_allocation);

      child_allocation.x += child_allocation.width + BUTTON_SPACING;
    }
  }

  public override void get_preferred_height_for_width (int     width,
                                                       out int minimum,
                                                       out int natural) {
    int min = 0;
    int nat = 0;
    for (int i = 0; i < buttons.length; i ++) {
      var btn = buttons.get (i);
      int m, n;
      btn.get_preferred_height_for_width (width, out m, out n);
      min = int.max (m, min);
      nat = int.max (n, nat);
    }

    /* We subtract BUTTON_DELTA in size_allocate again */
    minimum = min + 2 * BUTTON_DELTA;
    natural = nat + 2 * BUTTON_DELTA;
  }

  public override void get_preferred_height (out int minimum,
                                             out int natural) {
    int min = 0;
    int nat = 0;
    for (int i = 0; i < buttons.length; i ++) {
      var btn = buttons.get (i);
      int m, n;
      btn.get_preferred_height (out m, out n);
      min = int.max (m, min);
      nat = int.max (n, nat);
    }

    /* We subtract BUTTON_DELTA in size_allocate again */
    minimum = min + 2 * BUTTON_DELTA;
    natural = nat + 2 * BUTTON_DELTA;
  }

  public override void get_preferred_width (out int minimum,
                                            out int natural) {
    int min = 0;
    int nat = 0;
    for (int i = 0; i < buttons.length; i ++) {
      var btn = buttons.get (i);
      int m, n;
      btn.get_preferred_width (out m, out n);
      min += m;
      nat += n;
    }

    minimum = min + (buttons.length * BUTTON_SPACING);
    natural = nat + (buttons.length * BUTTON_SPACING);
  }

  public override bool draw (Cairo.Context ct) {
    for (int i = 0, p = this.buttons.length; i < p; i ++) {
      Gtk.Widget btn = this.buttons.get (i);
      this.propagate_draw (btn, ct);
    }

    for (int i = 0, p = this.close_buttons.length; i < p; i ++) {
      var btn = this.close_buttons.get (i);
      this.propagate_draw (btn, ct);
    }

    for (int i = 0, p = this.desc_buttons.length; i < p; i ++) {
      var btn = this.desc_buttons.get (i);
      this.propagate_draw (btn, ct);
    }

    for (int i = 0, p = this.progress_bars.length; i < p; i ++) {
      var bar = this.progress_bars.get (i);
      this.propagate_draw (bar, ct);
    }

    return Gdk.EVENT_PROPAGATE;
  }
  // }}}

  public string load_media (MediaUpload upload) {
#if DEBUG
    assert (!this.full);
#endif

    upload.progress_updated.connect ((progress) => {
      set_image_progress (upload.id, progress);
    });
    upload.progress_complete.connect ((error) => {
      end_progress (upload.id, error);
    });
    upload.media_id_assigned.connect(() => {
      set_media_id(upload.id);
    });

    this.uploads.add(upload);

    Cairo.ImageSurface surface;
    if (upload.media_category.has_suffix("video")) {
      surface = (Cairo.ImageSurface)load_surface_for_video (upload.filepath);
    }
    else {
      surface = (Cairo.ImageSurface)load_surface (upload.filepath);
    }

    var button = new AddImageButton (upload);
    button.surface = surface;

    button.hexpand = false;
    button.halign = Gtk.Align.START;
    button.show ();
    this.add (button);
    return button.uuid;
  }

  private void set_image_progress (string uuid, double progress) {
    for (int i = 0; i < buttons.length; i ++) {
      var btn = buttons.get (i);
      if (btn.uuid == uuid) {
        var progress_bar = progress_bars.get (i);
        progress_bar.set_fraction (progress);
        break;
      }
    }
  }

  private void end_progress (string uuid, GLib.Error? error) {
    for (int i = 0; i < buttons.length; i ++) {
      var btn = buttons.get (i);
      if (btn.uuid == uuid) {
        image_uploaded (uploads[i]);
        progress_bars.get(i).hide();
        var style_context = btn.get_style_context ();
        style_context.remove_class ("image-progress");

        if (error == null) {
          style_context.add_class ("image-success");
          style_context.remove_class ("image-error");
        } else {
          warning ("%s: %s", btn.image_path, error.message);
          style_context.add_class ("image-error");
          style_context.remove_class ("image-success");
          btn.clicked.connect (reupload_image_cb);
        }
        break;
      }
    }
  }

  public bool is_ready () {
    for (int i = 0; i < uploads.length; i++) {
      if (!uploads[i].is_uploaded()) {
        return false;
      }
    }
    return true;
  }

  public void set_media_id(string uuid) {
    for (int i = 0; i < buttons.length; i ++) {
      var btn = buttons.get (i);
      if (btn.uuid == uuid) {
        desc_buttons.get(i).sensitive = true;
        break;
      }
    }
  }

  public void insensitivize_buttons () {
    for (int i = 0; i < close_buttons.length; i ++) {
      close_buttons.get (i).set_sensitive (false);
    }
  }

  public void sensitivize_buttons () {
    for (int i = 0; i < close_buttons.length; i ++) {
      close_buttons.get (i).set_sensitive (true);
    }
  }
}
