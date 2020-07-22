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

public class LazyMenuButton : Gtk.Button {
  public GLib.Menu menu_model { get; set; }

  public override void clicked () {
    var popover = new Gtk.Popover.from_model (this, this.menu_model);
    popover.position = Gtk.PositionType.BOTTOM;
#if GTK322
    popover.popup ();
#else
    popover.show ();
#endif
  }
}
