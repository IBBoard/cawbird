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

public class CollectById : GLib.Object {
    private GLib.GenericSet<string> ids;
    private GLib.Error? error = null;

    public bool done {
        get {
            return ids.length == 0;
        }
    }

    public bool errored {
        get {
            return error != null;
        }
    }

    public signal void finished (GLib.Error? error);

    public CollectById ()
    {
        ids = new GLib.GenericSet<string>(GLib.str_hash, GLib.str_equal, null);
    }

    public void add(string id) {
        ids.add(id);
    }

    public void emit (string id, GLib.Error? error = null)
    {
        /* If our global error is set, something previously went wrong and we ignore
            this call to emit(); */
        if (this.error != null) {
            return;
        }

        /* If error is set, we call finished() with that error and ignore all
            following calls to emit() */
        if (error != null) {
            finished (error);
            this.error = error;
            return;
        }

        ids.remove(id);

        if (done) {
            finished (null);
        }
    }
}
  