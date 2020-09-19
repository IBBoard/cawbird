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
#include "CbMediaImageWidget.h"

G_DEFINE_TYPE (CbMediaImageWidget, cb_media_image_widget, GTK_TYPE_SCROLLED_WINDOW)

static void
cb_media_image_widget_finalize (GObject *object)
{
  CbMediaImageWidget *self = CB_MEDIA_IMAGE_WIDGET (object);

  g_clear_object (&self->drag_gesture);
  if (self->image_surface != NULL) {
    cairo_surface_destroy(self->image_surface);
  }

  if (self->media && self->hires_progress_id) {
    g_signal_handler_disconnect (self->media, self->hires_progress_id);
  }

  G_OBJECT_CLASS (cb_media_image_widget_parent_class)->finalize (object);
}


static void
drag_begin_cb (GtkGestureDrag *gesture,
               double          start_x,
               double          start_y,
               gpointer        user_data)
{
  CbMediaImageWidget *self = user_data;
  GtkAdjustment *adjustment;

  adjustment = gtk_scrolled_window_get_hadjustment (GTK_SCROLLED_WINDOW (self));
  self->drag_start_hvalue = gtk_adjustment_get_value (adjustment);

  adjustment = gtk_scrolled_window_get_vadjustment (GTK_SCROLLED_WINDOW (self));
  self->drag_start_vvalue = gtk_adjustment_get_value (adjustment);

  gtk_gesture_set_state (GTK_GESTURE (gesture), GTK_EVENT_SEQUENCE_CLAIMED);
}

static void
drag_update_cb (GtkGestureDrag *gesture,
                double          offset_x,
                double          offset_y,
                gpointer        user_data)
{
  CbMediaImageWidget *self = user_data;
  GtkAdjustment *adjustment;

  adjustment = gtk_scrolled_window_get_hadjustment (GTK_SCROLLED_WINDOW (self));
  gtk_adjustment_set_value (adjustment, self->drag_start_hvalue - offset_x);

  adjustment = gtk_scrolled_window_get_vadjustment (GTK_SCROLLED_WINDOW (self));
  gtk_adjustment_set_value (adjustment, self->drag_start_vvalue - offset_y);

  gtk_gesture_set_state (GTK_GESTURE (gesture), GTK_EVENT_SEQUENCE_CLAIMED);
}

static void
cb_media_image_widget_class_init (CbMediaImageWidgetClass *klass)
{
  GObjectClass *object_class = G_OBJECT_CLASS (klass);

  object_class->finalize = cb_media_image_widget_finalize;
}

static void
cb_media_image_widget_init (CbMediaImageWidget *self)
{
  self->image = gtk_image_new ();
  gtk_container_add (GTK_CONTAINER (self), self->image);

  self->drag_gesture = gtk_gesture_drag_new (GTK_WIDGET (self));
  gtk_gesture_single_set_button (GTK_GESTURE_SINGLE (self->drag_gesture), GDK_BUTTON_MIDDLE);
  gtk_event_controller_set_propagation_phase (GTK_EVENT_CONTROLLER (self->drag_gesture), GTK_PHASE_CAPTURE);
  g_signal_connect (self->drag_gesture, "drag-begin", G_CALLBACK (drag_begin_cb), self);
  g_signal_connect (self->drag_gesture, "drag-update", G_CALLBACK (drag_update_cb), self);
}

void
hires_progress (CbMedia *media, gpointer user_data) {
  if (!media->loaded_hires) {
    return;
  }
  CbMediaImageWidget *self = CB_MEDIA_IMAGE_WIDGET(user_data);
  gtk_image_set_from_surface (GTK_IMAGE (self->image), media->surface_hires);
  cairo_surface_destroy(self->image_surface);
  self->image_surface = NULL;
}

GtkWidget *
cb_media_image_widget_new (CbMedia *media, GdkRectangle *max_dimensions)
{
  CbMediaImageWidget *self;
  int win_width;
  int win_height;

  g_return_val_if_fail (CB_IS_MEDIA (media), NULL);
  g_return_val_if_fail (!media->invalid, NULL);
  g_return_val_if_fail (media->surface != NULL, NULL);

  self = CB_MEDIA_IMAGE_WIDGET (g_object_new (CB_TYPE_MEDIA_IMAGE_WIDGET, NULL));

  if (media->type == CB_MEDIA_TYPE_GIF) {
    gtk_image_set_from_animation (GTK_IMAGE (self->image), media->animation);
  }
  else if (media->loaded_hires) {
    gtk_image_set_from_surface (GTK_IMAGE (self->image), cb_media_get_highest_res_surface(media));
  }
  else {
    double scale_width = media->width * 1.0 / media->thumb_width;
    double scale_height = media->height * 1.0 / media->thumb_height;
    self->media = media;
    self->hires_progress_id = g_signal_connect(media, "hires-progress", G_CALLBACK(hires_progress), self);
    self->image_surface = cairo_image_surface_create(cairo_image_surface_get_format(media->surface), media->width, media->height);
    cairo_t *ct = cairo_create(self->image_surface);
    cairo_scale(ct, scale_width, scale_height);
    cairo_set_source_surface (ct, media->surface, 0, 0);
    cairo_paint(ct);
    cairo_destroy(ct);
    gtk_image_set_from_surface (GTK_IMAGE (self->image), self->image_surface);
    if (!media->loading) {
      // NULL callback because we should pick it up from the earlier g_signal_connect
      cb_media_downloader_load_hires_async (cb_media_downloader_get_default(), media, NULL, NULL);
    }
  }

  win_width = media->width;
  win_height = media->height;

  if (win_width > max_dimensions->width)
  {
    win_width = max_dimensions->width;
  }

  if (win_height > max_dimensions->height)
  {
    win_height = max_dimensions->height;
  }

  gtk_widget_set_size_request (GTK_WIDGET (self), win_width, win_height);
  gtk_widget_set_tooltip_text (GTK_WIDGET (self), media->alt_text);
  atk_object_set_description(gtk_widget_get_accessible(GTK_WIDGET(self)), media->alt_text == NULL ? "" : media->alt_text);

  return GTK_WIDGET (self);
}