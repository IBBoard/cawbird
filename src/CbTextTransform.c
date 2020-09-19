/*  This file is part of Cawbird, a Gtk+ linux Twitter client forked from Corebird.
 *  Copyright (C) 2016 Timm Bäder (Corebird)
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

#include "CbTextTransform.h"
#include "CbMediaDownloader.h"
#include "CbTypes.h"
#include "CbUtils.h"
#include <string.h>
#include <ctype.h>

char *
cb_text_transform_tweet (const CbMiniTweet *tweet,
                         guint              flags,
                         guint64            quote_id)
{
  return cb_text_transform_text (tweet->text,
                                 tweet->entities,
                                 tweet->n_entities,
                                 flags,
                                 tweet->n_medias,
                                 quote_id,
                                 tweet->display_range_start);
}

const int TRAILING = 1 << 0;


static inline gboolean
is_hashtag (const char *s)
{
  return s[0] == '#';
}

static inline gboolean
is_link (const char *s)
{
  return s != NULL && (g_str_has_prefix (s, "http://") || g_str_has_prefix (s, "https://"));
}

static inline gboolean
is_quote_link (const CbTextEntity *e, gint64 quote_id)
{
  char *suffix = g_strdup_printf ("/status/%" G_GINT64_FORMAT, quote_id);
  gboolean ql;

  ql = (e->target != NULL) &&
       (g_str_has_prefix (e->target, "https://twitter.com/") &&
        g_str_has_suffix (e->target, suffix));

  g_free (suffix);

  return ql;
}

static inline gboolean
is_media_url (const char *url,
              const char *display_text,
              gsize       media_count)
{
  return (is_twitter_media_candidate (url != NULL ? url : display_text) && media_count == 1) ||
         g_str_has_prefix (display_text, "pic.twitter.com/");
}

static inline gboolean
is_whitespace (const char *s)
{
  while (*s != '\0')
    {
      if (!isspace (*s))
        return FALSE;

      s++;
    }

  return TRUE;
}

char *
cb_text_transform_fix_encoding (const char *text)
{
  GString *fixed_string;
  gunichar cur_char;
  const gchar *str;
  gchar *valid_string;
  guint valid_start = 0;
  guint cur_pos = 0;
  guint entity_pos;
  gboolean in_entity = FALSE;
  str = text;
  fixed_string = g_string_new (NULL);

  // Apparently this is a C-ish pattern for walking the string
  while(*str) {
    cur_char = g_utf8_get_char (str);

    if (in_entity) {
      if (
        (cur_char >= '0' && cur_char <= '9')
        || (cur_char >= 'A' && cur_char <= 'Z') || (cur_char >= 'a' && cur_char <= 'z')
        || (cur_char == '#' && entity_pos == cur_pos - 1)) {
        // Continue - but don't "continue;" because we need to do the stuff at the end of the loop
      } else if (cur_char == ';') {
        // Assume the entity was valid.
        // Or we had REALLY bad luck and found an old tweet where someone used an ampersand. no space, some alphanumeric text AND a semicolon!
        in_entity = FALSE;
      } else {
        // Entity was invalid
        if (valid_start < entity_pos) {
          // There's valid substring text to add
          valid_string = g_utf8_substring(text, valid_start, entity_pos);
          g_string_append(fixed_string, valid_string);
          g_free(valid_string);
        }

        g_string_append(fixed_string, "&amp;");
        valid_start = entity_pos + 1;

        if (cur_char == '&') {
          // If it's a consecutive & then we're in a new entity already!
          in_entity = TRUE;
          entity_pos = cur_pos;
        } else {
          in_entity = FALSE;
        }
      }
    } else if (cur_char == '&') {
      entity_pos = cur_pos;
      in_entity = TRUE;
    } 
    // Else all is good, just keep going

    str = g_utf8_next_char(str);
    cur_pos += 1;
  }

  if (in_entity) {
    // Handle a trailing entity
    // TODO: Avoid code copy-and-paste from the WHILE loop
    if (valid_start < entity_pos) {
      valid_string = g_utf8_substring(text, valid_start, entity_pos);
      g_string_append(fixed_string, valid_string);
      g_free(valid_string);
    }

    g_string_append(fixed_string, "&amp;");
    valid_start = entity_pos + 1;
  }

  // Add any trailing text
  if (valid_start < cur_pos) {
    valid_string = g_utf8_substring(text, valid_start, cur_pos);
    g_string_append(fixed_string, valid_string);
    g_free(valid_string);
  }

  return g_string_free(fixed_string, FALSE);
}

char *
cb_text_transform_text (const char   *text,
                        CbTextEntity *entities,
                        gsize         n_entities,
                        guint         flags,
                        gsize         n_medias,
                        gint64        quote_id,
                        guint         display_range_start)
{
  GString *str;
  const  guint text_len   = g_utf8_strlen (text, -1);
  int i;
  char *end_str;
  char *encoded_before;
  gboolean last_entity_was_trailing = FALSE;
  guint last_end   = 0;
  guint cur_end    = text_len;

  if (text_len == 0)
    return g_strdup (text);

  str = g_string_new (NULL);

  for (i = (int)n_entities - 1; i >= 0; i --)
    {
      char *btw;
      guint entity_to;
      gsize btw_length = cur_end - entities[i].to;

      if (entities[i].to <= display_range_start)
        continue;

      entity_to = entities[i].to - display_range_start;

      btw = g_utf8_substring (text,
                              entity_to,
                              cur_end);

      if (!is_whitespace (btw) && btw_length > 0)
        {
          g_free (btw);
          break;
        }
      else
        cur_end = entity_to;

      if (entities[i].to == cur_end &&
          (is_hashtag (entities[i].display_text) || is_link (entities[i].target)))
          {
            entities[i].info |= TRAILING;
            cur_end = entities[i].from - display_range_start;
          }
      else
        {
          g_free (btw);
          break;
        }

      g_free (btw);
    }


  for (i = 0; i < (int)n_entities; i ++)
    {
      CbTextEntity *entity = &entities[i];
      char *before;
      char *entity_text;
      guint entity_to;
      guint entity_from;
      gboolean entity_exists = FALSE;

      if (entity->to <= display_range_start)
        continue;

      entity_to = entity->to - display_range_start;
      entity_from = entity->from - display_range_start;

      entity_text = g_utf8_substring(text, entity_from, entity_to);

      // If the entity text doesn't match the text between the indices (ignoring case, because sometimes Twitter has @ibboard
      // in the text and @IBBoard in the entity) then something went wrong with our data!
      // We ignore the case of ASCII characters because a) g_strcasecmp is deprecated and recommends the ASCII functions
      // and b) case changing has mainly been seen with usernames, which are only ASCII anyway
      if (is_hashtag (entity->display_text)) {
        // We build hashtags with "#" but the text might use the FULLWIDTH NUMBER SIGN
        // so we have to ignore it in the comparison
        char *original_text_no_hash = g_utf8_offset_to_pointer (entity->original_text, 1);
        char *entity_text_no_hash = g_utf8_offset_to_pointer (entity_text, 1);
        entity_exists = g_ascii_strcasecmp(original_text_no_hash, entity_text_no_hash) == 0;
      }
      else {
        entity_exists = g_ascii_strcasecmp(entity->original_text, entity_text) == 0;
      }

      if (!entity_exists) {
        g_info("Skipping entity - expected %s but found %s. Likely bad indices (%u to %u)", entity->original_text, entity_text, entity->from, entity->to);
        g_free(entity_text);
        continue;
      }

      g_free(entity_text);

      before = g_utf8_substring (text,
                                 last_end,
                                 entity_from);

      if (!(last_entity_was_trailing && is_whitespace (before))) {
        encoded_before = cb_text_transform_fix_encoding (before);
        g_string_append (str, encoded_before);
        g_free (encoded_before);
      }

      g_free (before);

      if ((flags & CB_TEXT_TRANSFORM_REMOVE_TRAILING_HASHTAGS) > 0 &&
          (entity->info & TRAILING) > 0 &&
          is_hashtag (entity->display_text))
        {
          last_end = entity_to;
          last_entity_was_trailing = TRUE;
          continue;
        }

      last_entity_was_trailing = FALSE;

      if (((flags & CB_TEXT_TRANSFORM_REMOVE_MEDIA_LINKS) > 0 &&
           is_media_url (entity->target, entity->display_text, n_medias)) ||
          (quote_id != 0 && is_quote_link (entity, quote_id)))
        {
          last_end = entity_to;
          continue;
        }

      if ((flags & CB_TEXT_TRANSFORM_EXPAND_LINKS) > 0)
        {
          if (entity->display_text[0] == '@')
            g_string_append (str, entity->display_text);
          else
            g_string_append (str, entity->target ? entity->target : entity->display_text);
        }
      else
        {
          g_string_append (str, "<span underline=\"none\">&#x2068;<a href=\"");
          g_string_append (str, entity->target ? entity->target : entity->display_text);
          g_string_append (str, "\"");

          if (entity->tooltip_text != NULL)
            {
              char *c = cb_utils_escape_ampersands (entity->tooltip_text);
              char *cc = cb_utils_escape_quotes (c);

              g_string_append (str, " title=\"");
              g_string_append (str, cc);
              g_string_append (str, "\"");

              g_free (cc);
              g_free (c);
            }

          g_string_append (str, ">");
          g_string_append (str, entity->display_text);
          g_string_append (str,"</a>&#x2069;</span>");
        }

      last_end = entity_to;
    }

  end_str = g_utf8_substring (text, last_end, text_len);
  encoded_before = cb_text_transform_fix_encoding (end_str);
  g_string_append (str, encoded_before);

  g_free (encoded_before);
  g_free (end_str);

  return g_string_free (str, FALSE);
}



