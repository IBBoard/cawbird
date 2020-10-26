
void normal () {
  var entities = new Cb.TextEntity[0];
  string source_text = "foo bar foo";

  string result = Cb.TextTransform.text (source_text,
                                         entities,
                                         0,
                                         0,
                                         0);

  assert (result == source_text);
}


void simple () {
  var entities = new Cb.TextEntity[1];
  entities[0] = Cb.TextEntity () {
    from = 4,
    to   = 7,
    original_text = "bar",
    display_text = "display_text",
    tooltip_text = "tooltip_text",
    target       = "target_text"
  };

  string source_text = "foo bar foo";
  string result = Cb.TextTransform.text (source_text,
                                         entities,
                                         0,
                                         0,
                                         0);

  // Not the best asserts, but oh well
  assert (result.contains ("display_text"));
  assert (result.contains ("tooltip_text"));
  assert (result.contains ("target_text"));
}

void url_at_end () {
  var entities = new Cb.TextEntity[1];
  entities[0] = Cb.TextEntity () {
    from = 8,
    to   = 11,
    original_text = "foo",
    display_text = "display_text",
    tooltip_text = "tooltip_text",
    target       = "target_text"
  };

  string source_text = "foo bar foo";
  string result = Cb.TextTransform.text (source_text,
                                         entities,
                                         0,
                                         0,
                                         0);

  // Not the best asserts, but oh well
  assert (result.contains ("display_text"));
  assert (result.contains ("tooltip_text"));
  assert (result.contains ("target_text"));
}


void utf8 () {
  var entities = new Cb.TextEntity[1];
  entities[0] = Cb.TextEntity () {
    from = 2,
    to   = 6,
    original_text = "#foo",
    display_text = "#foo",
    tooltip_text = "#foo",
    target       = null
  };

  string source_text = "× #foo";
  string result = Cb.TextTransform.text (source_text,
                                         entities,
                                         Cb.TransformFlags.REMOVE_MEDIA_LINKS,
                                         0, 0);
  assert (result.has_prefix ("× "));
}


void expand_links () {
  var entities = new Cb.TextEntity[1];
  entities[0] = Cb.TextEntity () {
    from = 2,
    to   = 6,
    original_text = "#foo",
    display_text = "displayfoobar",
    tooltip_text = "#foo",
    target       = "target_url"
  };

  string source_text = "× #foo";
  string result = Cb.TextTransform.text (source_text,
                                         entities,
                                         Cb.TransformFlags.EXPAND_LINKS,
                                         0, 0);

  assert (result.has_prefix ("× "));
  assert (!result.contains ("displayfoobar"));
  assert (result.contains ("target_url"));
}

void multiple_links () {
  var entities = new Cb.TextEntity[4];
  entities[0] = Cb.TextEntity () {
    from = 0,
    to = 22,
    original_text = "http://t.co/O5uZwJg31k",
    display_text = "mirgehendirurlsaus.com",
    target = "http://mirgehendirurlsaus.com",
    tooltip_text = "http://mirgehendirurlsaus.com"
  };
  entities[1] = Cb.TextEntity () {
    from = 26,
    to   = 48,
    original_text = "http://t.co/BsKkxv8UG4",
    display_text = "foobar.com",
    target = "http://foobar.com",
    tooltip_text = "http://foobar.com"
  };
  entities[2] = Cb.TextEntity () {
    from = 52,
    to   = 74,
    original_text = "http://t.co/W8qs846ude",
    display_text = "hahaaha.com",
    target = "http://hahaaha.com",
    tooltip_text = "http://hahaaha.com"
  };
  entities[3] = Cb.TextEntity () {
    from = 77,
    to   = 99,
    original_text = "http://t.co/x4bKoCusvQ",
    display_text = "huehue.org",
    target = "http://huehue.org",
    tooltip_text = "http://huehue.org"
  };

  string text = "http://t.co/O5uZwJg31k    http://t.co/BsKkxv8UG4    http://t.co/W8qs846ude   http://t.co/x4bKoCusvQ";

  string result = Cb.TextTransform.text (text,
                                         entities,
                                         0, 0, 0);


  string spec = """<span underline="none">&#x2068;<a href="http://mirgehendirurlsaus.com" title="http://mirgehendirurlsaus.com">mirgehendirurlsaus.com</a>&#x2069;</span>    <span underline="none">&#x2068;<a href="http://foobar.com" title="http://foobar.com">foobar.com</a>&#x2069;</span>    <span underline="none">&#x2068;<a href="http://hahaaha.com" title="http://hahaaha.com">hahaaha.com</a>&#x2069;</span>   <span underline="none">&#x2068;<a href="http://huehue.org" title="http://huehue.org">huehue.org</a>&#x2069;</span>""";

  assert (result == spec);
}


void remove_only_trailing_hashtags () {
  string text = "Hey, #totally inappropriate @baedert! #baedertworship öä #thefeels   ";

  var entities = new Cb.TextEntity[4];

  entities[0] = Cb.TextEntity () {
    from = 5,
    to = 13,
    original_text = "#totally",
    display_text = "#totally",
    target = "foobar"
  };

  entities[1] = Cb.TextEntity () {
    from = 28,
    to = 36,
    original_text = "@baedert",
    display_text = "@baedert",
    target = "blubb"
  };

  entities[2] = Cb.TextEntity () {
    from = 38,
    to = 53,
    original_text = "#baedertworship",
    display_text = "#baedertworship",
    target = "bla"
  };

  entities[3] = Cb.TextEntity () {
    from = 57,
    to = 66,
    original_text = "#thefeels",
    display_text = "#thefeels",
    target = "foobar"
  };

  string result = Cb.TextTransform.text (text,
                                         entities,
                                         Cb.TransformFlags.REMOVE_TRAILING_HASHTAGS,
                                         0, 0);

  assert (result.contains (">@baedert<")); // Mention should still be a link
  assert (result.contains (">#totally<"));
  assert (result.contains ("#baedertworship"));
  assert (!result.contains ("#thefeels"));
}

void remove_multiple_trailing_hashtags () {
  string text = "Hey, #totally inappropriate @baedert! #baedertworship #thefeels #foobar";

  var entities = new Cb.TextEntity[5];

  entities[0] = Cb.TextEntity () {
    from = 5,
    to = 13,
    original_text = "#totally",
    display_text = "#totally",
    target = "foobar"
  };

  entities[1] = Cb.TextEntity () {
    from = 28,
    to = 36,
    original_text = "@baedert",
    display_text = "@baedert",
    target = "blubb"
  };

  entities[2] = Cb.TextEntity () {
    from = 38,
    to = 53,
    original_text = "#baedertworship",
    display_text = "#baedertworship",
    target = "bla"
  };

  entities[3] = Cb.TextEntity () {
    from = 54,
    to = 63,
    original_text = "#thefeels",
    display_text = "#thefeels",
    target = "foobar"
  };

  entities[4] = Cb.TextEntity () {
    from = 64,
    to = 71,
    original_text = "#foobar",
    display_text = "#foobar",
    target = "bla"
  };

  string result = Cb.TextTransform.text (text,
                                         entities,
                                         Cb.TransformFlags.REMOVE_TRAILING_HASHTAGS, 0, 0);

  assert (result.contains (">@baedert<")); // Mention should still be a link
  assert (result.contains (">#totally<"));
  assert (!result.contains ("#baedertworship"));
  assert (!result.contains ("#thefeels"));
  assert (!result.contains ("#foobar"));
}


void trailing_hashtags_mention_before () {
  string text = "Hey, #totally inappropriate! #baedertworship @baedert #foobar";

  var entities = new Cb.TextEntity[4];

  entities[0] = Cb.TextEntity () {
    from = 5,
    to = 13,
    original_text = "#totally",
    display_text = "#totally",
    target = "foobar"
  };

  entities[1] = Cb.TextEntity () {
    from = 29,
    to = 44,
    original_text = "#baedertworship",
    display_text = "#baedertworship",
    target = "bla"
  };

  entities[2] = Cb.TextEntity () {
    from = 45,
    to = 53,
    original_text = "@baedert",
    display_text = "@baedert",
    target = "foobar"
  };

  entities[3] = Cb.TextEntity () {
    from = 54,
    to = 61,
    original_text = "#foobar",
    display_text = "#foobar",
    target = "bla"
  };

  string result = Cb.TextTransform.text (text,
                                         entities,
                                         Cb.TransformFlags.REMOVE_TRAILING_HASHTAGS, 0, 0);

  assert (result.contains (">@baedert<")); // Mention should still be a link
  assert (result.contains (">#totally<"));
  assert (result.contains (">#baedertworship<"));
  assert (!result.contains ("#foobar"));
}


void whitespace_hashtags () {
  string text = "Hey, #totally inappropriate @baedert! #baedertworship #thefeels #foobar";

  var entities = new Cb.TextEntity[5];

  entities[0] = Cb.TextEntity () {
    from = 5,
    to = 13,
    original_text = "#totally",
    display_text = "#totally",
    target = "foobar"
  };

  entities[1] = Cb.TextEntity () {
    from = 28,
    to = 36,
    original_text = "@baedert",
    display_text = "@baedert",
    target = "blubb"
  };

  entities[2] = Cb.TextEntity () {
    from = 38,
    to = 53,
    original_text = "#baedertworship",
    display_text = "#baedertworship",
    target = "bla"
  };

  entities[3] = Cb.TextEntity () {
    from = 54,
    to = 63,
    original_text = "#thefeels",
    display_text = "#thefeels",
    target = "foobar"
  };

  entities[4] = Cb.TextEntity () {
    from = 64,
    to = 71,
    original_text = "#foobar",
    display_text = "#foobar",
    target = "bla"
  };

  string result = Cb.TextTransform.text (text,
                                         entities,
                                         Cb.TransformFlags.REMOVE_TRAILING_HASHTAGS, 0, 0);

  assert (result.contains (">@baedert<")); // Mention should still be a link
  assert (result.contains (">#totally<"));
  assert (!result.contains ("#baedertworship"));
  assert (!result.contains ("#thefeels"));
  assert (!result.contains ("#foobar"));
  assert (!result.contains ("   ")); // 3 spaces between the 3 hashtags
}

void trailing_hashtags_link_after () {
  string text = "Hey, #totally inappropriate @baedert! #baedertworship https://foobar.com";

  var entities = new Cb.TextEntity[4];

  entities[0] = Cb.TextEntity () {
    from = 5,
    to = 13,
    original_text = "#totally",
    display_text = "#totally",
    target = "foobar"
  };

  entities[1] = Cb.TextEntity () {
    from = 28,
    to = 36,
    original_text = "@baedert",
    display_text = "@baedert",
    target = "blubb"
  };

  entities[2] = Cb.TextEntity () {
    from = 38,
    to = 53,
    original_text = "#baedertworship",
    display_text = "#baedertworship",
    target = "bla"
  };

  entities[3] = Cb.TextEntity () {
    from = 54,
    to = 72,
    original_text = "https://foobar.com",
    display_text = "BLA BLA BLA",
    target = "https://foobar.com"
  };

  string result = Cb.TextTransform.text (text,
                                         entities,
                                         Cb.TransformFlags.REMOVE_TRAILING_HASHTAGS,
                                         0, 0);

  assert (result.contains (">@baedert<")); // Mention should still be a link
  assert (result.contains (">#totally<"));
  assert (!result.contains ("#baedertworship"));
}


void no_quoted_link () {
  var t = new Cb.Tweet ();
  t.quoted_tweet = Cb.MiniTweet ();
  t.quoted_tweet.id = 1337;

  t.source_tweet = Cb.MiniTweet ();
  t.source_tweet.text = "Foobar Some text after.";
  t.source_tweet.entities = new Cb.TextEntity[1];
  t.source_tweet.entities[0] = Cb.TextEntity () {
    from = 0,
    to   = 6,
    target = "https://twitter.com/bla/status/1337",
    original_text = "Foobar",
    display_text = "sometextwhocares"
  };

  Settings.add_text_transform_flag (Cb.TransformFlags.REMOVE_MEDIA_LINKS);

  string result = t.get_trimmed_text (Settings.get_text_transform_flags ());

  assert (!result.contains ("1337"));
  assert (result.length > 0);
}

void new_reply () {
  /*
   * This tests a the 'new reply' behavior, see
   * https://dev.twitter.com/overview/api/upcoming-changes-to-tweets
   */
  var t = new Cb.Tweet ();
  var parser = new Json.Parser ();
  try {
    parser.load_from_data (REPLY_TWEET_DATA);
    t.load_from_json (parser.get_root (), 1337, new GLib.DateTime.now_local ());
  } catch (GLib.Error e) {
    assert (false);
  }

  assert (t.source_tweet.display_range_start == 115);

  //message ("Entities:");
  //foreach (var e in t.source_tweet.entities) {
    //message ("'%s': %u, %u", e.display_text, e.from, e.to);
  //}

  var text = t.get_trimmed_text (Cb.TransformFlags.EXPAND_LINKS);
  message (text);

  /* Should not contain any mention */
  assert (!text.contains ("@"));

  /* One of the entities is a URL, the expanded link should point to
   * eventbrite.com, not t.co */
  assert (!text.contains ("t.co"));
}

void trailing_new_lines () {
  var entities = new Cb.TextEntity[1];
  entities[0] = Cb.TextEntity () {
    from = 11,
    to   = 31,
    original_text = "pic.twitter.com/test",
    display_text = "pic.twitter.com/test",
    tooltip_text = "pic.twitter.com/test",
    target       = "https://pic.twitter.com/test"
  };

  string source_text = "foo bar\r\n\r\npic.twitter.com/test";
  string result = Cb.TextTransform.text (source_text,
                                         entities,
                                         Cb.TransformFlags.REMOVE_MEDIA_LINKS,
                                         0,
                                         0);
  assert(result == "foo bar");

  entities[0] = Cb.TextEntity () {
    from = 8,
    to   = 28,
    original_text = "pic.twitter.com/test",
    display_text = "pic.twitter.com/test",
    tooltip_text = "pic.twitter.com/test",
    target       = "https://pic.twitter.com/test"
  };

  source_text = "foo bar pic.twitter.com/test\r\n\r\n";
  result = Cb.TextTransform.text (source_text,
                                  entities,
                                  Cb.TransformFlags.REMOVE_MEDIA_LINKS,
                                  0,
                                  0);
  assert(result == "foo bar");

  string text = "Hey, #totally inappropriate @baedert!\r\n\r\n #baedertworship #thefeels #foobar";

  entities = new Cb.TextEntity[5];

  entities[0] = Cb.TextEntity () {
    from = 5,
    to = 13,
    original_text = "#totally",
    display_text = "#totally",
    target = "foobar"
  };

  entities[1] = Cb.TextEntity () {
    from = 28,
    to = 36,
    original_text = "@baedert",
    display_text = "@baedert",
    target = "blubb"
  };

  entities[2] = Cb.TextEntity () {
    from = 42,
    to = 57,
    original_text = "#baedertworship",
    display_text = "#baedertworship",
    target = "bla"
  };

  entities[3] = Cb.TextEntity () {
    from = 58,
    to = 67,
    original_text = "#thefeels",
    display_text = "#thefeels",
    target = "foobar"
  };

  entities[4] = Cb.TextEntity () {
    from = 68,
    to = 75,
    original_text = "#foobar",
    display_text = "#foobar",
    target = "bla"
  };

  result = Cb.TextTransform.text (text,
                                  entities,
                                  Cb.TransformFlags.REMOVE_TRAILING_HASHTAGS, 0, 0);

  assert (result.contains (">@baedert<")); // Mention should still be a link
  assert (result.contains (">#totally<"));
  assert (result[result.length - 1] == '!');
  assert (!result.contains ("#baedertworship"));
  assert (!result.contains ("#thefeels"));
  assert (!result.contains ("#foobar"));
  assert (!result.contains ("   ")); // 3 spaces between the 3 hashtags
}

void bug1 () {
  var t = new Cb.Tweet ();
  var parser = new Json.Parser ();
  try {
    parser.load_from_data (BUG1_DATA);
    t.load_from_json (parser.get_root (), 1337, new GLib.DateTime.now_local ());
  } catch (GLib.Error e) {
    assert (false);
  }

  string filter_text = t.get_filter_text ();
  assert (filter_text.length > 0);
}

void bug69_encode_text () {
  // Test that our encoding function works independently of tweets.
  // It'd be nice if we didn't have to expose this function, but we're testing
  // C code from Vala, so I don't think there's much choice

  // First make sure normal text doesn't change
  assert(Cb.TextTransform.fix_encoding ("Hello, World!") == "Hello, World!");
  assert(Cb.TextTransform.fix_encoding ("Héllö, Wôrld‽") == "Héllö, Wôrld‽");
  assert(Cb.TextTransform.fix_encoding ("こんにちは世界！") == "こんにちは世界！");

  // Then test it doesn't break correct encoding
  assert(Cb.TextTransform.fix_encoding ("Hello, World &amp; Others&excl;&#x00021;&#33;") == "Hello, World &amp; Others&excl;&#x00021;&#33;");

  // Then test it fixes a simple case
  assert(Cb.TextTransform.fix_encoding ("Hello, World & Others!") == "Hello, World &amp; Others!");

  // Then some other positions
  assert(Cb.TextTransform.fix_encoding ("&Hello, World!") == "&amp;Hello, World!");
  assert(Cb.TextTransform.fix_encoding ("Hello, World!&") == "Hello, World!&amp;");

  // And then bug 69 - double ampersand
  assert(Cb.TextTransform.fix_encoding ("Hello, World && Others!") == "Hello, World &amp;&amp; Others!");

  // Check other odd ampersand setups while we're at it.
  assert(Cb.TextTransform.fix_encoding ("Hello, World &amp;& Others!") == "Hello, World &amp;&amp; Others!");
  assert(Cb.TextTransform.fix_encoding ("Hello, World &&amp; Others!") == "Hello, World &amp;&amp; Others!");
  assert(Cb.TextTransform.fix_encoding ("Hello, World &hello& Others!") == "Hello, World &amp;hello&amp; Others!");

  // When posting https://twitter.com/IBBoard/status/1222590553793159169 it showed "&" instead of "…" but nothing should change
  assert(Cb.TextTransform.fix_encoding ("The spammers are dead!\n\nOh, wait, no… #sigh https://t.co/j1LEcVQySq") == "The spammers are dead!\n\nOh, wait, no… #sigh https://t.co/j1LEcVQySq");
}

void bug69_old_bad_encoding () {
  // Some really old tweets properly encode some characters but not ampersands.
  // This causes our rendering to break as it assumes everything is valid HTML.
  var now = new GLib.DateTime.now_local ();
  var bad_tweet = new Cb.Tweet ();

  var parser = new Json.Parser ();
  try {
    parser.load_from_data (bug69_bad_tweet);
  } catch (GLib.Error e) {
    critical (e.message);
  }
  var bad_root = parser.get_root ();
  bad_tweet.load_from_json (bad_root, 0, now);

  var good_tweet = new Cb.Tweet ();
  parser = new Json.Parser ();

  try {
    parser.load_from_data (bug69_good_tweet);
  } catch (GLib.Error e) {
    critical (e.message);
  }
  var good_root = parser.get_root ();

  good_tweet.load_from_json (good_root, 0, now);

  var bad_tweet_text = bad_tweet.get_real_text();
  assert (good_tweet.get_real_text().substring(0, bad_tweet_text.length) == bad_tweet_text);
}

void bug70_substring_memory_allocation() {
  // Twitter once gave us bad data (duplicate entity indices). This caused negative-length substrings.
  // We can't linkigy an entity that we don't know the position of, so it has to remain as text.
  // This is the best we can do with the data available.

  var now = new GLib.DateTime.now_local ();
  var t = new Cb.Tweet ();

  var parser = new Json.Parser ();
  try {
    parser.load_from_data (BUG70);
  } catch (GLib.Error e) {
    critical (e.message);
  }
  var root = parser.get_root ();

  // This should raise a WARNING level message and we should use expect, but we have to use INFO because WARNING is fatal in debug mode, which tests use,
  // and the system uses the structured log writer so we can't do simple filtering
  //GLib.Test.expect_message("cawbird", GLib.LogLevelFlags.LEVEL_WARNING, "Skipping entity - expected https://t.co/30kMXiKMRU but found https://t.co/4Xxq6jHtm0. Likely bad indices (54 to 77)");
  t.load_from_json (root, 0, now);
  assert (t.get_real_text() == "https://t.co/30kMXiKMRU https://twitter.com/chadloder/status/1211804049240031232");
  //GLib.Test.assert_expected_messages ();
}

void bug70_case_insensitivity() {
  // Apparently Twitter sometimes mismatches the case between the entity content and the text.
  // Presumably this happens when someone types @ibboard but the canonical format is @IBBoard.
  // The text shows what was typed, but the entity shows the canonical value.
  var t = new Cb.Tweet ();
  t.quoted_tweet = Cb.MiniTweet ();
  t.quoted_tweet.id = 1337;

  t.source_tweet = Cb.MiniTweet ();
  t.source_tweet.text = "Hello @ibboard! #newyearseve #ebertstraße";
  t.source_tweet.entities = new Cb.TextEntity[3];
  t.source_tweet.entities[0] = Cb.TextEntity () {
    from = 6,
    to   = 14,
    original_text = "@IBBoard",
    display_text = "@IBBoard",
    target = "blubb"
  };
  t.source_tweet.entities[1] = Cb.TextEntity () {
    from = 16,
    to   = 28,
    original_text = "#NewYearsEve",
    display_text = "#NewYearsEve",
    target = "#NewYearsEve"
  };
  t.source_tweet.entities[2] = Cb.TextEntity () {
    from = 29,
    to   = 41,
    original_text = "#Ebertstraße",
    display_text = "#Ebertstraße",
    target = "#Ebertstraße"
  };

  string result = t.get_real_text ();

  assert (result == "Hello @IBBoard! #NewYearsEve #Ebertstraße");
}

void bug70_wide_hash() {
  // Some character sets (e.g. Japanese) may use U+FF03 FULLWIDTH NUMBER SIGN
  // instead of U+0023 NUMBER SIGN  
  var t = new Cb.Tweet ();
  t.quoted_tweet = Cb.MiniTweet ();
  t.quoted_tweet.id = 1337;

  t.source_tweet = Cb.MiniTweet ();
  t.source_tweet.text = "Wide ＃リーグオーダー";
  t.source_tweet.entities = new Cb.TextEntity[1];
  t.source_tweet.entities[0] = Cb.TextEntity () {
    from = 5,
    to   = 13,
    original_text = "#リーグオーダー",
    // Use the fact that get_real_text() expands hashtags to their display text to do a translation that we can spot
    display_text = "#LeagueOrder"
  };
  info("bug70-wide-hash");
  string result = t.get_real_text ();
  assert (result == "Wide #LeagueOrder");
}

int main (string[] args) {
  GLib.Environment.set_variable ("GSETTINGS_BACKEND", "memory", true);
  Intl.setlocale (LocaleCategory.ALL, "");
  GLib.Test.init (ref args);
  Settings.init ();
  GLib.Test.add_func ("/tt/normal", normal);
  GLib.Test.add_func ("/tt/simple", simple);
  GLib.Test.add_func ("/tt/url-at-end", url_at_end);
  GLib.Test.add_func ("/tt/utf8", utf8);
  GLib.Test.add_func ("/tt/expand-links", expand_links);
  GLib.Test.add_func ("/tt/multiple-links", multiple_links);
  GLib.Test.add_func ("/tt/remove-only-trailing-hashtags", remove_only_trailing_hashtags);
  GLib.Test.add_func ("/tt/remove-multiple-trailing-hashtags", remove_multiple_trailing_hashtags);
  GLib.Test.add_func ("/tt/trailing-hashtags-mention-before", trailing_hashtags_mention_before);
  GLib.Test.add_func ("/tt/whitespace-between-trailing-hashtags", whitespace_hashtags);
  GLib.Test.add_func ("/tt/trailing-hashtags-media-link-after", trailing_hashtags_link_after);
  GLib.Test.add_func ("/tt/no-quoted-link", no_quoted_link);
  GLib.Test.add_func ("/tt/new-reply", new_reply);
  GLib.Test.add_func ("/tt/trailing_newlines", trailing_new_lines);
  GLib.Test.add_func ("/tt/bug1", bug1);
  GLib.Test.add_func ("/tt/bug69-encode-text", bug69_encode_text);
  GLib.Test.add_func ("/tt/bug69-old-bad-encoding", bug69_old_bad_encoding);
  GLib.Test.add_func ("/tt/bug70-substring-memory-allocation", bug70_substring_memory_allocation);
  GLib.Test.add_func ("/tt/bug70-case-insensitivity", bug70_case_insensitivity);
  GLib.Test.add_func ("/tt/bug70-wide-hash", bug70_wide_hash);

  return GLib.Test.run ();
}

// {{{
const string REPLY_TWEET_DATA = """
{
  "created_at" : "Mon Apr 17 15:16:18 +0000 2017",
  "id" : 853990508326252550,
  "id_str" : "853990508326252550",
  "full_text" : "@jjdesmond @_UBRAS_ @franalsworth @4Apes @katy4apes @theAliceRoberts @JaneGoodallUK @Jane_Goodall @JaneGoodallInst And here's the link for tickets again ... https://t.co/a9lOVMouNK",
  "truncated" : false,
  "display_text_range" : [
    115,
    180
  ],
  "entities" : {
    "hashtags" : [
    ],
    "symbols" : [
    ],
    "user_mentions" : [
      {
        "screen_name" : "jjdesmond",
        "name" : "Jimmy Jenny Desmond",
        "id" : 21278482,
        "id_str" : "21278482",
        "indices" : [
          0,
          10
        ]
      },
      {
        "screen_name" : "_UBRAS_",
        "name" : "Roots and Shoots UOB",
        "id" : 803329927974096896,
        "id_str" : "803329927974096896",
        "indices" : [
          11,
          19
        ]
      },
      {
        "screen_name" : "franalsworth",
        "name" : "Fran",
        "id" : 776983919287754752,
        "id_str" : "776983919287754752",
        "indices" : [
          20,
          33
        ]
      },
      {
        "screen_name" : "4Apes",
        "name" : "Ian Redmond",
        "id" : 155889035,
        "id_str" : "155889035",
        "indices" : [
          34,
          40
        ]
      },
      {
        "screen_name" : "katy4apes",
        "name" : "Katy Jedamzik",
        "id" : 159608654,
        "id_str" : "159608654",
        "indices" : [
          41,
          51
        ]
      },
      {
        "screen_name" : "theAliceRoberts",
        "name" : "Prof Alice Roberts",
        "id" : 260211154,
        "id_str" : "260211154",
        "indices" : [
          52,
          68
        ]
      },
      {
        "screen_name" : "JaneGoodallUK",
        "name" : "Roots & Shoots UK",
        "id" : 423423823,
        "id_str" : "423423823",
        "indices" : [
          69,
          83
        ]
      },
      {
        "screen_name" : "Jane_Goodall",
        "name" : "Jane Goodall",
        "id" : 235157216,
        "id_str" : "235157216",
        "indices" : [
          84,
          97
        ]
      },
      {
        "screen_name" : "JaneGoodallInst",
        "name" : "JaneGoodallInstitute",
        "id" : 39822897,
        "id_str" : "39822897",
        "indices" : [
          98,
          114
        ]
      }
    ],
    "urls" : [
      {
        "url" : "https://t.co/a9lOVMouNK",
        "expanded_url" : "https://www.eventbrite.com/e/working-with-apes-tickets-33089771397",
        "display_url" : "eventbrite.com/e/working-with…",
        "indices" : [
          157,
          180
        ]
      }
    ]
  },
  "source" : "<a href=\"http://twitter.com/download/iphone\" rel=\"nofollow\">Twitter for iPhone</a>",
  "in_reply_to_status_id" : 853925036696141824,
  "in_reply_to_status_id_str" : "853925036696141824",
  "in_reply_to_user_id" : 21278482,
  "in_reply_to_user_id_str" : "21278482",
  "in_reply_to_screen_name" : "jjdesmond",
  "user" : {
    "id" : 415472140,
    "id_str" : "415472140",
    "name" : "Ben Garrod",
    "screen_name" : "Ben_garrod",
    "location" : "Bristol&Norfolk",
    "description" : "Monkey-chaser, TV-talker, bone geek and Teaching Fellow at @AngliaRuskin https://t.co/FXbftdxxTJ",
    "url" : "https://t.co/1B9SDHfWoF",
    "entities" : {
      "url" : {
        "urls" : [
          {
            "url" : "https://t.co/1B9SDHfWoF",
            "expanded_url" : "http://www.josarsby.com/ben-garrod",
            "display_url" : "josarsby.com/ben-garrod",
            "indices" : [
              0,
              23
            ]
          }
        ]
      },
      "description" : {
        "urls" : [
          {
            "url" : "https://t.co/FXbftdxxTJ",
            "expanded_url" : "http://www.anglia.ac.uk/science-and-technology/about/life-sciences/our-staff/ben-garrod",
            "display_url" : "anglia.ac.uk/science-and-te…",
            "indices" : [
              73,
              96
            ]
          }
        ]
      }
    },
    "protected" : false,
    "followers_count" : 6526,
    "friends_count" : 1016,
    "listed_count" : 128,
    "created_at" : "Fri Nov 18 11:30:48 +0000 2011",
    "favourites_count" : 25292,
    "utc_offset" : 3600,
    "time_zone" : "London",
    "geo_enabled" : true,
    "verified" : true,
    "statuses_count" : 17224,
    "lang" : "en",
    "contributors_enabled" : false,
    "is_translator" : false,
    "is_translation_enabled" : false,
    "profile_background_color" : "C0DEED",
    "profile_background_image_url" : "http://pbs.twimg.com/profile_background_images/590945579024257024/2F1itaGz.jpg",
    "profile_background_image_url_https" : "https://pbs.twimg.com/profile_background_images/590945579024257024/2F1itaGz.jpg",
    "profile_background_tile" : false,
    "profile_image_url" : "http://pbs.twimg.com/profile_images/615498558385557505/cwSloac3_normal.jpg",
    "profile_image_url_https" : "https://pbs.twimg.com/profile_images/615498558385557505/cwSloac3_normal.jpg",
    "profile_banner_url" : "https://pbs.twimg.com/profile_banners/415472140/1477223840",
    "profile_link_color" : "0084B4",
    "profile_sidebar_border_color" : "FFFFFF",
    "profile_sidebar_fill_color" : "DDEEF6",
    "profile_text_color" : "333333",
    "profile_use_background_image" : false,
    "has_extended_profile" : false,
    "default_profile" : false,
    "default_profile_image" : false,
    "following" : false,
    "follow_request_sent" : false,
    "notifications" : false,
    "translator_type" : "none"
  },
  "geo" : null,
  "coordinates" : null,
  "place" : null,
  "contributors" : null,
  "is_quote_status" : false,
  "retweet_count" : 6,
  "favorite_count" : 7,
  "favorited" : false,
  "retweeted" : false,
  "possibly_sensitive" : false,
  "lang" : "en"
}

""";

const string BUG1_DATA =
"""
{
   "created_at":"Wed Jul 05 19:38:02 +0000 2017",
   "id":882685018904068105,
   "id_str":"882685018904068105",
   "text":"@maljehani10 @sWs8ycsI3krjWrE @bnt_alhofuf @itiihade12 @A_algrni @berota_q8 @fayadhalshamari @OKadour82 @K_ibraheem\u2026 https:\/\/t.co\/9uPkhLBtv4",
   "display_text_range":[
      117,
      140
   ],
   "source":"\u003ca href=\"http:\/\/twitter.com\/download\/iphone\" rel=\"nofollow\"\u003eTwitter for iPhone\u003c\/a\u003e",
   "truncated":true,
   "in_reply_to_status_id":882681872479813633,
   "in_reply_to_status_id_str":"882681872479813633",
   "in_reply_to_user_id":784249163206815744,
   "in_reply_to_user_id_str":"784249163206815744",
   "in_reply_to_screen_name":"maljehani10",
   "user":{
      "id":328900753,
      "id_str":"328900753",
      "name":"\u0627\u062a\u062d\u0627\u062f\u064a \u0644\u0644\u0646\u062e\u0627\u0639",
      "screen_name":"LudKadol",
      "location":"21.469328,39.268171",
      "url":null,
      "description":"\u0627\u0644\u0639\u064a\u0646 \u062a\u0631\u0649 \u0648 \u062a\u0645\u064a\u0644 \u0648 \u0627\u0644\u0642\u0644\u0628 \u064a\u0639\u0634\u0642 \u0643\u0644 \u062c\u0645\u064a\u0644 \u062d\u0628\u0643 \u064a\u0627 \u0627\u062a\u064a \u064a\u062f\u0627\u0648\u064a \u0643\u0644 \u0639\u0644\u064a\u0644 \u0627\u062a\u062d\u0627\u062f\u064a \u060c \u0627\u0631\u0633\u0646\u0627\u0644\u064a \u060c \u0645\u064a\u0644\u0627\u0646\u064a \u060c \u0645\u062f\u0631\u064a\u062f\u064a  D2ABFF98",
      "protected":false,
      "verified":false,
      "followers_count":1771,
      "friends_count":2111,
      "listed_count":3,
      "favourites_count":609,
      "statuses_count":19199,
      "created_at":"Mon Jul 04 06:57:10 +0000 2011",
      "utc_offset":10800,
      "time_zone":"Riyadh",
      "geo_enabled":false,
      "lang":"ar",
      "contributors_enabled":false,
      "is_translator":false,
      "profile_background_color":"C0DEED",
      "profile_background_image_url":"http:\/\/pbs.twimg.com\/profile_background_images\/396412541\/Abstract_3d_8.jpg",
      "profile_background_image_url_https":"https:\/\/pbs.twimg.com\/profile_background_images\/396412541\/Abstract_3d_8.jpg",
      "profile_background_tile":false,
      "profile_link_color":"0084B4",
      "profile_sidebar_border_color":"C0DEED",
      "profile_sidebar_fill_color":"DDEEF6",
      "profile_text_color":"333333",
      "profile_use_background_image":true,
      "profile_image_url":"http:\/\/pbs.twimg.com\/profile_images\/823799368255938560\/HhgWWlCA_normal.jpg",
      "profile_image_url_https":"https:\/\/pbs.twimg.com\/profile_images\/823799368255938560\/HhgWWlCA_normal.jpg",
      "profile_banner_url":"https:\/\/pbs.twimg.com\/profile_banners\/328900753\/1436433030",
      "default_profile":false,
      "default_profile_image":false,
      "following":null,
      "follow_request_sent":null,
      "notifications":null
   },
   "geo":null,
   "coordinates":null,
   "place":null,
   "contributors":null,
   "is_quote_status":false,
   "extended_tweet":{
      "full_text":"@maljehani10 @sWs8ycsI3krjWrE @bnt_alhofuf @itiihade12 @A_algrni @berota_q8 @fayadhalshamari @OKadour82 @K_ibraheem @Adnan_Jas @othmanmali @ADEL_MARDI @battalalgoos \u0628\u0648\u0644\u0648\u0646\u064a \u0628\u064a\u062a\u0648\u0631\u0643\u0627 \u062a\u0631\u0627\u0648\u0633\u064a \u0645\u0627\u0631\u0643\u064a\u0646\u0647\u0648 \u062c\u064a\u0632\u0627\u0648\u064a \u0646\u0627\u062f\u064a \u0647\u062c\u0631 \u062f\u064a\u0627\u0643\u064a\u062a\u064a \u0645\u0648\u0646\u062a\u0627\u0631\u064a \u0627\u0644\u062e ...",
      "display_text_range":[
         165,
         235
      ],
      "entities":{
         "hashtags":[

         ],
         "urls":[

         ],
         "user_mentions":[
            {
               "screen_name":"maljehani10",
               "name":"\u0645\u062d\u0645\u062f \u0623\u0628\u0648 \u0633\u0627\u0631\u064a",
               "id":784249163206815744,
               "id_str":"784249163206815744",
               "indices":[
                  0,
                  12
               ]
            },
            {
               "screen_name":"sWs8ycsI3krjWrE",
               "name":"mwni6xx6mwni",
               "id":859152891076018176,
               "id_str":"859152891076018176",
               "indices":[
                  13,
                  29
               ]
            },
            {
               "screen_name":"bnt_alhofuf",
               "name":"\u0627\u0645 \u0631\u064a\u0646\u0627\u062f \u2665 \u0625\u062a\u062d\u0627\u062f\u064a\u0629 \u2665",
               "id":2214026312,
               "id_str":"2214026312",
               "indices":[
                  30,
                  42
               ]
            },
            {
               "screen_name":"itiihade12",
               "name":"\u0628\u0637\u0644 \u0643\u0623\u0633 \u0648\u0644\u064a \u0627\u0644\u0639\u0647\u062f",
               "id":806883635634769921,
               "id_str":"806883635634769921",
               "indices":[
                  43,
                  54
               ]
            },
            {
               "screen_name":"A_algrni",
               "name":"#\u0639\u0628\u062f\u0627\u0644\u0631\u062d\u0645\u0646_\u0627\u0644\u0642\u0631\u0646\u064a",
               "id":370497227,
               "id_str":"370497227",
               "indices":[
                  55,
                  64
               ]
            },
            {
               "screen_name":"berota_q8",
               "name":"\u0639\u0628\u0640\u064a\u0640\u0631~\u0627\u0644\u0625\u062a\u062d\u0627\u062f",
               "id":396583124,
               "id_str":"396583124",
               "indices":[
                  65,
                  75
               ]
            },
            {
               "screen_name":"fayadhalshamari",
               "name":"\u0641\u064a\u0627\u0636 \u0627\u0644\u0634\u0645\u0631\u064a",
               "id":377591886,
               "id_str":"377591886",
               "indices":[
                  76,
                  92
               ]
            },
            {
               "screen_name":"OKadour82",
               "name":"\u0639\u0628\u064a\u062f \u0643\u0639\u062f\u0648\u0631",
               "id":1358991192,
               "id_str":"1358991192",
               "indices":[
                  93,
                  103
               ]
            },
            {
               "screen_name":"K_ibraheem",
               "name":"\u062e\u0644\u064a\u0644 \u0625\u0628\u0631\u0627\u0647\u064a\u0645",
               "id":271130300,
               "id_str":"271130300",
               "indices":[
                  104,
                  115
               ]
            },
            {
               "screen_name":"Adnan_Jas",
               "name":"\u0639\u062f\u0646\u0627\u0646 \u062c\u0633\u062a\u0646\u064a\u0647",
               "id":416120500,
               "id_str":"416120500",
               "indices":[
                  116,
                  126
               ]
            },
            {
               "screen_name":"othmanmali",
               "name":"\u0639\u062b\u0645\u0627\u0646 \u0627\u0628\u0648\u0628\u0643\u0631 \u0645\u0627\u0644\u064a",
               "id":299213308,
               "id_str":"299213308",
               "indices":[
                  127,
                  138
               ]
            },
            {
               "screen_name":"ADEL_MARDI",
               "name":"\u0639\u0627\u062f\u0644 \u0627\u0644\u0645\u0631\u0636\u064a",
               "id":508105416,
               "id_str":"508105416",
               "indices":[
                  139,
                  150
               ]
            },
            {
               "screen_name":"battalalgoos",
               "name":"\u0628\u062a\u0627\u0644 \u0627\u0644\u0642\u0648\u0633",
               "id":251600033,
               "id_str":"251600033",
               "indices":[
                  151,
                  164
               ]
            }
         ],
         "symbols":[

         ]
      }
   },
   "retweet_count":0,
   "favorite_count":0,
   "entities":{
      "hashtags":[

      ],
      "urls":[
         {
            "url":"https:\/\/t.co\/9uPkhLBtv4",
            "expanded_url":"https:\/\/twitter.com\/i\/web\/status\/882685018904068105",
            "display_url":"twitter.com\/i\/web\/status\/8\u2026",
            "indices":[
               117,
               140
            ]
         }
      ],
      "user_mentions":[
         {
            "screen_name":"maljehani10",
            "name":"\u0645\u062d\u0645\u062f \u0623\u0628\u0648 \u0633\u0627\u0631\u064a",
            "id":784249163206815744,
            "id_str":"784249163206815744",
            "indices":[
               0,
               12
            ]
         },
         {
            "screen_name":"sWs8ycsI3krjWrE",
            "name":"mwni6xx6mwni",
            "id":859152891076018176,
            "id_str":"859152891076018176",
            "indices":[
               13,
               29
            ]
         },
         {
            "screen_name":"bnt_alhofuf",
            "name":"\u0627\u0645 \u0631\u064a\u0646\u0627\u062f \u2665 \u0625\u062a\u062d\u0627\u062f\u064a\u0629 \u2665",
            "id":2214026312,
            "id_str":"2214026312",
            "indices":[
               30,
               42
            ]
         },
         {
            "screen_name":"itiihade12",
            "name":"\u0628\u0637\u0644 \u0643\u0623\u0633 \u0648\u0644\u064a \u0627\u0644\u0639\u0647\u062f",
            "id":806883635634769921,
            "id_str":"806883635634769921",
            "indices":[
               43,
               54
            ]
         },
         {
            "screen_name":"A_algrni",
            "name":"#\u0639\u0628\u062f\u0627\u0644\u0631\u062d\u0645\u0646_\u0627\u0644\u0642\u0631\u0646\u064a",
            "id":370497227,
            "id_str":"370497227",
            "indices":[
               55,
               64
            ]
         },
         {
            "screen_name":"berota_q8",
            "name":"\u0639\u0628\u0640\u064a\u0640\u0631~\u0627\u0644\u0625\u062a\u062d\u0627\u062f",
            "id":396583124,
            "id_str":"396583124",
            "indices":[
               65,
               75
            ]
         },
         {
            "screen_name":"fayadhalshamari",
            "name":"\u0641\u064a\u0627\u0636 \u0627\u0644\u0634\u0645\u0631\u064a",
            "id":377591886,
            "id_str":"377591886",
            "indices":[
               76,
               92
            ]
         },
         {
            "screen_name":"OKadour82",
            "name":"\u0639\u0628\u064a\u062f \u0643\u0639\u062f\u0648\u0631",
            "id":1358991192,
            "id_str":"1358991192",
            "indices":[
               93,
               103
            ]
         },
         {
            "screen_name":"K_ibraheem",
            "name":"\u062e\u0644\u064a\u0644 \u0625\u0628\u0631\u0627\u0647\u064a\u0645",
            "id":271130300,
            "id_str":"271130300",
            "indices":[
               104,
               115
            ]
         }
      ],
      "symbols":[

      ]
   },
   "favorited":false,
   "retweeted":false,
   "filter_level":"low",
   "lang":"ar",
   "timestamp_ms":"1499283482658"
}
""";

const string bug69_good_tweet = """
{
  "created_at" : "Fri Dec 20 14:17:23 +0000 2019",
  "id" : 1208028629059420161,
  "id_str" : "1208028629059420161",
  "full_text" : "for i in `seq 1 254` ; do ping -W1 -c 1 10.0.0.$i &gt; /dev/null &amp;&amp; echo 10.0.0.$i ; done #scan network 10.0.0.0 for active hosts &amp; stuff",
  "truncated" : false,
  "display_text_range" : [
    0,
    200
  ],
  "entities" : {
    "hashtags" : [
      {
        "text" : "scan",
        "indices" : [
          98,
          103
        ]
      }
    ],
    "symbols" : [
    ],
    "user_mentions" : [
    ],
    "urls" : [
    ]
  },
  "source" : "<a href=\"https://ibboard.co.uk/cawbird/\" rel=\"nofollow\">Cawbird</a>",
  "in_reply_to_status_id" : null,
  "in_reply_to_status_id_str" : null,
  "in_reply_to_user_id" : null,
  "in_reply_to_user_id_str" : null,
  "in_reply_to_screen_name" : null,
  "user" : {
    "id" : 194913600,
    "id_str" : "194913600",
    "name" : "Test Account",
    "screen_name" : "IBBTwtr",
    "location" : "",
    "description" : "IBBoard's test account for sending test messages to without disturbing people. THIS ACCOUNT WILL NEVER POST ANYTHING INTERESTING! May be used as a spam trap.",
    "url" : null,
    "entities" : {
      "description" : {
        "urls" : [
        ]
      }
    },
    "protected" : false,
    "followers_count" : 2,
    "friends_count" : 12,
    "listed_count" : 0,
    "created_at" : "Sat Sep 25 09:06:35 +0000 2010",
    "favourites_count" : 1,
    "utc_offset" : null,
    "time_zone" : null,
    "geo_enabled" : false,
    "verified" : false,
    "statuses_count" : 102,
    "lang" : null,
    "contributors_enabled" : false,
    "is_translator" : false,
    "is_translation_enabled" : false,
    "profile_background_color" : "C0DEED",
    "profile_background_image_url" : "http://abs.twimg.com/images/themes/theme1/bg.png",
    "profile_background_image_url_https" : "https://abs.twimg.com/images/themes/theme1/bg.png",
    "profile_background_tile" : false,
    "profile_image_url" : "http://pbs.twimg.com/profile_images/853335069934669831/k5Y-rjee_normal.jpg",
    "profile_image_url_https" : "https://pbs.twimg.com/profile_images/853335069934669831/k5Y-rjee_normal.jpg",
    "profile_link_color" : "1DA1F2",
    "profile_sidebar_border_color" : "C0DEED",
    "profile_sidebar_fill_color" : "DDEEF6",
    "profile_text_color" : "333333",
    "profile_use_background_image" : true,
    "has_extended_profile" : false,
    "default_profile" : true,
    "default_profile_image" : false,
    "can_media_tag" : true,
    "followed_by" : false,
    "following" : false,
    "follow_request_sent" : false,
    "notifications" : false,
    "translator_type" : "none"
  },
  "geo" : null,
  "coordinates" : null,
  "place" : null,
  "contributors" : null,
  "is_quote_status" : true,
  "quoted_status_id" : 6705176552,
  "quoted_status_id_str" : "6705176552",
  "quoted_status_permalink" : {
    "url" : "https://t.co/0hUF8hx8Lj",
    "expanded" : "https://twitter.com/climagic/status/6705176552",
    "display" : "twitter.com/climagic/statu…"
  },
  "quoted_status" : {
    "created_at" : "Tue Dec 15 19:25:44 +0000 2009",
    "id" : 6705176552,
    "id_str" : "6705176552",
    "full_text" : "for i in `seq 1 254` ; do ping -W1 -c 1 10.0.0.$i &gt; /dev/null && echo 10.0.0.$i ; done #scan network 10.0.0.0 for active hosts",
    "truncated" : false,
    "display_text_range" : [
      0,
      129
    ],
    "entities" : {
      "hashtags" : [
        {
          "text" : "scan",
          "indices" : [
            90,
            95
          ]
        }
      ],
      "symbols" : [
      ],
      "user_mentions" : [
      ],
      "urls" : [
      ]
    },
    "source" : "<a href=\"http://twitter.com\" rel=\"nofollow\">Twitter Web Client</a>",
    "in_reply_to_status_id" : null,
    "in_reply_to_status_id_str" : null,
    "in_reply_to_user_id" : null,
    "in_reply_to_user_id_str" : null,
    "in_reply_to_screen_name" : null,
    "user" : {
      "id" : 91333167,
      "id_str" : "91333167",
      "name" : "Command Line Magic",
      "screen_name" : "climagic",
      "location" : "BASHLAND",
      "description" : "Cool Unix/Linux Command Line tricks you can use in $TWITTER_CHAR_LIMIT characters or less. Here mostly to inspire all to try more. Read docs first, run later.",
      "url" : "https://t.co/eKoQFEZTLs",
      "entities" : {
        "url" : {
          "urls" : [
            {
              "url" : "https://t.co/eKoQFEZTLs",
              "expanded_url" : "http://www.climagic.org/",
              "display_url" : "climagic.org",
              "indices" : [
                0,
                23
              ]
            }
          ]
        },
        "description" : {
          "urls" : [
          ]
        }
      },
      "protected" : false,
      "followers_count" : 187515,
      "friends_count" : 12242,
      "listed_count" : 4036,
      "created_at" : "Fri Nov 20 12:49:35 +0000 2009",
      "favourites_count" : 1498,
      "utc_offset" : null,
      "time_zone" : null,
      "geo_enabled" : true,
      "verified" : false,
      "statuses_count" : 12536,
      "lang" : null,
      "contributors_enabled" : false,
      "is_translator" : false,
      "is_translation_enabled" : false,
      "profile_background_color" : "C0DEED",
      "profile_background_image_url" : "http://abs.twimg.com/images/themes/theme1/bg.png",
      "profile_background_image_url_https" : "https://abs.twimg.com/images/themes/theme1/bg.png",
      "profile_background_tile" : true,
      "profile_image_url" : "http://pbs.twimg.com/profile_images/535876218/climagic-icon_normal.png",
      "profile_image_url_https" : "https://pbs.twimg.com/profile_images/535876218/climagic-icon_normal.png",
      "profile_link_color" : "0084B4",
      "profile_sidebar_border_color" : "C0DEED",
      "profile_sidebar_fill_color" : "DDEEF6",
      "profile_text_color" : "333333",
      "profile_use_background_image" : true,
      "has_extended_profile" : false,
      "default_profile" : false,
      "default_profile_image" : false,
      "can_media_tag" : true,
      "followed_by" : false,
      "following" : false,
      "follow_request_sent" : false,
      "notifications" : false,
      "translator_type" : "none"
    },
    "geo" : null,
    "coordinates" : null,
    "place" : null,
    "contributors" : null,
    "is_quote_status" : false,
    "retweet_count" : 12,
    "favorite_count" : 44,
    "favorited" : false,
    "retweeted" : false,
    "lang" : "en"
  },
  "retweet_count" : 0,
  "favorite_count" : 0,
  "favorited" : false,
  "retweeted" : false,
  "possibly_sensitive" : false,
  "lang" : "en"
}
""";

// This is a tweaked version of the good tweet because
const string bug69_bad_tweet = """
{
  "created_at" : "Tue Dec 15 19:25:44 +0000 2009",
  "id" : 6705176552,
  "id_str" : "6705176552",
  "full_text" : "for i in `seq 1 254` ; do ping -W1 -c 1 10.0.0.$i &gt; /dev/null && echo 10.0.0.$i ; done #scan network 10.0.0.0 for active hosts & stuff",
  "truncated" : false,
  "display_text_range" : [
    0,
    129
  ],
  "entities" : {
    "hashtags" : [
      {
        "text" : "scan",
        "indices" : [
          90,
          95
        ]
      }
    ],
    "symbols" : [
    ],
    "user_mentions" : [
    ],
    "urls" : [
    ]
  },
  "source" : "<a href=\"http://twitter.com\" rel=\"nofollow\">Twitter Web Client</a>",
  "in_reply_to_status_id" : null,
  "in_reply_to_status_id_str" : null,
  "in_reply_to_user_id" : null,
  "in_reply_to_user_id_str" : null,
  "in_reply_to_screen_name" : null,
  "user" : {
    "id" : 91333167,
    "id_str" : "91333167",
    "name" : "Command Line Magic",
    "screen_name" : "climagic",
    "location" : "BASHLAND",
    "description" : "Cool Unix/Linux Command Line tricks you can use in $TWITTER_CHAR_LIMIT characters or less. Here mostly to inspire all to try more. Read docs first, run later.",
    "url" : "https://t.co/eKoQFEZTLs",
    "entities" : {
      "url" : {
        "urls" : [
          {
            "url" : "https://t.co/eKoQFEZTLs",
            "expanded_url" : "http://www.climagic.org/",
            "display_url" : "climagic.org",
            "indices" : [
              0,
              23
            ]
          }
        ]
      },
      "description" : {
        "urls" : [
        ]
      }
    },
    "protected" : false,
    "followers_count" : 187515,
    "friends_count" : 12242,
    "listed_count" : 4036,
    "created_at" : "Fri Nov 20 12:49:35 +0000 2009",
    "favourites_count" : 1498,
    "utc_offset" : null,
    "time_zone" : null,
    "geo_enabled" : true,
    "verified" : false,
    "statuses_count" : 12536,
    "lang" : null,
    "contributors_enabled" : false,
    "is_translator" : false,
    "is_translation_enabled" : false,
    "profile_background_color" : "C0DEED",
    "profile_background_image_url" : "http://abs.twimg.com/images/themes/theme1/bg.png",
    "profile_background_image_url_https" : "https://abs.twimg.com/images/themes/theme1/bg.png",
    "profile_background_tile" : true,
    "profile_image_url" : "http://pbs.twimg.com/profile_images/535876218/climagic-icon_normal.png",
    "profile_image_url_https" : "https://pbs.twimg.com/profile_images/535876218/climagic-icon_normal.png",
    "profile_link_color" : "0084B4",
    "profile_sidebar_border_color" : "C0DEED",
    "profile_sidebar_fill_color" : "DDEEF6",
    "profile_text_color" : "333333",
    "profile_use_background_image" : true,
    "has_extended_profile" : false,
    "default_profile" : false,
    "default_profile_image" : false,
    "can_media_tag" : true,
    "followed_by" : false,
    "following" : false,
    "follow_request_sent" : false,
    "notifications" : false,
    "translator_type" : "none"
  },
  "geo" : null,
  "coordinates" : null,
  "place" : null,
  "contributors" : null,
  "is_quote_status" : false,
  "retweet_count" : 12,
  "favorite_count" : 44,
  "favorited" : false,
  "retweeted" : false,
  "lang" : "en"
}
""";

const string BUG70 = """
{
  "created_at" : "Tue Dec 31 00:20:42 +0000 2019",
  "id" : 1211804333978734592,
  "id_str" : "1211804333978734592",
  "full_text" : "@FlizzieMcGuire @schmittlauch https://t.co/30kMXiKMRU https://t.co/4Xxq6jHtm0",
  "truncated" : false,
  "display_text_range" : [
    30,
    53
  ],
  "entities" : {
    "hashtags" : [
    ],
    "symbols" : [
    ],
    "user_mentions" : [
      {
        "screen_name" : "FlizzieMcGuire",
        "name" : "Bikini Bottom Mafia Stan Account",
        "id" : 863773010,
        "id_str" : "863773010",
        "indices" : [
          0,
          15
        ]
      },
      {
        "screen_name" : "schmittlauch",
        "name" : "Trolli @schmittlauch@toot.matereal.eu 🦥",
        "id" : 312869558,
        "id_str" : "312869558",
        "indices" : [
          16,
          29
        ]
      }
    ],
    "urls" : [
      {
        "url" : "https://t.co/30kMXiKMRU",
        "expanded_url" : "https://twitter.com/chadloder/status/1211804049240031232?s=21",
        "display_url" : "twitter.com/chadloder/stat…",
        "indices" : [
          54,
          77
        ]
      },
      {
        "url" : "https://t.co/4Xxq6jHtm0",
        "expanded_url" : "https://twitter.com/chadloder/status/1211804049240031232",
        "display_url" : "twitter.com/chadloder/stat…",
        "indices" : [
          54,
          77
        ]
      }
    ]
  },
  "source" : "<a href=\"http://twitter.com/download/iphone\" rel=\"nofollow\">Twitter for iPhone</a>",
  "in_reply_to_status_id" : 1211803346975240192,
  "in_reply_to_status_id_str" : "1211803346975240192",
  "in_reply_to_user_id" : 863773010,
  "in_reply_to_user_id_str" : "863773010",
  "in_reply_to_screen_name" : "FlizzieMcGuire",
  "user" : {
    "id" : 98575337,
    "id_str" : "98575337",
    "name" : "Chad Loder",
    "screen_name" : "chadloder",
    "location" : "Los Angeles, CA",
    "description" : "Founder @Habitu8 • Recovering tech guy, author, investor • Human • Previously: Founder, VP Engineering @Rapid7 • #blacklivesmatter",
    "url" : "https://t.co/j2ABO3HoJN",
    "entities" : {
      "url" : {
        "urls" : [
          {
            "url" : "https://t.co/j2ABO3HoJN",
            "expanded_url" : "https://www.habitu8.io/",
            "display_url" : "habitu8.io",
            "indices" : [
              0,
              23
            ]
          }
        ]
      },
      "description" : {
        "urls" : [
        ]
      }
    },
    "protected" : false,
    "followers_count" : 41256,
    "friends_count" : 3984,
    "listed_count" : 392,
    "created_at" : "Tue Dec 22 07:11:56 +0000 2009",
    "favourites_count" : 39913,
    "utc_offset" : null,
    "time_zone" : null,
    "geo_enabled" : true,
    "verified" : false,
    "statuses_count" : 13848,
    "lang" : null,
    "contributors_enabled" : false,
    "is_translator" : false,
    "is_translation_enabled" : false,
    "profile_background_color" : "C0DEED",
    "profile_background_image_url" : "http://abs.twimg.com/images/themes/theme1/bg.png",
    "profile_background_image_url_https" : "https://abs.twimg.com/images/themes/theme1/bg.png",
    "profile_background_tile" : false,
    "profile_image_url" : "http://pbs.twimg.com/profile_images/1213949167870984193/SohzlEa0_normal.jpg",
    "profile_image_url_https" : "https://pbs.twimg.com/profile_images/1213949167870984193/SohzlEa0_normal.jpg",
    "profile_banner_url" : "https://pbs.twimg.com/profile_banners/98575337/1578219983",
    "profile_link_color" : "F0CBCA",
    "profile_sidebar_border_color" : "C0DEED",
    "profile_sidebar_fill_color" : "DDEEF6",
    "profile_text_color" : "333333",
    "profile_use_background_image" : true,
    "has_extended_profile" : true,
    "default_profile" : false,
    "default_profile_image" : false,
    "can_media_tag" : true,
    "followed_by" : true,
    "following" : false,
    "follow_request_sent" : false,
    "notifications" : false,
    "translator_type" : "none"
  },
  "geo" : null,
  "coordinates" : null,
  "place" : null,
  "contributors" : null,
  "is_quote_status" : true,
  "quoted_status_id" : 1211804049240031232,
  "quoted_status_id_str" : "1211804049240031232",
  "quoted_status_permalink" : {
    "url" : "https://t.co/4Xxq6jHtm0",
    "expanded" : "https://twitter.com/chadloder/status/1211804049240031232",
    "display" : "twitter.com/chadloder/stat…"
  },
  "quoted_status" : {
    "created_at" : "Tue Dec 31 00:19:34 +0000 2019",
    "id" : 1211804049240031232,
    "id_str" : "1211804049240031232",
    "full_text" : "The Kiwifarms shit-stains are mad that Nazi-loving backpfeifengesicht¹ Vincent Canfield got booted from #36C3 conference.\n\nLet’s be clear.\n\n1. The hacking scene has ALWAYS had antifascists.\n\n2. Anti-antifascist literally means “fascist”.\n\n¹ - loosely translated, “punchable face” https://t.co/2wXVVs9An8",
    "truncated" : false,
    "display_text_range" : [
      0,
      279
    ],
    "entities" : {
      "hashtags" : [
        {
          "text" : "36C3",
          "indices" : [
            104,
            109
          ]
        }
      ],
      "symbols" : [
      ],
      "user_mentions" : [
      ],
      "urls" : [
      ],
      "media" : [
        {
          "id" : 1211804033226170368,
          "id_str" : "1211804033226170368",
          "indices" : [
            280,
            303
          ],
          "media_url" : "http://pbs.twimg.com/media/ENExWQnU4AAcv5K.jpg",
          "media_url_https" : "https://pbs.twimg.com/media/ENExWQnU4AAcv5K.jpg",
          "url" : "https://t.co/2wXVVs9An8",
          "display_url" : "pic.twitter.com/2wXVVs9An8",
          "expanded_url" : "https://twitter.com/chadloder/status/1211804049240031232/photo/1",
          "type" : "photo",
          "sizes" : {
            "thumb" : {
              "w" : 150,
              "h" : 150,
              "resize" : "crop"
            },
            "medium" : {
              "w" : 1024,
              "h" : 496,
              "resize" : "fit"
            },
            "large" : {
              "w" : 1024,
              "h" : 496,
              "resize" : "fit"
            },
            "small" : {
              "w" : 680,
              "h" : 329,
              "resize" : "fit"
            }
          },
          "features" : {
            "orig" : {
              "faces" : [
              ]
            },
            "medium" : {
              "faces" : [
              ]
            },
            "large" : {
              "faces" : [
              ]
            },
            "small" : {
              "faces" : [
              ]
            }
          }
        }
      ]
    },
    "extended_entities" : {
      "media" : [
        {
          "id" : 1211804033226170368,
          "id_str" : "1211804033226170368",
          "indices" : [
            280,
            303
          ],
          "media_url" : "http://pbs.twimg.com/media/ENExWQnU4AAcv5K.jpg",
          "media_url_https" : "https://pbs.twimg.com/media/ENExWQnU4AAcv5K.jpg",
          "url" : "https://t.co/2wXVVs9An8",
          "display_url" : "pic.twitter.com/2wXVVs9An8",
          "expanded_url" : "https://twitter.com/chadloder/status/1211804049240031232/photo/1",
          "type" : "photo",
          "sizes" : {
            "thumb" : {
              "w" : 150,
              "h" : 150,
              "resize" : "crop"
            },
            "medium" : {
              "w" : 1024,
              "h" : 496,
              "resize" : "fit"
            },
            "large" : {
              "w" : 1024,
              "h" : 496,
              "resize" : "fit"
            },
            "small" : {
              "w" : 680,
              "h" : 329,
              "resize" : "fit"
            }
          },
          "features" : {
            "orig" : {
              "faces" : [
              ]
            },
            "medium" : {
              "faces" : [
              ]
            },
            "large" : {
              "faces" : [
              ]
            },
            "small" : {
              "faces" : [
              ]
            }
          }
        }
      ]
    },
    "source" : "<a href=\"http://twitter.com/download/iphone\" rel=\"nofollow\">Twitter for iPhone</a>",
    "in_reply_to_status_id" : null,
    "in_reply_to_status_id_str" : null,
    "in_reply_to_user_id" : null,
    "in_reply_to_user_id_str" : null,
    "in_reply_to_screen_name" : null,
    "user" : {
      "id" : 98575337,
      "id_str" : "98575337",
      "name" : "Chad Loder",
      "screen_name" : "chadloder",
      "location" : "Los Angeles, CA",
      "description" : "Founder @Habitu8 • Recovering tech guy, author, investor • Human • Previously: Founder, VP Engineering @Rapid7 • #blacklivesmatter",
      "url" : "https://t.co/j2ABO3HoJN",
      "entities" : {
        "url" : {
          "urls" : [
            {
              "url" : "https://t.co/j2ABO3HoJN",
              "expanded_url" : "https://www.habitu8.io/",
              "display_url" : "habitu8.io",
              "indices" : [
                0,
                23
              ]
            }
          ]
        },
        "description" : {
          "urls" : [
          ]
        }
      },
      "protected" : false,
      "followers_count" : 41256,
      "friends_count" : 3984,
      "listed_count" : 392,
      "created_at" : "Tue Dec 22 07:11:56 +0000 2009",
      "favourites_count" : 39913,
      "utc_offset" : null,
      "time_zone" : null,
      "geo_enabled" : true,
      "verified" : false,
      "statuses_count" : 13848,
      "lang" : null,
      "contributors_enabled" : false,
      "is_translator" : false,
      "is_translation_enabled" : false,
      "profile_background_color" : "C0DEED",
      "profile_background_image_url" : "http://abs.twimg.com/images/themes/theme1/bg.png",
      "profile_background_image_url_https" : "https://abs.twimg.com/images/themes/theme1/bg.png",
      "profile_background_tile" : false,
      "profile_image_url" : "http://pbs.twimg.com/profile_images/1213949167870984193/SohzlEa0_normal.jpg",
      "profile_image_url_https" : "https://pbs.twimg.com/profile_images/1213949167870984193/SohzlEa0_normal.jpg",
      "profile_banner_url" : "https://pbs.twimg.com/profile_banners/98575337/1578219983",
      "profile_link_color" : "F0CBCA",
      "profile_sidebar_border_color" : "C0DEED",
      "profile_sidebar_fill_color" : "DDEEF6",
      "profile_text_color" : "333333",
      "profile_use_background_image" : true,
      "has_extended_profile" : true,
      "default_profile" : false,
      "default_profile_image" : false,
      "can_media_tag" : true,
      "followed_by" : true,
      "following" : false,
      "follow_request_sent" : false,
      "notifications" : false,
      "translator_type" : "none"
    },
    "geo" : null,
    "coordinates" : null,
    "place" : null,
    "contributors" : null,
    "is_quote_status" : false,
    "retweet_count" : 4,
    "favorite_count" : 18,
    "favorited" : false,
    "retweeted" : false,
    "possibly_sensitive" : false,
    "lang" : "en"
  },
  "retweet_count" : 0,
  "favorite_count" : 1,
  "favorited" : false,
  "retweeted" : false,
  "possibly_sensitive" : false,
  "lang" : "und"
}
""";
// }}}
