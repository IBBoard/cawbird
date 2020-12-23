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
        return fileinfo.get_content_type ();
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
            if (Utils.is_animated_gif(filepath)) {
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
  
    public MediaUpload(string filepath, bool for_dm = false) throws GLib.Error {
      id = GLib.Uuid.string_random();
      file = File.new_for_path(filepath);
      fileinfo = file.query_info(GLib.FileAttribute.STANDARD_TYPE + "," +
                                 GLib.FileAttribute.STANDARD_CONTENT_TYPE + "," +
                                 GLib.FileAttribute.STANDARD_SIZE, 0);
      dm = for_dm;
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