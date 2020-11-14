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

#ifndef MEDIA_H
#define MEDIA_H

#include <glib-object.h>
#include <cairo-gobject.h>
#include <gdk-pixbuf/gdk-pixbuf.h>

G_BEGIN_DECLS

typedef enum {
  CB_MEDIA_TYPE_IMAGE,
  CB_MEDIA_TYPE_GIF,
  CB_MEDIA_TYPE_ANIMATED_GIF,
  CB_MEDIA_TYPE_TWITTER_VIDEO,
  CB_MEDIA_TYPE_INSTAGRAM_VIDEO,

  CB_MEDIA_TYPE_UNKNOWN
} CbMediaType;


struct _CbMedia
{
  GObject parent_instance;

  char *url;
  char *thumb_url;
  char *target_url;
  char *alt_text;

  int width;
  int height;
  int thumb_width;
  int thumb_height;

  gchar *consumer_key;
  gchar *consumer_secret;
  gchar *token;
  gchar *token_secret;

  CbMediaType type;
  guint loading: 1;
  guint loaded : 1;
  guint loading_hires: 1;
  guint loaded_hires : 1;
  guint invalid : 1;
  double percent_loaded;
  double percent_loaded_hires;

  cairo_surface_t *surface;
  cairo_surface_t *surface_hires;
  GdkPixbufAnimation *animation;
};

typedef struct _CbMedia CbMedia;

#define CB_TYPE_MEDIA cb_media_get_type ()
G_DECLARE_FINAL_TYPE (CbMedia, cb_media, CB, MEDIA, GObject);

CbMedia *   cb_media_new              (void);
gboolean    cb_media_is_video         (CbMedia *media);
gboolean    cb_media_requires_authentication (CbMedia *media);
void        cb_media_loading_finished (CbMedia *media);
void        cb_media_update_progress  (CbMedia *media,
                                       double   progress);
void        cb_media_loading_hires_finished (CbMedia *media);
void        cb_media_update_hires_progress (CbMedia *media,
                                            double   progress);
CbMediaType cb_media_type_from_url    (const char *url);
cairo_surface_t * cb_media_get_highest_res_surface (CbMedia *media);

G_END_DECLS

#endif
