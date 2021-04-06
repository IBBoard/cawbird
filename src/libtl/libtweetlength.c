/*  This file is part of libtweetlength
 *  Copyright (C) 2017 Timm Bäder
 *
 *  libtweetlength is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  libtweetlength is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with libtweetlength.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "libtweetlength.h"
#include "data.h"
#include <string.h>

#define LINK_LENGTH 23
#define UNWEIGHTED_VALUE 1
#define WEIGHTED_VALUE 2
#define END_SEQUENCE_WEIGHT 0
#define REGIONAL_INDICATOR_OFFSET 0x1F1E6
#define MAKE_KEY(prev_char, cur_char) GUINT_TO_POINTER(prev_char + (cur_char << 8))

// Map of current character type to a list of potential replacements based on the previous character
GHashTable *chartype_map;
// Lookup table of valid Regional Indicator strings
gboolean valid_ri_strings[26*26];
gboolean ri_validator_generated = FALSE;

typedef struct {
  guint type;
  const char *start;
  gsize start_character_index;
  gsize length_in_bytes;
  gsize length_in_characters;
  gsize length_in_weighted_characters;
} Token;

#ifdef LIBTL_DEBUG
static char * G_GNUC_UNUSED
token_str (const Token *t)
{
  return g_strdup_printf ("Type: %u, Text: '%.*s'", t->type, (int)t->length_in_bytes, t->start);
}

static char * G_GNUC_UNUSED
entity_str (const TlEntity *e)
{
  return g_strdup_printf ("Type: %u, Text: '%.*s'", e->type, (int)e->length_in_bytes, e->start);
}

#endif

enum {
  TOK_TEXT = 1,
  TOK_NUMBER,
  TOK_WHITESPACE,
  TOK_COLON,
  TOK_SLASH,
  TOK_OPEN_PAREN,
  TOK_CLOSE_PAREN,
  TOK_QUESTIONMARK,
  TOK_DOT,
  TOK_HASH,
  TOK_AT,
  TOK_EQUALS,
  TOK_DASH,
  TOK_UNDERSCORE,
  TOK_APOSTROPHE,
  TOK_QUOTE,
  TOK_DOLLAR,
  TOK_AMPERSAND,
  TOK_EXCLAMATION,
  TOK_TILDE
};

enum {
  CHARTYPE_NONE, // Used for initial setup ("none") and other special situations (Fitzpatrick modifier on its own)
  CHARTYPE_UNWEIGHTED,
  CHARTYPE_KEYCAPPABLE,
  CHARTYPE_WEIGHTED_OTHER,
  CHARTYPE_FITZPATRICK,
  CHARTYPE_WOMAN,
  CHARTYPE_MAN,
  CHARTYPE_UNGENDERED_ADULT,
  CHARTYPE_CHILD,
  CHARTYPE_FAMILY_PARENTS,
  CHARTYPE_FAMILY_1_CHILD,
  CHARTYPE_FAMILY_2_CHILD,
  CHARTYPE_PERSON,
  CHARTYPE_GENDERABLE_PERSON,
  CHARTYPE_UNTONED_GENDERABLE_PERSON,
  CHARTYPE_FITZPATRICKED_PERSON,
  CHARTYPE_FITZPATRICKED_GENDERABLE_PERSON,
  CHARTYPE_FITZPATRICKED_ADULT,
  CHARTYPE_FITZPATRICKED_UNGENDERED_ADULT,
  CHARTYPE_HAIRSTYLE,
  CHARTYPE_HAIRSTYLED_ADULT,
  CHARTYPE_JOB,
  CHARTYPE_JOB_TEXT,
  CHARTYPE_JOB_PERSON_TEXT,
  CHARTYPE_JOB_PERSON,
  CHARTYPE_WHITE_FLAG,
  CHARTYPE_WHITE_FLAG_VS16,
  CHARTYPE_BLACK_FLAG,
  CHARTYPE_GENDER_TEXT,
  CHARTYPE_GENDER,
  CHARTYPE_GENDERED_PERSON_TEXT,
  CHARTYPE_GENDERED_PERSON,
  CHARTYPE_HAIR,
  CHARTYPE_HEART,
  CHARTYPE_LOVE_BASE_TEXT,
  CHARTYPE_LOVE_BASE,
  CHARTYPE_LOVE_BASE_TEXT_POSSIBLE,
  CHARTYPE_LOVE_BASE_POSSIBLE,
  CHARTYPE_LOVE,
  CHARTYPE_KISS_MARK,
  CHARTYPE_KISSING_BASE,
  CHARTYPE_KISSING_BASE_POSSIBLE,
  CHARTYPE_KISSING,
  CHARTYPE_RAINBOW,
  CHARTYPE_TRANSGENDER_SYMBOL,
  CHARTYPE_SKULL_AND_CROSSBONES,
  CHARTYPE_PARTIAL_COMBINED_FLAG,
  CHARTYPE_COMBINED_FLAG,
  CHARTYPE_CHRISTMAS_TREE,
  CHARTYPE_DOG,
  CHARTYPE_SAFETY_VEST,
  CHARTYPE_CAT,
  CHARTYPE_COLOUR_BLACK,
  CHARTYPE_BEAR,
  CHARTYPE_SNOWFLAKE,
  CHARTYPE_ZWJ_ANIMAL_TEXT,
  CHARTYPE_ZWJ_ANIMAL,
  CHARTYPE_REGIONAL_INDICATOR,
  CHARTYPE_REGIONAL_INDICATOR_FLAG,
  CHARTYPE_TAG,
  CHARTYPE_TAGGED_FLAG,
  CHARTYPE_TAG_CLOSE,
  CHARTYPE_VS16,
  CHARTYPE_ZWJ
};

typedef struct _CharTypeOption {
  guint8 new_chartype;
  guint8 carry_weight;
} CharTypeOption;

static inline CharTypeOption*
new_chartypeoption(guint new_chartype, guint carry_weight) {
  CharTypeOption *opt = malloc(sizeof(CharTypeOption));
  opt->new_chartype = new_chartype;
  opt->carry_weight = carry_weight;
  return opt;
}

static inline GHashTable*
get_chartype_options ()
{
  if (chartype_map != NULL) {
    return chartype_map;
  }

  chartype_map = g_hash_table_new(g_direct_hash, g_direct_equal);

  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_WOMAN, CHARTYPE_WOMAN), new_chartypeoption(CHARTYPE_FAMILY_PARENTS, WEIGHTED_VALUE));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_MAN, CHARTYPE_MAN), new_chartypeoption(CHARTYPE_FAMILY_PARENTS, WEIGHTED_VALUE));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_MAN, CHARTYPE_WOMAN), new_chartypeoption(CHARTYPE_FAMILY_PARENTS, WEIGHTED_VALUE));
  // But not Woman then Man for the family
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_WOMAN, CHARTYPE_CHILD), new_chartypeoption(CHARTYPE_FAMILY_1_CHILD, END_SEQUENCE_WEIGHT));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_MAN, CHARTYPE_CHILD), new_chartypeoption(CHARTYPE_FAMILY_1_CHILD, END_SEQUENCE_WEIGHT));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_FAMILY_PARENTS, CHARTYPE_CHILD), new_chartypeoption(CHARTYPE_FAMILY_1_CHILD, END_SEQUENCE_WEIGHT));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_FAMILY_1_CHILD, CHARTYPE_CHILD), new_chartypeoption(CHARTYPE_FAMILY_2_CHILD, END_SEQUENCE_WEIGHT));

  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_WOMAN, CHARTYPE_JOB_TEXT), new_chartypeoption(CHARTYPE_JOB_PERSON_TEXT, WEIGHTED_VALUE));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_MAN, CHARTYPE_JOB_TEXT), new_chartypeoption(CHARTYPE_JOB_PERSON_TEXT, WEIGHTED_VALUE));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_UNGENDERED_ADULT, CHARTYPE_JOB_TEXT), new_chartypeoption(CHARTYPE_JOB_PERSON_TEXT, WEIGHTED_VALUE));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_FITZPATRICKED_ADULT, CHARTYPE_JOB_TEXT), new_chartypeoption(CHARTYPE_JOB_PERSON_TEXT, WEIGHTED_VALUE));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_FITZPATRICKED_UNGENDERED_ADULT, CHARTYPE_JOB_TEXT), new_chartypeoption(CHARTYPE_JOB_PERSON_TEXT, WEIGHTED_VALUE));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_WOMAN, CHARTYPE_JOB), new_chartypeoption(CHARTYPE_JOB_PERSON, END_SEQUENCE_WEIGHT));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_MAN, CHARTYPE_JOB), new_chartypeoption(CHARTYPE_JOB_PERSON, END_SEQUENCE_WEIGHT));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_UNGENDERED_ADULT, CHARTYPE_JOB), new_chartypeoption(CHARTYPE_JOB_PERSON, END_SEQUENCE_WEIGHT));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_FITZPATRICKED_ADULT, CHARTYPE_JOB), new_chartypeoption(CHARTYPE_JOB_PERSON, END_SEQUENCE_WEIGHT));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_FITZPATRICKED_UNGENDERED_ADULT, CHARTYPE_JOB), new_chartypeoption(CHARTYPE_JOB_PERSON, END_SEQUENCE_WEIGHT));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_JOB_PERSON_TEXT, CHARTYPE_VS16), new_chartypeoption(CHARTYPE_JOB_PERSON, END_SEQUENCE_WEIGHT));

  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_UNGENDERED_ADULT, CHARTYPE_CHRISTMAS_TREE), new_chartypeoption(CHARTYPE_JOB_PERSON, END_SEQUENCE_WEIGHT));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_FITZPATRICKED_UNGENDERED_ADULT, CHARTYPE_CHRISTMAS_TREE), new_chartypeoption(CHARTYPE_JOB_PERSON, END_SEQUENCE_WEIGHT));

  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_PERSON, CHARTYPE_FITZPATRICK), new_chartypeoption(CHARTYPE_FITZPATRICKED_PERSON, END_SEQUENCE_WEIGHT));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_GENDERABLE_PERSON, CHARTYPE_FITZPATRICK), new_chartypeoption(CHARTYPE_FITZPATRICKED_GENDERABLE_PERSON, END_SEQUENCE_WEIGHT));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_WOMAN, CHARTYPE_FITZPATRICK), new_chartypeoption(CHARTYPE_FITZPATRICKED_ADULT, END_SEQUENCE_WEIGHT));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_MAN, CHARTYPE_FITZPATRICK), new_chartypeoption(CHARTYPE_FITZPATRICKED_ADULT, END_SEQUENCE_WEIGHT));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_UNGENDERED_ADULT, CHARTYPE_FITZPATRICK), new_chartypeoption(CHARTYPE_FITZPATRICKED_UNGENDERED_ADULT, END_SEQUENCE_WEIGHT));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_CHILD, CHARTYPE_FITZPATRICK), new_chartypeoption(CHARTYPE_FITZPATRICKED_PERSON, END_SEQUENCE_WEIGHT));

  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_UNGENDERED_ADULT, CHARTYPE_HAIRSTYLE), new_chartypeoption(CHARTYPE_HAIRSTYLED_ADULT, END_SEQUENCE_WEIGHT));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_WOMAN, CHARTYPE_HAIRSTYLE), new_chartypeoption(CHARTYPE_HAIRSTYLED_ADULT, END_SEQUENCE_WEIGHT));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_MAN, CHARTYPE_HAIRSTYLE), new_chartypeoption(CHARTYPE_HAIRSTYLED_ADULT, END_SEQUENCE_WEIGHT));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_UNGENDERED_ADULT, CHARTYPE_HAIRSTYLE), new_chartypeoption(CHARTYPE_HAIRSTYLED_ADULT, END_SEQUENCE_WEIGHT));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_FITZPATRICKED_ADULT, CHARTYPE_HAIRSTYLE), new_chartypeoption(CHARTYPE_HAIRSTYLED_ADULT, END_SEQUENCE_WEIGHT));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_FITZPATRICKED_UNGENDERED_ADULT, CHARTYPE_HAIRSTYLE), new_chartypeoption(CHARTYPE_HAIRSTYLED_ADULT, END_SEQUENCE_WEIGHT));

  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_UNGENDERED_ADULT, CHARTYPE_GENDER_TEXT), new_chartypeoption(CHARTYPE_GENDERED_PERSON_TEXT, WEIGHTED_VALUE));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_UNTONED_GENDERABLE_PERSON, CHARTYPE_GENDER_TEXT), new_chartypeoption(CHARTYPE_GENDERED_PERSON_TEXT, WEIGHTED_VALUE));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_FITZPATRICKED_UNGENDERED_ADULT, CHARTYPE_GENDER_TEXT), new_chartypeoption(CHARTYPE_GENDERED_PERSON_TEXT, WEIGHTED_VALUE));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_GENDERABLE_PERSON, CHARTYPE_GENDER_TEXT), new_chartypeoption(CHARTYPE_GENDERED_PERSON_TEXT, WEIGHTED_VALUE));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_FITZPATRICKED_GENDERABLE_PERSON, CHARTYPE_GENDER_TEXT), new_chartypeoption(CHARTYPE_GENDERED_PERSON_TEXT, WEIGHTED_VALUE));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_GENDERED_PERSON_TEXT, CHARTYPE_VS16), new_chartypeoption(CHARTYPE_GENDERED_PERSON, END_SEQUENCE_WEIGHT));

  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_GENDER_TEXT, CHARTYPE_VS16), new_chartypeoption(CHARTYPE_GENDER, END_SEQUENCE_WEIGHT));

  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_WHITE_FLAG, CHARTYPE_VS16), new_chartypeoption(CHARTYPE_WHITE_FLAG_VS16, END_SEQUENCE_WEIGHT));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_WHITE_FLAG, CHARTYPE_RAINBOW), new_chartypeoption(CHARTYPE_COMBINED_FLAG, END_SEQUENCE_WEIGHT));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_WHITE_FLAG_VS16, CHARTYPE_RAINBOW), new_chartypeoption(CHARTYPE_COMBINED_FLAG, END_SEQUENCE_WEIGHT));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_WHITE_FLAG, CHARTYPE_TRANSGENDER_SYMBOL), new_chartypeoption(CHARTYPE_PARTIAL_COMBINED_FLAG, WEIGHTED_VALUE));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_WHITE_FLAG_VS16, CHARTYPE_TRANSGENDER_SYMBOL), new_chartypeoption(CHARTYPE_PARTIAL_COMBINED_FLAG, WEIGHTED_VALUE));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_BLACK_FLAG, CHARTYPE_SKULL_AND_CROSSBONES), new_chartypeoption(CHARTYPE_PARTIAL_COMBINED_FLAG, WEIGHTED_VALUE));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_PARTIAL_COMBINED_FLAG, CHARTYPE_VS16), new_chartypeoption(CHARTYPE_COMBINED_FLAG, END_SEQUENCE_WEIGHT));

  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_WOMAN, CHARTYPE_HEART), new_chartypeoption(CHARTYPE_LOVE_BASE_TEXT, WEIGHTED_VALUE));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_MAN, CHARTYPE_HEART), new_chartypeoption(CHARTYPE_LOVE_BASE_TEXT_POSSIBLE, WEIGHTED_VALUE));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_LOVE_BASE_TEXT, CHARTYPE_VS16), new_chartypeoption(CHARTYPE_LOVE_BASE, WEIGHTED_VALUE));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_LOVE_BASE_TEXT_POSSIBLE, CHARTYPE_VS16), new_chartypeoption(CHARTYPE_LOVE_BASE_POSSIBLE, WEIGHTED_VALUE));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_LOVE_BASE, CHARTYPE_MAN), new_chartypeoption(CHARTYPE_LOVE, END_SEQUENCE_WEIGHT));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_LOVE_BASE, CHARTYPE_WOMAN), new_chartypeoption(CHARTYPE_LOVE, END_SEQUENCE_WEIGHT));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_LOVE_BASE_POSSIBLE, CHARTYPE_MAN), new_chartypeoption(CHARTYPE_LOVE, END_SEQUENCE_WEIGHT));
  // But not Man Heart Woman
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_LOVE_BASE, CHARTYPE_KISS_MARK), new_chartypeoption(CHARTYPE_KISSING_BASE, WEIGHTED_VALUE));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_LOVE_BASE_POSSIBLE, CHARTYPE_KISS_MARK), new_chartypeoption(CHARTYPE_KISSING_BASE_POSSIBLE, WEIGHTED_VALUE));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_KISSING_BASE, CHARTYPE_MAN), new_chartypeoption(CHARTYPE_KISSING, END_SEQUENCE_WEIGHT));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_KISSING_BASE, CHARTYPE_WOMAN), new_chartypeoption(CHARTYPE_KISSING, END_SEQUENCE_WEIGHT));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_KISSING_BASE_POSSIBLE, CHARTYPE_MAN), new_chartypeoption(CHARTYPE_KISSING, END_SEQUENCE_WEIGHT));
  // But not Man Heart Kiss Woman

  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_BEAR, CHARTYPE_SNOWFLAKE), new_chartypeoption(CHARTYPE_ZWJ_ANIMAL_TEXT, WEIGHTED_VALUE));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_ZWJ_ANIMAL_TEXT, CHARTYPE_VS16), new_chartypeoption(CHARTYPE_ZWJ_ANIMAL, END_SEQUENCE_WEIGHT));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_DOG, CHARTYPE_SAFETY_VEST), new_chartypeoption(CHARTYPE_ZWJ_ANIMAL, END_SEQUENCE_WEIGHT));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_CAT, CHARTYPE_COLOUR_BLACK), new_chartypeoption(CHARTYPE_ZWJ_ANIMAL, END_SEQUENCE_WEIGHT));

  // We assume that CHARTYPE_TAG strings are valid because it's too much trouble if they're not.
  // There's a near-zero probability of people writing them by hand, so we should be safe.
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_BLACK_FLAG, CHARTYPE_TAG), new_chartypeoption(CHARTYPE_TAGGED_FLAG, WEIGHTED_VALUE));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_TAGGED_FLAG, CHARTYPE_TAG), new_chartypeoption(CHARTYPE_TAGGED_FLAG, WEIGHTED_VALUE));
  g_hash_table_insert(chartype_map, MAKE_KEY(CHARTYPE_TAGGED_FLAG, CHARTYPE_TAG_CLOSE), new_chartypeoption(CHARTYPE_TAGGED_FLAG, END_SEQUENCE_WEIGHT));

  return chartype_map;
}

static gboolean
is_valid_regional_indicator (gunichar ri_char1, gunichar ri_char2) {
  if (!ri_validator_generated) {
    // Strings taken from https://en.wikipedia.org/wiki/Regional_indicator_symbol
    // Note: We need the trailing space to align everything for the loop!
    gchar *indicators = "AC AD AE AF AG AI AL AM AO AQ AR AS AT AU AW AX AZ BA BB BD BE BF BG BH BI BJ BL BM BN BO BQ BR BS BT BV BW BY BZ"
                        " CA CC CD CF CG CH CI CK CL CM CN CO CP CR CU CV CW CX CY CZ DE DG DJ DK DM DO DZ EA EC EE EG EH ER ES ET EU FI FJ FK FM FO FR"
                        " GA GB GD GE GF GG GH GI GL GM GN GP GQ GR GS GT GU GW GY HK HM HN HR HT HU IC ID IE IL IM IN IO IQ IR IS IT JE JM JO JP"
                        " KE KG KH KI KM KN KP KR KW KY KZ LA LB LC LI LK LR LS LT LU LV LY MA MC MD ME MF MG MH MK ML MM MN MO MP MQ MR MS MT MU MV MW MX MY MZ"
                        " NA NC NE NF NG NI NL NO NP NR NU NZ OM PA PE PF PG PH PK PL PM PN PR PS PT PW PY QA RE RO RS RU RW"
                        " SA SB SC SD SE SG SH SI SJ SK SL SM SN SO SR SS ST SV SX SY SZ TA TC TD TF TG TH TJ TK TL TM TN TO TR TT TV TW TZ"
                        " UA UG UM UN US UY UZ VA VC VE VG VI VN VU WF WS XK YE YT ZA ZM ZW"
                        " AN BU CS DD FX NT QU SU TP YD YU ZR ";
    gchar *char1 = indicators;
    gchar *char2 = char1 + 1;

    do {
      valid_ri_strings[((*char1 - 0x41) * 26) + (*char2 - 0x41)] = TRUE;
      char1 += 3;
      char2 += 3;
    } while (*char1 != '\0');

    ri_validator_generated = TRUE;
  }

  return valid_ri_strings[((ri_char1 - REGIONAL_INDICATOR_OFFSET) * 26) + (ri_char2 - REGIONAL_INDICATOR_OFFSET)];
}

static inline guint
token_type_from_char (gunichar c)
{
  switch (c) {
    case '@':
      return TOK_AT;
    case '#':
      return TOK_HASH;
    case ':':
      return TOK_COLON;
    case '/':
      return TOK_SLASH;
    case '(':
      return TOK_OPEN_PAREN;
    case ')':
      return TOK_CLOSE_PAREN;
    case '.':
      return TOK_DOT;
    case '?':
      return TOK_QUESTIONMARK;
    case '=':
      return TOK_EQUALS;
    case '-':
      return TOK_DASH;
    case '_':
      return TOK_UNDERSCORE;
    case '\'':
      return TOK_APOSTROPHE;
    case '"':
      return TOK_QUOTE;
    case '$':
      return TOK_DOLLAR;
    case '&':
      return TOK_AMPERSAND;
    case '!':
      return TOK_EXCLAMATION;
    case '~':
      return TOK_TILDE;
    case '0':
    case '1':
    case '2':
    case '3':
    case '4':
    case '5':
    case '6':
    case '7':
    case '8':
    case '9':
      return TOK_NUMBER;
    case ' ':
    case '\n':
    case '\t':
      return TOK_WHITESPACE;

    default:
      return TOK_TEXT;
  }
}

static inline gboolean
token_ends_in_accented (const Token *t)
{
  const char *p = t->start;
  gunichar c;
  gsize i;

  if (t->length_in_bytes == 1 ||
      t->type != TOK_TEXT) {
    return FALSE;
  }

  // The rules here aren't exactly clear...
  // We read the last character of the text pointed to by the given token.
  // If that's not an ascii character, we return TRUE.
  for (i = 0; i < t->length_in_characters - 1; i ++) {
    p = g_utf8_next_char (p);
  }

  c = g_utf8_get_char (p);

  if (c > 127)
    return TRUE;

  return FALSE;
}

static inline gboolean
token_in (const Token *t,
          const char  *haystack)
{
  const int haystack_len = strlen (haystack);
  int i;

  if (t->length_in_bytes > 1) {
    return FALSE;
  }


  for (i = 0; i < haystack_len; i ++) {
    if (haystack[i] == t->start[0]) {
      return TRUE;
    }
  }

  return FALSE;
}


static inline void
emplace_token (GArray     *array,
               const char *token_start,
               gsize       token_length,
               gsize       start_character_index,
               gsize       length_in_characters,
               gsize       length_in_weighted_characters)
{
  Token *t;

  g_array_set_size (array, array->len + 1);
  t = &g_array_index (array, Token, array->len - 1);

  t->type = token_type_from_char (token_start[0]);
  t->start = token_start;
  t->length_in_bytes = token_length;
  t->start_character_index = start_character_index;
  t->length_in_characters = length_in_characters;
  t->length_in_weighted_characters = length_in_weighted_characters;
}

static inline void
emplace_entity_for_tokens (GArray      *array,
                           const Token *tokens,
                           guint        entity_type,
                           guint        start_token_index,
                           guint        end_token_index)
{
  TlEntity *e;
  guint i;

  g_array_set_size (array, array->len + 1);
  e = &g_array_index (array, TlEntity, array->len - 1);

  e->type = entity_type;
  e->start = tokens[start_token_index].start;
  e->length_in_bytes = 0;
  e->length_in_characters = 0;
  e->length_in_weighted_characters = 0;
  e->start_character_index = tokens[start_token_index].start_character_index;

  for (i = start_token_index; i <= end_token_index; i ++) {
    e->length_in_bytes += tokens[i].length_in_bytes;
    e->length_in_characters += tokens[i].length_in_characters;
    e->length_in_weighted_characters += tokens[i].length_in_weighted_characters;
  }
}

static inline gboolean
is_valid_mention_char (gunichar c)
{
  // Just ASCII
  if (c > 127)
    return FALSE;

  return TRUE;
}


static inline gboolean
token_is_tld (const Token *t,
              gboolean     has_protocol)
{
  guint i;

  if (t->length_in_characters > GTLDS[G_N_ELEMENTS (GTLDS) - 1].length) {
    return FALSE;
  }

  for (i = 0; i < G_N_ELEMENTS (GTLDS); i ++) {
    if (t->length_in_characters == GTLDS[i].length &&
        strncasecmp (t->start, GTLDS[i].str, t->length_in_bytes) == 0) {
      return TRUE;
    }
  }

  for (i = 0; i < G_N_ELEMENTS (CCTLDS); i ++) {
    if (t->length_in_characters == CCTLDS[i].length &&
        strncasecmp (t->start, CCTLDS[i].str, t->length_in_bytes) == 0) {
      return TRUE;
    }
  }

  return FALSE;
}

static inline gboolean
token_is_protocol (const Token *t)
{
  if (t->type != TOK_TEXT) {
    return FALSE;
  }

  if (t->length_in_bytes != 4 && t->length_in_bytes != 5) {
    return FALSE;
  }

  return strncasecmp (t->start, "http", t->length_in_bytes) == 0 ||
         strncasecmp (t->start, "https", t->length_in_bytes) == 0;
}

static inline gboolean
char_splits (gunichar c)
{
  switch (c) {
    case ',':
    case '.':
    case '/':
    case '?':
    case '(':
    case ')':
    case ':':
    case ';':
    case '=':
    case '@':
    case '#':
    case '-':
    case '_':
    case '\n':
    case '\t':
    case '\0':
    case ' ':
    case '\'':
    case '"':
    case '$':
    case '|':
    case '&':
    case '^':
    case '%':
    case '+':
    case '*':
    case '\\':
    case '{':
    case '}':
    case '[':
    case ']':
    case '`':
    case '~':
    case '!':
      return TRUE;
    default:
      return FALSE;
  }

  return FALSE;
}

static inline gsize
entity_length_in_characters (const TlEntity *e)
{
  switch (e->type) {
    case TL_ENT_LINK:
      return LINK_LENGTH;

    default:
      return e->length_in_characters;
  }
}

static inline gboolean
is_weighted_character (gunichar ch) {
  // Based on https://developer.twitter.com/en/docs/developer-utilities/twitter-text
  // then the following ranges count as "1", everything else is "2":
  //   * 0 - 4351 (0x0 - 0x10FF) = Latin through to Georgian
  //   * 8192 - 8205 (0x2000 - 0x200D) = Unicode spaces
  //   * 8208 - 8223 (0x2010 - 0x201F) = Unicode hyphens and smart quotes
  //   * 8242 - 8247 (0x2032 - 0x2037) = Prime marks
  return !((ch >= 0    && ch <= 4351) ||
           (ch >= 8192 && ch <= 8205) ||
           (ch >= 8208 && ch <= 8223) ||
           (ch >= 8242 && ch <= 8247));
}

static inline guint
chartype_for_char (gunichar c)
{
  if (c == 0x200D) {
    return CHARTYPE_ZWJ;
  }
  else if (!is_weighted_character (c)) {
    return CHARTYPE_UNWEIGHTED;
  }
  else if (c == 0xFE0F) {
    return CHARTYPE_VS16;
  }
  else if ((c >= 0x1100 && c < 0x2000) || (c >= 0x2800 && c <= 0x1F1E5 && c != 0x2B1B)) {
    // Hangul Jamo through Greek Extended
    // and Braille Patterns through Enclosed Alphanumeric Supplemental (that aren't Regional Indicators)
    // We specifically exclude U+2B1B to keep the range as big as possible
    return CHARTYPE_WEIGHTED_OTHER;
  }
  else if (c >= 0x1F3FB && c <= 0x1F3FF) {
    return CHARTYPE_FITZPATRICK;
  }
  else if (c == 0x1f466 || c == 0x1f467) {
    return CHARTYPE_CHILD;
  }
  else if (c == 0x1F468) {
    return CHARTYPE_MAN;
  }
  else if (c == 0x1F469) {
    return CHARTYPE_WOMAN;
  }
  else if (c == 0x1F9D1) {
    return CHARTYPE_UNGENDERED_ADULT;
  }
  else if (c == 0x26F9
           || c == 0x1F3C3
           || c == 0x1F3C4
           || (c >= 0x1F3CA && c == 0x1F3CC)
           || c == 0x1F46E
           || c == 0x1F470
           || c == 0x1F471
           || c == 0x1F473
           || c == 0x1F477
           || c == 0x1F481
           || c == 0x1F482
           || c == 0x1F486
           || c == 0x1F487
           || c == 0x1F575
           || (c >= 0x1F645 && c<= 0x1F647)
           || c == 0x1F64B
           || c == 0x1F64D
           || c == 0x1F64E
           || c == 0x1F6A3
           || (c >= 0x1F6B4 && c <= 0x1F6B6)
           || c == 0x1F926
           || c == 0x1F935
           || (c >= 0x1F937 && c <= 0x1F939)
           || c == 0x1F93D
           || c == 0x1F93E
           || c == 0x1F9B8
           || c == 0x1F9B9
           || (c >= 0x1F9CD && c <= 0x1F9CF)
           || (c >= 0x1F9D6 && c <= 0x1F9DE)
           ) {
    return CHARTYPE_GENDERABLE_PERSON;
  }
  else if (c == 0x1F46F || c == 0x1F93C || c == 0x1F9DD) {
    // Zombies, wrestlers and bunnie people, oh my!
    return CHARTYPE_UNTONED_GENDERABLE_PERSON;
  }
  else if (c == 0x261D
           || (c >= 0x270A && c<= 0x270C)
           || c == 0x270D
           || c == 0x1F385
           || c == 0x1F3C2
           || c == 0x1F3C7
           || c == 0x1F442
           || c == 0x1F443
           || (c >= 0x1F446 && c <= 0x1F450)
           || (c >= 0x1F466 && c <= 0x1F46D)
           || c == 0x1F47C
           || c == 0x1F483
           || c == 0x1F485
           || c == 0x1F48F
           || c == 0x1F491
           || c == 0x1F4AA
           || c == 0x1F574
           || c == 0x1F57A
           || c == 0x1F590
           || c == 0x1F595
           || c == 0x1F596
           || c == 0x1F64C
           || c == 0x1F6C0
           || c == 0x1F6CC
           || c == 0x1F90C
           || c == 0x1F90F
           || c == 0x1F918
           || (c >= 0x1F919 && c <= 0x1F91E)
           || c == 0x1F91F
           || (c >= 0x1F930 && c <= 0x1F934)
           || c == 0x1F936
           || c == 0x1F977
           || c == 0x1F9B5
           || c == 0x1F9B6
           || c == 0x1F9BB
           || (c >= 0x1F9D1 && c<= 0x1F9D5)) {
    return CHARTYPE_PERSON;
  }
  else if (c == 0xE007F) {
    return CHARTYPE_TAG_CLOSE;
  }
  else if (c == 0x1F33E
           || c == 0x1F373
           || c == 0x1F37C
           || c == 0x1F393
           || c == 0x1F3A4
           || c == 0x1F3A8
           || c == 0x1F3EB
           || c == 0x1F3ED
           || c == 0x1F4BB
           || c == 0x1F4BC
           || c == 0x1F527
           || c == 0x1F52C
           || c == 0x1F680
           || c == 0x1F692
           || c == 0x1F9AF
           || c == 0x1F9BC
           || c == 0x1F9BD
          ) {
    return CHARTYPE_JOB;
  }
  else if (c == 0x2695 || c == 0x2696 || c == 0x2708) {
    return CHARTYPE_JOB_TEXT;
  }
  else if (c >= 0x1F1E6 && c <= 0x1F1FF) {
    return CHARTYPE_REGIONAL_INDICATOR;
  }
  else if (c == 0x1F3F3) {
    return CHARTYPE_WHITE_FLAG;
  }
  else if (c == 0x1F3F4) {
    return CHARTYPE_BLACK_FLAG;
  }
  else if (c == 0x1F308) {
    return CHARTYPE_RAINBOW;
  }
  else if (c == 0x26A7) {
    return CHARTYPE_TRANSGENDER_SYMBOL;
  }
  else if (c == 0x2620) {
    return CHARTYPE_SKULL_AND_CROSSBONES;
  }
  else if (c == 0x2764) {
    return CHARTYPE_HEART;
  }
  else if (c == 0x1F48B) {
    return CHARTYPE_KISS_MARK;
  }
  else if (c >= 0x1F9B0 && c <= 0x1F9B3) {
    return CHARTYPE_HAIRSTYLE;
  }
  else if (c == 0x2640 || c == 0x2642) {
    return CHARTYPE_GENDER_TEXT;
  }
  else if (c == 0x1F384) {
    return CHARTYPE_CHRISTMAS_TREE;
  }
  else if (c == 0x1F408) {
    return CHARTYPE_CAT;
  }
  else if (c == 0x1F415) {
    return CHARTYPE_DOG;
  }
  else if (c == 0x1F43B) {
    return CHARTYPE_BEAR;
  }
  else if (c == 0x1F9BA) {
    return CHARTYPE_SAFETY_VEST;
  }
  else if (c == 0x2B1B) {
    return CHARTYPE_COLOUR_BLACK;
  }
  else if (c == 0x2744) {
    return CHARTYPE_SNOWFLAKE;
  }
  else if ((c >= 0xE0030 && c <= 0xE0039)
            || (c >= 0xE0041 && c <= 0xE005A)
            || (c >= 0xE0061 && c <= 0xE007A)) {
    // Capital letters and digits, as per https://www.unicode.org/L2/L2015/15190-pri299-additional-flags-bkgnd.html
    // But Twitter takes lower-case
    return CHARTYPE_TAG;
  }
  else {
#ifdef LIBTL_DEBUG
    g_debug("Fell through to \"other\" for 0x%08X", c);
#endif
    return CHARTYPE_WEIGHTED_OTHER;
  }
}

/*
 * tokenize:
 *
 * Returns: (transfer full): Tokens
 */
static GArray *
tokenize (const char *input,
          gsize       length_in_bytes,
          gboolean    compact_emoji)
{
  GArray *tokens = g_array_new (FALSE, TRUE, sizeof (Token));
  const char *p = input;
  gsize cur_character_index = 0;
  GHashTable *chartype_map = get_chartype_options();

  while (p - input < (long)length_in_bytes) {
    const char *cur_start = p;
    gunichar cur_char = g_utf8_get_char (p);
    gsize cur_length = 0;
    gsize length_in_chars = 0;
    gsize length_in_weighted_chars = 0;
    guint last_token_type = 0;
    guint prev_char_type = CHARTYPE_NONE;
    guint cur_char_type = CHARTYPE_NONE;
    guint carry_weight = 0;
    gboolean is_zwjed = FALSE;
    gboolean matched = FALSE;
    gunichar prev_ri_char = '\0';
    CharTypeOption *data;

    /* If this char already splits, it's a one-char token */
    if (char_splits (cur_char)) {
      const char *old_p = p;
      p = g_utf8_next_char (p);
      emplace_token (tokens, cur_start, p - old_p, cur_character_index, 1, is_weighted_character (cur_char) ? WEIGHTED_VALUE : UNWEIGHTED_VALUE);
      cur_character_index ++;
      continue;
    }

    last_token_type = token_type_from_char (cur_char);

    do {
      if (compact_emoji) {
        matched = FALSE;
        cur_char_type = chartype_for_char (cur_char);

        if (cur_char_type == CHARTYPE_ZWJ) {
          if (!is_zwjed) {
            matched = TRUE;
            is_zwjed = TRUE;
            carry_weight += UNWEIGHTED_VALUE;
          }
          cur_char_type = prev_char_type;
        }
        else if (cur_char_type == CHARTYPE_REGIONAL_INDICATOR) {
          if (prev_char_type == CHARTYPE_REGIONAL_INDICATOR && is_valid_regional_indicator (prev_ri_char, cur_char)) {
            matched = TRUE;
            cur_char_type = CHARTYPE_REGIONAL_INDICATOR_FLAG;
          }
          prev_ri_char = cur_char;
        }
        else {
          if (is_zwjed || cur_char_type == CHARTYPE_FITZPATRICK || cur_char_type == CHARTYPE_VS16
              || cur_char_type == CHARTYPE_TAG || prev_char_type == CHARTYPE_TAGGED_FLAG) {
            data = g_hash_table_lookup(chartype_map, MAKE_KEY(prev_char_type, cur_char_type));

            if (data != NULL) {
              matched = TRUE;
              int char_carry_weight = data->carry_weight;
              cur_char_type = data->new_chartype;
              if (char_carry_weight == END_SEQUENCE_WEIGHT) {
                // It was a completing character
                carry_weight = 0;
              }
              else {
                carry_weight += char_carry_weight;
              }
            }
            // Else it didn't have a mapping
          }

          is_zwjed = FALSE;
        }

        if (!matched) {
          // If we didn't match a rule then any partially built sequence (carry_weight)
          length_in_weighted_chars += carry_weight + (is_weighted_character (cur_char) ? WEIGHTED_VALUE : UNWEIGHTED_VALUE);
          carry_weight = 0;
        }

        prev_char_type = cur_char_type;
      }
      else {
        length_in_weighted_chars += is_weighted_character (cur_char) ? WEIGHTED_VALUE : UNWEIGHTED_VALUE;
      }

      const char *old_p = p;
      p = g_utf8_next_char (p);
      cur_char = g_utf8_get_char (p);
      cur_length += p - old_p;
      length_in_chars ++;

      if (token_type_from_char (cur_char) != last_token_type) {
        length_in_weighted_chars += carry_weight;
        carry_weight = 0;
        break;
      }

    } while (!char_splits (cur_char) &&
             p - input < (long)length_in_bytes);

    length_in_weighted_chars += carry_weight;
    emplace_token (tokens, cur_start, cur_length, cur_character_index, length_in_chars, length_in_weighted_chars);

    cur_character_index += length_in_chars;
  }

  return g_steal_pointer (&tokens);
}

static gboolean
parse_link_tail (GArray      *entities,
                 const Token *tokens,
                 gsize        n_tokens,
                 guint       *current_position)
{
  guint i = *current_position;
  const Token *t;

  gsize paren_level = 0;
  int first_paren_index = -1;
  for (;;) {
    t = &tokens[i];

    if (t->type == TOK_WHITESPACE || t->type == TOK_APOSTROPHE) {
      i --;
      break;
    }

    if (tokens[i].type == TOK_OPEN_PAREN) {

      if (first_paren_index == -1) {
        first_paren_index = i;
      }
      paren_level ++;
      if (paren_level == 3) {
        break;
      }
    } else if (tokens[i].type == TOK_CLOSE_PAREN) {
      if (first_paren_index == -1) {
        first_paren_index = i;
      }
      paren_level --;
    }

    i ++;

    if (i == n_tokens) {
      i --;
      break;
    }
  }

  if (paren_level != 0) {
    g_assert (first_paren_index != -1);
    i = first_paren_index - 1; // Before that paren
  }

  t = &tokens[i];
  /* Whatever happened, don't count trailing punctuation */
  if (token_in (t, INVALID_AFTER_URL_CHARS)) {
    i --;
  }

  *current_position = i;

  return TRUE;
}


// Returns whether a link has been parsed or not.
static gboolean
parse_link (GArray      *entities,
            const Token *tokens,
            gsize        n_tokens,
            guint       *current_position)
{
  guint i = *current_position;
  const Token *t;
  guint start_token = *current_position;
  guint end_token;
  gboolean has_protocol = FALSE;

  t = &tokens[i];

  // Some may not even appear before a protocol
  if (i > 0 && token_in (&tokens[i - 1], INVALID_BEFORE_URL_CHARS)) {
    return FALSE;
  }

  if (token_is_protocol (t)) {
    // need "://" now.
    t = &tokens[i + 1];
    if (t->type != TOK_COLON) {
      return FALSE;
    }
    i ++;

    t = &tokens[i + 1];
    if (t->type != TOK_SLASH) {
      return FALSE;
    }
    i ++;

    t = &tokens[i + 1];
    if (t->type != TOK_SLASH) {
      return FALSE;
    }
    // If we are at the end now, this is not a link, just the protocol.
    if (i + 1 == n_tokens - 1) {
      return FALSE;
    }
    i += 2; // Skip to token after second slash
    has_protocol = TRUE;
  } else {
    // Lookbehind: Token before may not be an @, they are not supported.
    if (i > 0 && token_in (&tokens[i - 1], INVALID_BEFORE_NON_PROTOCOL_URL_CHARS)) {
      return FALSE;
    }
  }

  if (token_in (&tokens[i], INVALID_URL_CHARS)) {
    return FALSE;
  }

  // Now read until .tld. There can be multiple (e.g. in http://foobar.com.com.com"),
  // so we need to do this in a greedy way.
  guint tld_index = i;
  guint tld_iter = i;
  gboolean tld_found = FALSE;
  guint fragment_length = 0;

  while (tld_iter < n_tokens - 1) {
    const Token *t = &tokens[tld_iter];

    if (t->type == TOK_WHITESPACE) {
      if (!tld_found) {
        return FALSE;
      }
    }

    if (!(t->type == TOK_NUMBER ||
          t->type == TOK_TEXT ||
          t->type == TOK_DOT ||
          t->type == TOK_DASH)) {
      if (!tld_found) {
        return FALSE;
      } else {
        break;
      }
    }

    if (t->type != TOK_DOT) {
      // Approximate some rules for handling Punycode. This may not be perfect, but it should be good enough and rarely hit.
      // And it passes Twitter's test case!
      if (t->length_in_characters != t->length_in_weighted_characters) {
        gsize unicode_chars = t->length_in_weighted_characters - t->length_in_characters;
        gsize ascii_ish_chars = t->length_in_characters - unicode_chars;
        fragment_length += ascii_ish_chars + ((((unicode_chars * 100) / 5) * 6) / 100) + 1;
      }
      else {
        fragment_length += t->length_in_characters;
      }
      if (fragment_length > 63) {
        return FALSE;
      }
    }
    else {
      fragment_length = 0;
    }

    if (t->type == TOK_DOT &&
        token_is_tld (&tokens[tld_iter + 1], has_protocol)) {
      tld_index = tld_iter;
      tld_found = TRUE;
    }

    tld_iter ++;
  }

  if (tld_index >= n_tokens - 1 ||
      !tld_found ||
      token_in (&tokens[tld_index - 1], INVALID_URL_CHARS)) {
    return FALSE;
  }

  // tld_index is the TOK_DOT
  g_assert (tokens[tld_index].type == TOK_DOT);
  i = tld_index + 1;

  // If the next token is a colon, we are reading a port
  if (i < n_tokens - 1 && tokens[i + 1].type == TOK_COLON) {
    i ++; // i == COLON
    if (tokens[i + 1].type != TOK_NUMBER) {
      // According to twitter.com, the link reaches until before the COLON
      i --;
    } else {
      // Skip port number
      i ++;
    }
  }

  // To continue a link, the next token must be a slash or a question mark
  // If it isn't, we stop here.
  if (i < n_tokens - 1) {
    // A trailing slash is part of the link, other punctuation is not.
    if (tokens[i + 1].type == TOK_SLASH ||
        tokens[i + 1].type == TOK_QUESTIONMARK) {
      i ++;

      if (i < n_tokens - 1) {
        if (!parse_link_tail (entities, tokens, n_tokens, &i)) {
          return FALSE;
        }
      } else if (tokens[i].type == TOK_QUESTIONMARK) {
        // Trailing questionmark is not part of the link
        i --;
      }
    } else if (tokens[i + 1].type == TOK_AT) {
      // We cannot just return FALSE for all non-slash/non-questionmark tokens here since
      // The Rules say some of them make a link until this token and some of them cause the
      // entire parsing to produce no link at all, like in the @ case (don't want to turn
      // email addresses into links).
      return FALSE;
    }
  }

  end_token = i;
  g_assert (end_token < n_tokens);

  emplace_entity_for_tokens (entities,
                             tokens,
                             TL_ENT_LINK,
                             start_token,
                             end_token);

  *current_position = end_token + 1; // Hop to the next token!

  return TRUE;
}

static gboolean
parse_mention (GArray      *entities,
               const Token *tokens,
               gsize        n_tokens,
               guint       *current_position)
{
  guint i = *current_position;
  const guint start_token = i;
  guint end_token;

  g_assert (tokens[i].type == TOK_AT);

  // Lookback at the previous token. If it was a text token
  // without whitespace between, this is not going to be a mention...
  if (i > 0) {
    // Text tokens before an @-token generally destroy the mention,
    // except in a few cases...
    if (tokens[i - 1].type == TOK_TEXT &&
        !token_in (&tokens[i - 1], VALID_BEFORE_MENTION_CHARS) &&
        !token_ends_in_accented (&tokens[i - 1])) {
      return FALSE;
    }

    // Numbers and special invalid chars always ruin the mention
    if (tokens[i - 1].type == TOK_NUMBER ||
        token_in (&tokens[i - 1], INVALID_BEFORE_MENTION_CHARS)) {
      return FALSE;
    }
  }

  // Skip @
  i ++;

  for (;;) {
    if (i >= n_tokens) {
      i --;
      break;
    }

    if (token_in (&tokens[i], INVALID_MENTION_CHARS)) {
      i --;
      break;
    }

    if (tokens[i].type != TOK_TEXT &&
        tokens[i].type != TOK_NUMBER &&
        tokens[i].type != TOK_UNDERSCORE) {
      i --;
      break;
    }

    if (tokens[i].type == TOK_TEXT) {
      const char *text = tokens[i].start;
      // Special rules apply about what characters may appear in a @screen_name
      const char *p = text;

      while (p - text < (long)tokens[i].length_in_bytes) {
        gunichar c = g_utf8_get_char (p);

        if (!is_valid_mention_char (c)) {
          return FALSE;
        }

        p = g_utf8_next_char (p);
      }

    }

    i ++;
  }

  if (i == start_token) {
    return FALSE;
  }

  // Mentions ending in an '@' are no mentions, e.g. @_@
  if (i < n_tokens - 1 &&
      tokens[i + 1].type == TOK_AT) {
    return FALSE;
  }

  end_token = i;
  g_assert (end_token < n_tokens);

  emplace_entity_for_tokens (entities,
                             tokens,
                             TL_ENT_MENTION,
                             start_token,
                             end_token);

  *current_position = end_token + 1; // Hop to the next token!

  return TRUE;
}

static gboolean
parse_hashtag (GArray      *entities,
               const Token *tokens,
               gsize        n_tokens,
               guint       *current_position)
{
  gsize i = *current_position;
  const guint start_token = i;
  guint end_token;
  gboolean text_found = FALSE;

  g_assert (tokens[i].type == TOK_HASH);

  // Lookback at the previous token. If it was a text token
  // without whitespace between, this is not going to be a mention...
  if (i > 0 && tokens[i - 1].type == TOK_TEXT &&
      !token_in (&tokens[i - 1], VALID_BEFORE_HASHTAG_CHARS)) {
    return FALSE;
  }

  // Some chars make the entire hashtag invalid
  if (i > 0 && token_in (&tokens[i - 1], INVALID_BEFORE_HASHTAG_CHARS)) {
    return FALSE;
  }

  //skip #
  i ++;

  for (; i < n_tokens; i ++) {
    if (token_in (&tokens[i], INVALID_HASHTAG_CHARS)) {
      break;
    }

    if (tokens[i].type != TOK_TEXT &&
        tokens[i].type != TOK_NUMBER &&
        tokens[i].type != TOK_UNDERSCORE) {
      break;
    }

    text_found |= tokens[i].type == TOK_TEXT;
  }

  if (!text_found) {
    return FALSE;
  }

  end_token = i - 1;
  g_assert (end_token < n_tokens);

  emplace_entity_for_tokens (entities,
                             tokens,
                             TL_ENT_HASHTAG,
                             start_token,
                             end_token);

  *current_position = end_token + 1; // Hop to the next token!

  return TRUE;
}

/*
 * parse:
 *
 * Returns: (transfer full): list of tokens
 */
static GArray *
parse (const Token *tokens,
       gsize        n_tokens,
       gboolean     extract_text_entities,
       guint       *n_relevant_entities)
{
  GArray *entities = g_array_new (FALSE, TRUE, sizeof (TlEntity));
  guint i = 0;
  guint relevant_entities = 0;

  while (i < n_tokens) {
    const Token *token = &tokens[i];

    // We always have to do this since links can begin with whatever word
    if (parse_link (entities, tokens, n_tokens, &i)) {
      relevant_entities ++;
      continue;
    }

    switch (token->type) {
      case TOK_AT:
        if (parse_mention (entities, tokens, n_tokens, &i)) {
          relevant_entities ++;
          continue;
        }
      break;

      case TOK_HASH:
        if (parse_hashtag (entities, tokens, n_tokens, &i)) {
          relevant_entities ++;
          continue;
        }
      break;
    }

    if (extract_text_entities &&
        token->type == TOK_TEXT) {
      relevant_entities ++;
    }

    emplace_entity_for_tokens (entities,
                               tokens,
                               token->type == TOK_TEXT ? TL_ENT_TEXT : TL_ENT_WHITESPACE,
                               i, i);

    i ++;
  }

  if (n_relevant_entities) {
    *n_relevant_entities = relevant_entities;
  }

  return entities;
}

static gsize
count_entities_in_characters (GArray *entities)
{
  guint i;
  gsize sum = 0;

  for (i = 0; i < entities->len; i ++) {
    const TlEntity *e = &g_array_index (entities, TlEntity, i);

    sum += entity_length_in_characters (e);
  }

  return sum;
}

/*
 * tl_count_chars:
 * input: (nullable): NUL-terminated tweet text
 *
 * Returns: The length of @input, in characters.
 */
gsize
tl_count_characters (const char *input)
{
  if (input == NULL || input[0] == '\0') {
    return 0;
  }

  return tl_count_characters_n (input, strlen (input));
}

/*
 * tl_count_characters_n:
 * input: (nullable): Text to measure
 * length_in_bytes: Length of @input, in bytes.
 *
 * Returns: The length of @input, in characters.
 */
gsize
tl_count_characters_n (const char *input,
                       gsize       length_in_bytes)
{
  GArray *tokens;
  const Token *token_array;
  gsize n_tokens;
  GArray *entities;
  gsize length;

  if (input == NULL || input[0] == '\0') {
    return 0;
  }

  // From here on, input/length_in_bytes are trusted to be OK
  tokens = tokenize (input, length_in_bytes, FALSE);

  n_tokens = tokens->len;
  token_array = (const Token *)g_array_free (tokens, FALSE);

  entities = parse (token_array, n_tokens, FALSE, NULL);

  length = count_entities_in_characters (entities);
  g_array_free (entities, TRUE);
  g_free ((char *)token_array);

  return length;
}

static inline gsize
entity_length_in_weighted_characters (const TlEntity *e)
{
  switch (e->type) {
    case TL_ENT_LINK:
      return LINK_LENGTH;

    default:
      return e->length_in_weighted_characters;
  }
}

static gsize
count_entities_in_weighted_characters (GArray *entities)
{
  guint i;
  gsize sum = 0;

  for (i = 0; i < entities->len; i ++) {
    const TlEntity *e = &g_array_index (entities, TlEntity, i);

    sum += entity_length_in_weighted_characters (e);
  }

  return sum;
}

/*
 * tl_count_weighted_chararacters:
 * input: (nullable): NUL-terminated tweet text
 * count_mode: COUNT_BASIC to do a dumb weighting count,
 *    COUNT_SHORT_URLS to do dumb weighting count but with URLs only counting as short url
 *    or COUNT_COMPACT for full short URL and compact emoji behaviour
 *
 * Returns: The length of @input, in Twitter's weighted characters.
 */
gsize
tl_count_weighted_characters (const char *input, guint count_mode)
{
  if (input == NULL || input[0] == '\0') {
    return 0;
  }

  char *normalised = g_utf8_normalize (input, -1, G_NORMALIZE_DEFAULT_COMPOSE);
  gsize size = 0;

  if (count_mode == COUNT_SHORT_URLS) {
    size = tl_count_weighted_characters_n (normalised, strlen (normalised), FALSE);
  }
  else if (count_mode == COUNT_COMPACT) {
    size = tl_count_weighted_characters_n (normalised, strlen (normalised), TRUE);
  }
  else {
    const char *p = normalised;
    gunichar c;

    c = g_utf8_get_char (p);
    while (c != '\0') {
      size += is_weighted_character (c) ? WEIGHTED_VALUE : UNWEIGHTED_VALUE;
      p = g_utf8_next_char (p);
      c = g_utf8_get_char (p);
    }
  }

  g_free(normalised);
  return size;
}

/*
 * tl_count_weighted_characters_n:
 * input: (nullable): Text to measure
 * length_in_bytes: Length of @input, in bytes.
 * compact_emoji: whether to count joined emoji as a compacted single character
 *
 * Returns: The length of @input, in characters.
 */
gsize
tl_count_weighted_characters_n (const char *input,
                                gsize       length_in_bytes,
                                gboolean    compact_emoji)
{
  GArray *tokens;
  const Token *token_array;
  gsize n_tokens;
  GArray *entities;
  gsize length;

  if (input == NULL || input[0] == '\0') {
    return 0;
  }

  // From here on, input/length_in_bytes are trusted to be OK
  tokens = tokenize (input, length_in_bytes, compact_emoji);

  n_tokens = tokens->len;
  token_array = (const Token *)g_array_free (tokens, FALSE);

  entities = parse (token_array, n_tokens, FALSE, NULL);

  length = count_entities_in_weighted_characters (entities);
  g_array_free (entities, TRUE);
  g_free ((char *)token_array);

  return length;
}

/**
 * tl_extract_entities:
 * @input: The input text to extract entities from
 * @out_n_entities: (out): Location to store the amount of entities in the returned
 *   array. If 0, the return value is %NULL.
 * @out_text_length: (out) (optional): Return location for the complete
 *   length of @input, in characters. This is the same value one would
 *   get from calling tl_count_characters() or tl_count_characters_n()
 *   on @input.
 *
 * Returns: An array of #TlEntity. If no entities are found, %NULL is returned.
 */
TlEntity *
tl_extract_entities (const char *input,
                     gsize      *out_n_entities,
                     gsize      *out_text_length)
{
  gsize dummy;

  g_return_val_if_fail (out_n_entities != NULL, NULL);

  if (out_text_length == NULL) {
    out_text_length = &dummy;
  }

  if (input == NULL || input[0] == '\0') {
    *out_n_entities = 0;
    *out_text_length = 0;
    return NULL;
  }

  return tl_extract_entities_n (input, strlen (input), out_n_entities, out_text_length);
}


static TlEntity *
tl_extract_entities_internal (const char *input,
                              gsize       length_in_bytes,
                              gsize      *out_n_entities,
                              gsize      *out_text_length,
                              gboolean    extract_text_entities)
{
  GArray *tokens;
  const Token *token_array;
  gsize n_tokens;
  GArray *entities;
  guint n_relevant_entities;
  TlEntity *result_entities;
  guint result_index = 0;

  tokens = tokenize (input, length_in_bytes, FALSE);

#ifdef LIBTL_DEBUG
  g_debug ("############ %s: %.*s", __FUNCTION__, (guint)length_in_bytes, input);
  for (guint i = 0; i < tokens->len; i ++) {
    const Token *t = &g_array_index (tokens, Token, i);
    g_debug ("Token %u: Type: %d, Length: %u, Text:%.*s, start char: %u, chars: %u", i, t->type, (guint)t->length_in_bytes,
         (int)t->length_in_bytes, t->start, (guint)t->start_character_index, (guint)t->length_in_characters);
  }
#endif

  n_tokens = tokens->len;
  token_array = (const Token *)g_array_free (tokens, FALSE);
  entities = parse (token_array, n_tokens, extract_text_entities, &n_relevant_entities);

  *out_text_length = count_entities_in_characters (entities);
  g_free ((char *)token_array);

#ifdef LIBTL_DEBUG
  for (guint i = 0; i < entities->len; i ++) {
    const TlEntity *e = &g_array_index (entities, TlEntity, i);
    g_debug ("TlEntity %u: Text: '%.*s', Type: %u, Bytes: %u, Length: %u, start character: %u", i, (int)e->length_in_bytes, e->start,
               e->type, (guint)e->length_in_bytes, (guint)entity_length_in_characters (e), (guint)e->start_character_index);
  }
#endif

  // Only pass mentions, hashtags and links out
  result_entities = g_malloc (sizeof (TlEntity) * n_relevant_entities);
  for (guint i = 0; i < entities->len; i ++) {
    const TlEntity *e = &g_array_index (entities, TlEntity, i);
    switch (e->type) {
      case TL_ENT_LINK:
      case TL_ENT_HASHTAG:
      case TL_ENT_MENTION:
        memcpy (&result_entities[result_index], e, sizeof (TlEntity));
        result_index ++;
      break;

      case TL_ENT_TEXT:
        if (extract_text_entities) {
          memcpy (&result_entities[result_index], e, sizeof (TlEntity));
          result_index ++;
        }
      break;

      default: {}
    }
  }

  *out_n_entities = n_relevant_entities;
  g_array_free (entities, TRUE);

  return result_entities;
}

/**
 * tl_extract_entities_n:
 * @input: The input text to extract entities from
 * @length_in_bytes: The length of @input, in bytes
 * @out_n_entities: (out): Location to store the amount of entities in the returned
 *   array. If 0, the return value is %NULL.
 * @out_text_length: (out) (optional): Return location for the complete
 *   length of @input, in characters. This is the same value one would
 *   get from calling tl_count_characters() or tl_count_characters_n()
 *   on @input.
 *
 * Returns: An array of #TlEntity. If no entities are found, %NULL is returned.
 */
TlEntity *
tl_extract_entities_n (const char *input,
                       gsize       length_in_bytes,
                       gsize      *out_n_entities,
                       gsize      *out_text_length)
{
  gsize dummy;

  g_return_val_if_fail (out_n_entities != NULL, NULL);

  if (out_text_length == NULL) {
    out_text_length = &dummy;
  }

  if (input == NULL || input[0] == '\0') {
    *out_n_entities = 0;
    *out_text_length = 0;
    return NULL;
  }

  return tl_extract_entities_internal (input,
                                       length_in_bytes,
                                       out_n_entities,
                                       out_text_length,
                                       FALSE);
}

/**
 * tl_extract_entities_and_text:
 * @input: The input text to extract entities from
 * @out_n_entities: (out): Location to store the amount of entities in the returned
 *   array. If 0, the return value is %NULL.
 * @out_text_length: (out) (optional): Return location for the complete
 *   length of @input, in characters. This is the same value one would
 *   get from calling tl_count_characters() or tl_count_characters_n()
 *   on @input.
 *
 * This is different from tl_extract_entities() in that it returns all entities
 * and not just hashtags, links and mentions. This allows for further post-processing
 * from the caller.
 *
 * Returns: An array of #TlEntity. If no entities are found, %NULL is returned.
 */
TlEntity *
tl_extract_entities_and_text (const char *input,
                              gsize      *out_n_entities,
                              gsize      *out_text_length)
{
  gsize dummy;

  g_return_val_if_fail (out_n_entities != NULL, NULL);

  if (out_text_length == NULL) {
    out_text_length = &dummy;
  }

  if (input == NULL || input[0] == '\0') {
    *out_n_entities = 0;
    *out_text_length = 0;
    return NULL;
  }

  return tl_extract_entities_internal (input,
                                       strlen (input),
                                       out_n_entities,
                                       out_text_length,
                                       TRUE);
}

/**
 * tl_extract_entities_and_text_n:
 * @input: The input text to extract entities from
 * @length_in_bytes: The length of @input, in bytes
 * @out_n_entities: (out): Location to store the amount of entities in the returned
 *   array. If 0, the return value is %NULL.
 * @out_text_length: (out) (optional): Return location for the complete
 *   length of @input, in characters. This is the same value one would
 *   get from calling tl_count_characters() or tl_count_characters_n()
 *   on @input.
 *
 * This is different from tl_extract_entities_n() in that it returns all entities
 * and not just hashtags, links and mentions. This allows for further post-processing
 * from the caller.
 *
 * Returns: An array of #TlEntity. If no entities are found, %NULL is returned.
 */
TlEntity *
tl_extract_entities_and_text_n (const char *input,
                                gsize       length_in_bytes,
                                gsize      *out_n_entities,
                                gsize      *out_text_length)
{
  gsize dummy;

  g_return_val_if_fail (out_n_entities != NULL, NULL);

  if (out_text_length == NULL) {
    out_text_length = &dummy;
  }

  if (input == NULL || input[0] == '\0') {
    *out_n_entities = 0;
    *out_text_length = 0;
    return NULL;
  }

  return tl_extract_entities_internal (input,
                                       length_in_bytes,
                                       out_n_entities,
                                       out_text_length,
                                       TRUE);
}
