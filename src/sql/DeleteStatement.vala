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

namespace Sql {
    public class DeleteStatement : Sql.BaseStatement<Sql.DeleteStatement> {
        private bool ran = false;
    
        public DeleteStatement (string table_name) {
            query_builder.append ("DELETE FROM `").append (table_name).append ("` ");
        }
    
        public int run () {
            if (!where_set) {
                critical ("Bare DELETE statements are not allowed!");
                return -1;
            }
            Sqlite.Statement stmt;
            query_builder.append(";");
            int ok = db.prepare_v2 (query_builder.str, -1, out stmt);
    
            if (ok != Sqlite.OK) {
                critical (db.errmsg ());
                return -1;
            }
            for (int i = 0; i < bindings.length; i++) {
                stmt.bind_text (i + 1, bindings.get (i));
            }
            ok = stmt.step ();
            if (ok == Sqlite.ERROR) {
                critical (db.errmsg ());
                critical (stmt.sql ());
                return -1;
            }
            ran = true;
            return db.changes ();
        }

#if DEBUG
        ~DeleteStatement () {
            if (!ran)
            critical ("UpdateStatement for %s did not run.", query_builder.str);
        }
#endif
    }
}