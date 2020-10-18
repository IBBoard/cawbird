void file_type () {
  string p = "foobar.png";
  assert (Cb.Utils.get_file_type (p) == "png");

  p = ".hidden.bar";
  assert (Cb.Utils.get_file_type (p) == "bar");

  p = "foo";
  assert (Cb.Utils.get_file_type (p) == "");

  p = "some.pointy.name.txt";
  assert (Cb.Utils.get_file_type (p) == "txt");

  p = "/foo/bar/zomg.txt";
  assert (Cb.Utils.get_file_type (p) == "txt");
}


void time_delta () {
  var now = new GLib.DateTime.now_local ();
  var then = now.add (-GLib.TimeSpan.MINUTE * 3);
  string delta = Utils.get_time_delta (then, now);
  assert (delta == "3m");

  then = now;
  delta = Utils.get_time_delta (then, now);
  assert (delta == "Now");

  then = now.add (-GLib.TimeSpan.HOUR * 20);
  delta = Utils.get_time_delta (then, now);
  assert (delta == "20h");

  then = now;
  delta = Utils.get_time_delta (then, now);
  assert (delta == "Now");
}

private Gtk.TextBuffer create_buffer_with_cursor(string text, int pos) {
  var buffer = new Gtk.TextBuffer(null);
  buffer.set_text(text);
  Gtk.TextIter iter;
  buffer.get_iter_at_offset(out iter, pos);
  buffer.place_cursor(iter);
  return buffer;
}

void get_ascii_cursor_word () {
  var text = "@cawbirdclient";
  Gtk.TextIter start_iter, end_iter;

  var buffer = create_buffer_with_cursor(text, 0);
  assert(Utils.get_cursor_word(buffer, out start_iter, out end_iter) == text);
  assert(start_iter.get_offset() == 0);
  assert(end_iter.get_offset() == text.char_count());

  buffer = create_buffer_with_cursor(text, 5);
  assert(Utils.get_cursor_word(buffer, out start_iter, out end_iter) == text);
  assert(start_iter.get_offset() == 0);
  assert(end_iter.get_offset() == text.char_count());

  buffer = create_buffer_with_cursor(text, text.char_count());
  assert(Utils.get_cursor_word(buffer, out start_iter, out end_iter) == text);
  assert(start_iter.get_offset() == 0);
  assert(end_iter.get_offset() == text.char_count());

  text = "Hello @cawbirdclient test!";

  buffer = create_buffer_with_cursor(text, 0);
  assert(Utils.get_cursor_word(buffer, out start_iter, out end_iter) == "Hello");
  assert(start_iter.get_offset() == 0);
  assert(end_iter.get_offset() == 5);

  buffer = create_buffer_with_cursor(text, text.char_count() / 2);
  assert(Utils.get_cursor_word(buffer, out start_iter, out end_iter) == "@cawbirdclient");
  assert(start_iter.get_offset() == 6);
  assert(end_iter.get_offset() == 20);

  buffer = create_buffer_with_cursor(text, text.char_count() - 2);
  assert(Utils.get_cursor_word(buffer, out start_iter, out end_iter) == "test!");
  assert(start_iter.get_offset() == 21);
  assert(end_iter.get_offset() == text.char_count());
}

void get_unicode_cursor_word () {
  var text = "@攻殻機動隊";
  Gtk.TextIter start_iter, end_iter;
  var buffer = create_buffer_with_cursor(text, 5);
  assert(Utils.get_cursor_word(buffer, out start_iter, out end_iter) == text);
  assert(start_iter.get_offset() == 0);
  assert(end_iter.get_offset() == text.char_count());
}

void get_punctuated_name_cursor_word () {
  var text = "@o'brien";
  Gtk.TextIter start_iter, end_iter;
  assert(Utils.get_cursor_word(create_buffer_with_cursor(text, 5), out start_iter, out end_iter) == text);

  text = "@ibboard's";
  assert(Utils.get_cursor_word(create_buffer_with_cursor(text, 5), out start_iter, out end_iter) == text);
}

void get_ascii_cursor_mention_word () {
  var text = "@cawbirdclient";
  Gtk.TextIter start_iter, end_iter;

  var buffer = create_buffer_with_cursor(text, 0);
  assert(Utils.get_cursor_mention_word(buffer, out start_iter, out end_iter) == text);
  assert(start_iter.get_offset() == 0);
  assert(end_iter.get_offset() == text.char_count());

  buffer = create_buffer_with_cursor(text, 5);
  assert(Utils.get_cursor_mention_word(buffer, out start_iter, out end_iter) == text);
  assert(start_iter.get_offset() == 0);
  assert(end_iter.get_offset() == text.char_count());

  buffer = create_buffer_with_cursor(text, text.char_count());
  assert(Utils.get_cursor_mention_word(buffer, out start_iter, out end_iter) == text);
  assert(start_iter.get_offset() == 0);
  assert(end_iter.get_offset() == text.char_count());

  text = "Hello @cawbirdclient test!";

  buffer = create_buffer_with_cursor(text, 0);
  assert(Utils.get_cursor_mention_word(buffer, out start_iter, out end_iter) == "");
  assert(start_iter.get_offset() == 0);
  assert(end_iter.get_offset() == 0);

  buffer = create_buffer_with_cursor(text, text.char_count() / 2);
  assert(Utils.get_cursor_mention_word(buffer, out start_iter, out end_iter) == "@cawbirdclient");
  assert(start_iter.get_offset() == 6);
  assert(end_iter.get_offset() == 20);

  buffer = create_buffer_with_cursor(text, text.char_count() - 2);
  assert(Utils.get_cursor_mention_word(buffer, out start_iter, out end_iter) == "");
  assert(start_iter.get_offset() == 21);
  assert(end_iter.get_offset() == 21);

  text = "noone@example.com";
  buffer = create_buffer_with_cursor(text, 0);
  assert(Utils.get_cursor_mention_word(buffer, out start_iter, out end_iter) == "");
  assert(start_iter.get_offset() == 0);
  assert(end_iter.get_offset() == 0);

  text = "@someone@mastadon";
  buffer = create_buffer_with_cursor(text, 0);
  assert(Utils.get_cursor_mention_word(buffer, out start_iter, out end_iter) == text);
  assert(start_iter.get_offset() == 0);
  assert(end_iter.get_offset() == text.char_count());
}

void get_punctuated_name_cursor_mention_word () {
  var text = "@o'briain";
  Gtk.TextIter start_iter, end_iter;
  assert(Utils.get_cursor_mention_word(create_buffer_with_cursor(text, 5), out start_iter, out end_iter) == text);

  text = "@ibboard's";
  assert(Utils.get_cursor_mention_word(create_buffer_with_cursor(text, 5), out start_iter, out end_iter) == text);
}

void get_unicode_cursor_mention_word () {
  var text = "@攻殻機動隊";
  Gtk.TextIter start_iter, end_iter;
  assert(Utils.get_cursor_mention_word(create_buffer_with_cursor(text, 5), out start_iter, out end_iter) == text);
}

void get_surrounded_cursor_mention_word () {
  var text = "Ghost in the Shell (@攻殻機動隊) aka GitS";
  Gtk.TextIter start_iter, end_iter;

  var buffer = create_buffer_with_cursor(text, 22);
  assert(Utils.get_cursor_mention_word(buffer, out start_iter, out end_iter) == "@攻殻機動隊");
  assert(start_iter.get_offset() == 20);
  assert(end_iter.get_offset() == 26);

  text = "(It's *@IBBoard*!)";
  buffer = create_buffer_with_cursor(text, 10);
  assert(Utils.get_cursor_mention_word(buffer, out start_iter, out end_iter) == "@IBBoard");
  assert(start_iter.get_offset() == 7);
  assert(end_iter.get_offset() == 15);

  buffer = create_buffer_with_cursor(text, text.char_count());
  assert(Utils.get_cursor_mention_word(buffer, out start_iter, out end_iter) == "@IBBoard");
  assert(start_iter.get_offset() == 7);
  assert(end_iter.get_offset() == 15);
}

int main (string[] args) {
  GLib.Test.init (ref args);
  GLib.Test.add_func ("/utils/file-type", file_type);
  GLib.Test.add_func ("/utils/time-delta", time_delta);
  GLib.Test.add_func ("/utils/get-ascii-cursor-words", get_ascii_cursor_word);
  GLib.Test.add_func ("/utils/get-unicode-cursor-words", get_unicode_cursor_word);
  GLib.Test.add_func ("/utils/get-punctuated-name-cursor-words", get_punctuated_name_cursor_word);
  GLib.Test.add_func ("/utils/get-ascii-cursor-mention-words", get_ascii_cursor_mention_word);
  GLib.Test.add_func ("/utils/get-unicode-cursor-mention-words", get_unicode_cursor_mention_word);
  GLib.Test.add_func ("/utils/get-punctuated-name-cursor-mention-words", get_punctuated_name_cursor_mention_word);
  GLib.Test.add_func ("/utils/get-surrounded-cursor-mention-words", get_surrounded_cursor_mention_word);

  return GLib.Test.run ();
}
