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

class ComposedTweet {
    private string _text;
    private GLib.GenericArray<MediaUpload> _uploads;
    private int64 _reply_to_id = -1;
    public int64 reply_to_id {
        get {
            return _reply_to_id;
        }
        set {
            assert(_quoted_tweet_url == null);
            _reply_to_id = value;
        }
    }
    private string? _quoted_tweet_url;

    public signal void ready();

    public ComposedTweet(string text) {
        _text = text;
        _uploads = new GLib.GenericArray<MediaUpload>(4);
    }

    public void add_attachment(MediaUpload upload) {
        upload.progress_complete.connect((message) => {
            if (message == null) {
                this.ready();
            }
        });
        _uploads.add(upload);
    }

    public MediaUpload[] get_attachments() {
        return _uploads.data;
    }

    public string get_text() {
        if (_quoted_tweet_url != null && _uploads.length > 0) {
            return "%s %s".printf(_text, get_quoted_url());
        }
        else {
            return _text;
        }
    }

    public bool has_quote_attachment() {
        return _quoted_tweet_url != null && _uploads.length == 0;
    }

    public void set_quoted_tweet(Cb.Tweet tweet) {
        assert(reply_to_id == -1);

        // We can't do this with a ternary to get the relevant mini tweet and then have one format string for that because
        // it somehow causes segfaults when the minitweet ends up having gibberish values (like an ID of 0 and thousands of media attachments!)
        if (tweet.retweeted_tweet != null) {
            _quoted_tweet_url = "https://twitter.com/%s/status/%s".printf(tweet.retweeted_tweet.author.screen_name, tweet.retweeted_tweet.id.to_string());    
        }
        else {
            _quoted_tweet_url = "https://twitter.com/%s/status/%s".printf(tweet.source_tweet.author.screen_name, tweet.source_tweet.id.to_string());
        }
     }

    public string get_quoted_url() {
        return _quoted_tweet_url == null ? "" : _quoted_tweet_url;
    }
}