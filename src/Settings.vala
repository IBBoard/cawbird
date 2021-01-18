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

public enum MediaVisibility{
  SHOW                = 1,
  HIDE                = 2,
  HIDE_IN_TIMELINES   = 3
}

public enum TranslationService {
  GOOGLE = 0,
  BING = 1,
  DEEPL = 2,
  CUSTOM = 3
}

public class Settings : GLib.Object {
  private static GLib.Settings settings;

  public static void init(){
    settings = new GLib.Settings("uk.co.ibboard.cawbird");
  }

  public static new GLib.Settings get () {
    return settings;
  }

  /**
   * Returns how many tweets should be stacked before a
   * notification should be created.
   */
  public static int get_tweet_stack_count() {
    int setting_val = settings.get_enum("new-tweets-notify");
    return setting_val;
  }

  /**
  * Check whether the user wants Cawbird to always use the dark gtk theme variant.
  */
  public static bool use_dark_theme(){
    return settings.get_boolean("use-dark-theme");
  }

  public static bool notify_new_mentions(){
    return settings.get_boolean("new-mentions-notify");
  }

  public static bool notify_new_dms(){
    return settings.get_boolean("new-dms-notify");
  }

  public static bool auto_scroll_on_new_tweets () {
    return settings.get_boolean ("auto-scroll-on-new-tweets");
  }

  public static string get_accel (string accel_name) {
    return settings.get_string ("accel-" + accel_name);
  }

  public static double max_media_size () {
    return settings.get_double ("max-media-size");
  }

  public static double get_tweet_scale() {
    int scale_idx = settings.get_enum ("tweet-scale");
    switch (scale_idx) {
      case 3: return Pango.Scale.XX_LARGE;
      case 2: return Pango.Scale.X_LARGE;
      case 1: return Pango.Scale.LARGE;
      default: return Pango.Scale.MEDIUM;
    }
  }

  public static void toggle_topbar_visible () {
    settings.set_boolean ("sidebar-visible", !settings.get_boolean ("sidebar-visible"));
  }

  public static string get_consumer_key () {
    return settings.get_string ("consumer-key");
  }

  public static string get_consumer_secret () {
    return settings.get_string ("consumer-secret");
  }

  public static void add_text_transform_flag (Cb.TransformFlags flag) {
    settings.set_uint ("text-transform-flags",
                       settings.get_uint ("text-transform-flags") | flag);
  }

  public static void remove_text_transform_flag (Cb.TransformFlags flag) {
    settings.set_uint ("text-transform-flags",
                       settings.get_uint ("text-transform-flags") & ~flag);
  }

  public static Cb.TransformFlags get_text_transform_flags () {
    return (Cb.TransformFlags) settings.get_uint ("text-transform-flags");
  }

  public static bool hide_nsfw_content () {
    return settings.get_boolean ("hide-nsfw-content");
  }

  public static MediaVisibility get_media_visiblity () {
    return (MediaVisibility)settings.get_enum ("media-visibility");
  }

  public static TranslationService get_translation_service() {
    return (TranslationService)settings.get_enum("translation-service");
  }

  public static string get_custom_translation_service() {
    return settings.get_string("custom-translation-service");
  }

  public static string get_translation_service_url() {
    var translation_service = get_translation_service();
    switch (translation_service) {
      case TranslationService.GOOGLE:
        return "https://translate.google.com/?op=translate&sl={SOURCE_LANG}&tl={TARGET_LANG}&text={CONTENT}";
      case TranslationService.BING:
        return "https://www.bing.com/translator/?from={SOURCE_LANG}&to={TARGET_LANG}&text={CONTENT}";
      case TranslationService.DEEPL:
        return "https://www.deepl.com/translator#{SOURCE_LANG}/{TARGET_LANG}/{CONTENT}";
      default:
        return get_custom_translation_service();
    }
  }
}
