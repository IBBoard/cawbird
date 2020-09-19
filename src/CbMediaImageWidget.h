/*  This file is part of Cawbird, a Gtk+ linux Twitter client forked from Corebird.
 *  Copyright (C) 2017 Timm Bäder (Corebird)
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

#ifndef _CB_MEDIA_IMAGE_WIDGET_H_
#define _CB_MEDIA_IMAGE_WIDGET_H_

#include <gtk/gtk.h>
#include "CbMedia.h"
#include "CbMediaDownloader.h"

#define CB_TYPE_MEDIA_IMAGE_WIDGET cb_media_image_widget_get_type ()
G_DECLARE_FINAL_TYPE (CbMediaImageWidget, cb_media_image_widget, CB, MEDIA_IMAGE_WIDGET, GtkScrolledWindow);

struct _CbMediaImageWidget
{
  GtkScrolledWindow parent_instance;

  GtkWidget *image;
  GtkGesture *drag_gesture;

  cairo_surface_t *image_surface;

  double drag_start_hvalue;
  double drag_start_vvalue;

  CbMedia *media;
  gulong hires_progress_id;
};
typedef struct _CbMediaImageWidget CbMediaImageWidget;

GtkWidget * cb_media_image_widget_new       (CbMedia *media, GdkRectangle *max_dimensions);

#endif
