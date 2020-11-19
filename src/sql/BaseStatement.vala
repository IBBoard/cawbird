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
    public abstract class BaseStatement<STATEMENT_TYPE> : GLib.Object {
        public unowned Sqlite.Database db;
        protected StringBuilder query_builder = new StringBuilder ();
        protected GLib.GenericArray<string> bindings = new GLib.GenericArray<string>();
        protected bool where_set = false;

        public STATEMENT_TYPE where (string stmt) {
            if (!where_set) {
                query_builder.append (" WHERE ");
                where_set = true;
            }
            query_builder.append (stmt);
            return this;
        }

        public STATEMENT_TYPE where_eq (string field, string val) {
            where(@"`$field` = ?");
            bindings.add(val);
            return this;
        }

        public STATEMENT_TYPE where_eqi (string w, int64 v) {
            return where_eq (w, v.to_string());
        }

        public STATEMENT_TYPE where_lt (string field, int64 val) {
            where(@"`$field` < ?");
            bindings.add(val.to_string());
            return this;
        }

        public STATEMENT_TYPE where_prefix (string field, string prefix) {
            where(@"`$field` LIKE ?");
            bindings.add(prefix + "%");
            return this;
        }

        public STATEMENT_TYPE where_prefix2 (string field, string prefix) {
            return where_prefix(field, prefix);
        }

        public STATEMENT_TYPE or () {
            query_builder.append (" OR ");
            return this;
        }

        public STATEMENT_TYPE and () {
            query_builder.append (" AND ");
            return this;
        }

        public STATEMENT_TYPE nocase () {
            query_builder.append (" COLLATE NOCASE");
            return this;
        }
    }
}