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

public class OAuthProxyCallWithBody : Rest.OAuthProxyCall {
    private string message_content = "";

    public OAuthProxyCallWithBody(Rest.Proxy proxy, string content) {
        Object(proxy: proxy);
        message_content = content;
    }

    public override bool serialize_params (out string content_type, out string content, out size_t content_len) throws Error {
        content_type = "application/json";
        content = this.message_content;
        content_len = this.message_content.length;
        return true;
    }
}
