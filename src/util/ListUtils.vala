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

namespace ListUtils {
  async void delete_list (Account account,
                          int64   to_rename) throws GLib.Error {
    var call = account.proxy.new_call ();
    call.set_method ("POST");
    call.set_function ("1.1/lists/subscribers/create.json");
    call.add_param ("list_id", to_rename.to_string ());
    GLib.Error? err = null;

    call.invoke_async.begin (null, (obj, res) => {
      try {
        call.invoke_async.end (res);
      } catch (GLib.Error e) {
        var tmp_err = TweetUtils.failed_request_to_error (call, e);

        if (tmp_err.domain != TweetUtils.get_error_domain() || tmp_err.code != 34) {
          err = tmp_err;
        }
      }
      delete_list.callback();
    });
    yield;
    if (err != null) {
      throw err;
    }
  }
 }