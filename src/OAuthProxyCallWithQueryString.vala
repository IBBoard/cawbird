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

 public class OAuthProxyCallWithQueryString : Rest.OAuthProxyCall {
    public OAuthProxyCallWithQueryString(Rest.Proxy proxy) {
        Object(proxy: proxy);
    }

    public override bool serialize_params (out string content_type, out string content, out size_t content_len) throws Error {
        var call_params = this.get_params().as_string_hash_table();
        string[] parts = new string[call_params.length];
        int pos = 0;
        call_params.foreach((key, value) => {
            parts[pos] = "%s=%s".printf(key, value);
            pos++;
        });
        string query_string = string.joinv("&", parts);
        this.set_function("%s?%s".printf(this.get_function(), query_string));
        content_type = "text/plain";
        content = "";
        content_len = 0;
        return true;
    }
}
