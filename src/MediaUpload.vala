/*  This file is part of Cawbird, a Gtk+ linux Twitter client forked from Corebird.
 *  Copyright (C) 2020 IBBoard
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
 
 class MediaUpload : GLib.Object {
    public string id { get; private set; }
    public string? filepath {
      owned get {
        return file.get_path();
      }
    }
    public string filetype {
      get {
#if MSWINDOWS
        var filename = filepath.down();
        // We can't trust Windows with mime types, it only understands extensions, so fudge something and hope for the best
        // This time we have to re-implement mime types, but based on file extensions!
        if (filename.has_suffix(".gif")) {
          return "image/gif";
        }
        else if (filename.has_suffix(".jpg") || filename.has_suffix(".jpeg")) {
          return "image/jpeg";
        }
        else if (filename.has_suffix(".webp")) {
          return "image/webp";
        }
        else if (filename.has_suffix(".png")) {
          return "image/png";
        }
        else {
          return "video/mp4";
        }
#else
        return fileinfo.get_content_type ();
#endif
      }
    }
    private string? cat;
    public string media_category {
      owned get {
        if (cat == null) {
          var prefix = dm ? "dm" : "tweet";
          if (filetype.has_prefix("video/")) {
            cat = "%s_video".printf(prefix);
          }
          else if (filetype == "image/gif") {
            // Animated GIFs are "blah_gif" but static GIFs are "blah_image"
            if (Utils.is_animated_gif(file)) {
              cat = "%s_gif".printf(prefix);
            }
            else {
              cat = "%s_image".printf(prefix);
            }
          }
          else {
            cat = "%s_image".printf(prefix);
          }
        }
        return cat;
      }
    }
    private int64 _media_id = -1;
    public int64 media_id {
      get { return _media_id; }
      set {
        _media_id = value;
        media_id_assigned();
      }
    }
    private File file;
    private FileInfo fileinfo;
    private bool dm;
    private bool delete_on_success;
    public int64 filesize {
      get {
        return fileinfo.get_size();
      }
    }
    private double _progress = 0;
    public double progress {
      get {
        return _progress;
      }
      set {
        _progress = value;
        progress_updated(_progress);
      }
    }
    private bool upload_finalized;
    public GLib.Cancellable cancellable { get; private set; }
    public signal void progress_updated(double progress);
    public signal void progress_complete(GLib.Error? error = null);
    public signal void media_id_assigned();
  
    public MediaUpload(File file, bool for_dm = false, bool delete_on_success = false) throws GLib.Error {
      id = GLib.Uuid.string_random();
      this.file = file;
      fileinfo = file.query_info(GLib.FileAttribute.STANDARD_TYPE + "," +
                                 GLib.FileAttribute.STANDARD_CONTENT_TYPE + "," +
                                 GLib.FileAttribute.STANDARD_SIZE, 0);
      dm = for_dm;
      this.delete_on_success = delete_on_success;
      if (delete_on_success) {
        progress_complete.connect(() => {
          file.delete_async.begin(10, null);
        });
      }
      cancellable = new GLib.Cancellable();
    }
  
    public FileInputStream read() throws GLib.Error {
      return file.read();
    }
  
    public void finalize_upload() {
      debug("Finalizing upload");
      progress = 1.0;
      upload_finalized = true;
      progress_complete();
    }
  
    public bool is_uploaded() {
      return upload_finalized;
    }
  }