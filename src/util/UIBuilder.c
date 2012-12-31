/* UIBuilder.c generated by valac 0.18.1, the Vala compiler
 * generated from UIBuilder.vala, do not modify */


#include <glib.h>
#include <glib-object.h>
#include <gtk/gtk.h>
#include <stdlib.h>
#include <string.h>
#include <gobject/gvaluecollector.h>


#define TYPE_UI_BUILDER (ui_builder_get_type ())
#define UI_BUILDER(obj) (G_TYPE_CHECK_INSTANCE_CAST ((obj), TYPE_UI_BUILDER, UIBuilder))
#define UI_BUILDER_CLASS(klass) (G_TYPE_CHECK_CLASS_CAST ((klass), TYPE_UI_BUILDER, UIBuilderClass))
#define IS_UI_BUILDER(obj) (G_TYPE_CHECK_INSTANCE_TYPE ((obj), TYPE_UI_BUILDER))
#define IS_UI_BUILDER_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass), TYPE_UI_BUILDER))
#define UI_BUILDER_GET_CLASS(obj) (G_TYPE_INSTANCE_GET_CLASS ((obj), TYPE_UI_BUILDER, UIBuilderClass))

typedef struct _UIBuilder UIBuilder;
typedef struct _UIBuilderClass UIBuilderClass;
typedef struct _UIBuilderPrivate UIBuilderPrivate;
#define _g_object_unref0(var) ((var == NULL) ? NULL : (var = (g_object_unref (var), NULL)))
#define _g_error_free0(var) ((var == NULL) ? NULL : (var = (g_error_free (var), NULL)))
typedef struct _ParamSpecUIBuilder ParamSpecUIBuilder;

struct _UIBuilder {
	GTypeInstance parent_instance;
	volatile int ref_count;
	UIBuilderPrivate * priv;
};

struct _UIBuilderClass {
	GTypeClass parent_class;
	void (*finalize) (UIBuilder *self);
};

struct _UIBuilderPrivate {
	GtkBuilder* builder;
};

struct _ParamSpecUIBuilder {
	GParamSpec parent_instance;
};


static gpointer ui_builder_parent_class = NULL;

gpointer ui_builder_ref (gpointer instance);
void ui_builder_unref (gpointer instance);
GParamSpec* param_spec_ui_builder (const gchar* name, const gchar* nick, const gchar* blurb, GType object_type, GParamFlags flags);
void value_set_ui_builder (GValue* value, gpointer v_object);
void value_take_ui_builder (GValue* value, gpointer v_object);
gpointer value_get_ui_builder (const GValue* value);
GType ui_builder_get_type (void) G_GNUC_CONST;
#define UI_BUILDER_GET_PRIVATE(o) (G_TYPE_INSTANCE_GET_PRIVATE ((o), TYPE_UI_BUILDER, UIBuilderPrivate))
enum  {
	UI_BUILDER_DUMMY_PROPERTY
};
UIBuilder* ui_builder_new (const gchar* path, const gchar* object_name);
UIBuilder* ui_builder_construct (GType object_type, const gchar* path, const gchar* object_name);
GtkButton* ui_builder_get_button (UIBuilder* self, const gchar* name);
GtkWindow* ui_builder_get_window (UIBuilder* self, const gchar* name);
GtkLabel* ui_builder_get_label (UIBuilder* self, const gchar* name);
GtkImage* ui_builder_get_image (UIBuilder* self, const gchar* name);
GtkBox* ui_builder_get_box (UIBuilder* self, const gchar* name);
GtkToggleButton* ui_builder_get_toggle (UIBuilder* self, const gchar* name);
static void ui_builder_finalize (UIBuilder* obj);
static void _vala_array_destroy (gpointer array, gint array_length, GDestroyNotify destroy_func);
static void _vala_array_free (gpointer array, gint array_length, GDestroyNotify destroy_func);


UIBuilder* ui_builder_construct (GType object_type, const gchar* path, const gchar* object_name) {
	UIBuilder* self = NULL;
	GError * _inner_error_ = NULL;
#line 10 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	g_return_val_if_fail (path != NULL, NULL);
#line 10 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	g_return_val_if_fail (object_name != NULL, NULL);
#line 10 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	self = (UIBuilder*) g_type_create_instance (object_type);
#line 83 "UIBuilder.c"
	{
		const gchar* _tmp0_;
#line 12 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
		_tmp0_ = object_name;
#line 12 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
		if (g_strcmp0 (_tmp0_, "") != 0) {
#line 90 "UIBuilder.c"
			GtkBuilder* _tmp1_;
			const gchar* _tmp2_;
			const gchar* _tmp3_;
			gchar* _tmp4_;
			gchar** _tmp5_ = NULL;
			gchar** _tmp6_;
			gint _tmp6__length1;
#line 13 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
			_tmp1_ = self->priv->builder;
#line 13 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
			_tmp2_ = path;
#line 13 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
			_tmp3_ = object_name;
#line 13 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
			_tmp4_ = g_strdup (_tmp3_);
#line 13 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
			_tmp5_ = g_new0 (gchar*, 1 + 1);
#line 13 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
			_tmp5_[0] = _tmp4_;
#line 13 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
			_tmp6_ = _tmp5_;
#line 13 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
			_tmp6__length1 = 1;
#line 13 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
			gtk_builder_add_objects_from_file (_tmp1_, _tmp2_, _tmp6_, &_inner_error_);
#line 13 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
			_tmp6_ = (_vala_array_free (_tmp6_, _tmp6__length1, (GDestroyNotify) g_free), NULL);
#line 13 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
			if (_inner_error_ != NULL) {
#line 120 "UIBuilder.c"
				goto __catch53_g_error;
			}
		} else {
			GtkBuilder* _tmp7_;
			const gchar* _tmp8_;
#line 15 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
			_tmp7_ = self->priv->builder;
#line 15 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
			_tmp8_ = path;
#line 15 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
			gtk_builder_add_from_file (_tmp7_, _tmp8_, &_inner_error_);
#line 15 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
			if (_inner_error_ != NULL) {
#line 134 "UIBuilder.c"
				goto __catch53_g_error;
			}
		}
	}
	goto __finally53;
	__catch53_g_error:
	{
		GError* e = NULL;
		const gchar* _tmp9_;
		GError* _tmp10_;
		const gchar* _tmp11_;
#line 11 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
		e = _inner_error_;
#line 11 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
		_inner_error_ = NULL;
#line 17 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
		_tmp9_ = path;
#line 17 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
		_tmp10_ = e;
#line 17 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
		_tmp11_ = _tmp10_->message;
#line 17 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
		g_critical ("UIBuilder.vala:17: Loading %s: %s", _tmp9_, _tmp11_);
#line 11 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
		_g_error_free0 (e);
#line 160 "UIBuilder.c"
	}
	__finally53:
#line 11 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	if (_inner_error_ != NULL) {
#line 11 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
		g_critical ("file %s: line %d: uncaught error: %s (%s, %d)", __FILE__, __LINE__, _inner_error_->message, g_quark_to_string (_inner_error_->domain), _inner_error_->code);
#line 11 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
		g_clear_error (&_inner_error_);
#line 11 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
		return NULL;
#line 171 "UIBuilder.c"
	}
#line 10 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	return self;
#line 175 "UIBuilder.c"
}


UIBuilder* ui_builder_new (const gchar* path, const gchar* object_name) {
#line 10 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	return ui_builder_construct (TYPE_UI_BUILDER, path, object_name);
#line 182 "UIBuilder.c"
}


static gpointer _g_object_ref0 (gpointer self) {
#line 22 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	return self ? g_object_ref (self) : NULL;
#line 189 "UIBuilder.c"
}


GtkButton* ui_builder_get_button (UIBuilder* self, const gchar* name) {
	GtkButton* result = NULL;
	GtkBuilder* _tmp0_;
	const gchar* _tmp1_;
	GObject* _tmp2_ = NULL;
	GtkButton* _tmp3_;
#line 21 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	g_return_val_if_fail (IS_UI_BUILDER (self), NULL);
#line 21 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	g_return_val_if_fail (name != NULL, NULL);
#line 22 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	_tmp0_ = self->priv->builder;
#line 22 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	_tmp1_ = name;
#line 22 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	_tmp2_ = gtk_builder_get_object (_tmp0_, _tmp1_);
#line 22 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	_tmp3_ = _g_object_ref0 (G_TYPE_CHECK_INSTANCE_TYPE (_tmp2_, GTK_TYPE_BUTTON) ? ((GtkButton*) _tmp2_) : NULL);
#line 22 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	result = _tmp3_;
#line 22 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	return result;
#line 215 "UIBuilder.c"
}


GtkWindow* ui_builder_get_window (UIBuilder* self, const gchar* name) {
	GtkWindow* result = NULL;
	GtkBuilder* _tmp0_;
	const gchar* _tmp1_;
	GObject* _tmp2_ = NULL;
	GtkWindow* _tmp3_;
#line 25 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	g_return_val_if_fail (IS_UI_BUILDER (self), NULL);
#line 25 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	g_return_val_if_fail (name != NULL, NULL);
#line 26 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	_tmp0_ = self->priv->builder;
#line 26 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	_tmp1_ = name;
#line 26 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	_tmp2_ = gtk_builder_get_object (_tmp0_, _tmp1_);
#line 26 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	_tmp3_ = _g_object_ref0 (G_TYPE_CHECK_INSTANCE_TYPE (_tmp2_, GTK_TYPE_WINDOW) ? ((GtkWindow*) _tmp2_) : NULL);
#line 26 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	result = _tmp3_;
#line 26 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	return result;
#line 241 "UIBuilder.c"
}


GtkLabel* ui_builder_get_label (UIBuilder* self, const gchar* name) {
	GtkLabel* result = NULL;
	GtkBuilder* _tmp0_;
	const gchar* _tmp1_;
	GObject* _tmp2_ = NULL;
	GtkLabel* _tmp3_;
#line 29 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	g_return_val_if_fail (IS_UI_BUILDER (self), NULL);
#line 29 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	g_return_val_if_fail (name != NULL, NULL);
#line 30 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	_tmp0_ = self->priv->builder;
#line 30 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	_tmp1_ = name;
#line 30 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	_tmp2_ = gtk_builder_get_object (_tmp0_, _tmp1_);
#line 30 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	_tmp3_ = _g_object_ref0 (G_TYPE_CHECK_INSTANCE_TYPE (_tmp2_, GTK_TYPE_LABEL) ? ((GtkLabel*) _tmp2_) : NULL);
#line 30 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	result = _tmp3_;
#line 30 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	return result;
#line 267 "UIBuilder.c"
}


GtkImage* ui_builder_get_image (UIBuilder* self, const gchar* name) {
	GtkImage* result = NULL;
	GtkBuilder* _tmp0_;
	const gchar* _tmp1_;
	GObject* _tmp2_ = NULL;
	GtkImage* _tmp3_;
#line 33 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	g_return_val_if_fail (IS_UI_BUILDER (self), NULL);
#line 33 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	g_return_val_if_fail (name != NULL, NULL);
#line 34 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	_tmp0_ = self->priv->builder;
#line 34 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	_tmp1_ = name;
#line 34 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	_tmp2_ = gtk_builder_get_object (_tmp0_, _tmp1_);
#line 34 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	_tmp3_ = _g_object_ref0 (G_TYPE_CHECK_INSTANCE_TYPE (_tmp2_, GTK_TYPE_IMAGE) ? ((GtkImage*) _tmp2_) : NULL);
#line 34 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	result = _tmp3_;
#line 34 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	return result;
#line 293 "UIBuilder.c"
}


GtkBox* ui_builder_get_box (UIBuilder* self, const gchar* name) {
	GtkBox* result = NULL;
	GtkBuilder* _tmp0_;
	const gchar* _tmp1_;
	GObject* _tmp2_ = NULL;
	GtkBox* _tmp3_;
#line 37 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	g_return_val_if_fail (IS_UI_BUILDER (self), NULL);
#line 37 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	g_return_val_if_fail (name != NULL, NULL);
#line 38 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	_tmp0_ = self->priv->builder;
#line 38 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	_tmp1_ = name;
#line 38 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	_tmp2_ = gtk_builder_get_object (_tmp0_, _tmp1_);
#line 38 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	_tmp3_ = _g_object_ref0 (G_TYPE_CHECK_INSTANCE_TYPE (_tmp2_, GTK_TYPE_BOX) ? ((GtkBox*) _tmp2_) : NULL);
#line 38 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	result = _tmp3_;
#line 38 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	return result;
#line 319 "UIBuilder.c"
}


GtkToggleButton* ui_builder_get_toggle (UIBuilder* self, const gchar* name) {
	GtkToggleButton* result = NULL;
	GtkBuilder* _tmp0_;
	const gchar* _tmp1_;
	GObject* _tmp2_ = NULL;
	GtkToggleButton* _tmp3_;
#line 41 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	g_return_val_if_fail (IS_UI_BUILDER (self), NULL);
#line 41 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	g_return_val_if_fail (name != NULL, NULL);
#line 42 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	_tmp0_ = self->priv->builder;
#line 42 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	_tmp1_ = name;
#line 42 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	_tmp2_ = gtk_builder_get_object (_tmp0_, _tmp1_);
#line 42 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	_tmp3_ = _g_object_ref0 (G_TYPE_CHECK_INSTANCE_TYPE (_tmp2_, GTK_TYPE_TOGGLE_BUTTON) ? ((GtkToggleButton*) _tmp2_) : NULL);
#line 42 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	result = _tmp3_;
#line 42 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	return result;
#line 345 "UIBuilder.c"
}


static void value_ui_builder_init (GValue* value) {
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	value->data[0].v_pointer = NULL;
#line 352 "UIBuilder.c"
}


static void value_ui_builder_free_value (GValue* value) {
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	if (value->data[0].v_pointer) {
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
		ui_builder_unref (value->data[0].v_pointer);
#line 361 "UIBuilder.c"
	}
}


static void value_ui_builder_copy_value (const GValue* src_value, GValue* dest_value) {
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	if (src_value->data[0].v_pointer) {
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
		dest_value->data[0].v_pointer = ui_builder_ref (src_value->data[0].v_pointer);
#line 371 "UIBuilder.c"
	} else {
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
		dest_value->data[0].v_pointer = NULL;
#line 375 "UIBuilder.c"
	}
}


static gpointer value_ui_builder_peek_pointer (const GValue* value) {
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	return value->data[0].v_pointer;
#line 383 "UIBuilder.c"
}


static gchar* value_ui_builder_collect_value (GValue* value, guint n_collect_values, GTypeCValue* collect_values, guint collect_flags) {
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	if (collect_values[0].v_pointer) {
#line 390 "UIBuilder.c"
		UIBuilder* object;
		object = collect_values[0].v_pointer;
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
		if (object->parent_instance.g_class == NULL) {
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
			return g_strconcat ("invalid unclassed object pointer for value type `", G_VALUE_TYPE_NAME (value), "'", NULL);
#line 397 "UIBuilder.c"
		} else if (!g_value_type_compatible (G_TYPE_FROM_INSTANCE (object), G_VALUE_TYPE (value))) {
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
			return g_strconcat ("invalid object type `", g_type_name (G_TYPE_FROM_INSTANCE (object)), "' for value type `", G_VALUE_TYPE_NAME (value), "'", NULL);
#line 401 "UIBuilder.c"
		}
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
		value->data[0].v_pointer = ui_builder_ref (object);
#line 405 "UIBuilder.c"
	} else {
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
		value->data[0].v_pointer = NULL;
#line 409 "UIBuilder.c"
	}
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	return NULL;
#line 413 "UIBuilder.c"
}


static gchar* value_ui_builder_lcopy_value (const GValue* value, guint n_collect_values, GTypeCValue* collect_values, guint collect_flags) {
	UIBuilder** object_p;
	object_p = collect_values[0].v_pointer;
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	if (!object_p) {
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
		return g_strdup_printf ("value location for `%s' passed as NULL", G_VALUE_TYPE_NAME (value));
#line 424 "UIBuilder.c"
	}
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	if (!value->data[0].v_pointer) {
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
		*object_p = NULL;
#line 430 "UIBuilder.c"
	} else if (collect_flags & G_VALUE_NOCOPY_CONTENTS) {
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
		*object_p = value->data[0].v_pointer;
#line 434 "UIBuilder.c"
	} else {
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
		*object_p = ui_builder_ref (value->data[0].v_pointer);
#line 438 "UIBuilder.c"
	}
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	return NULL;
#line 442 "UIBuilder.c"
}


GParamSpec* param_spec_ui_builder (const gchar* name, const gchar* nick, const gchar* blurb, GType object_type, GParamFlags flags) {
	ParamSpecUIBuilder* spec;
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	g_return_val_if_fail (g_type_is_a (object_type, TYPE_UI_BUILDER), NULL);
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	spec = g_param_spec_internal (G_TYPE_PARAM_OBJECT, name, nick, blurb, flags);
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	G_PARAM_SPEC (spec)->value_type = object_type;
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	return G_PARAM_SPEC (spec);
#line 456 "UIBuilder.c"
}


gpointer value_get_ui_builder (const GValue* value) {
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	g_return_val_if_fail (G_TYPE_CHECK_VALUE_TYPE (value, TYPE_UI_BUILDER), NULL);
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	return value->data[0].v_pointer;
#line 465 "UIBuilder.c"
}


void value_set_ui_builder (GValue* value, gpointer v_object) {
	UIBuilder* old;
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	g_return_if_fail (G_TYPE_CHECK_VALUE_TYPE (value, TYPE_UI_BUILDER));
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	old = value->data[0].v_pointer;
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	if (v_object) {
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
		g_return_if_fail (G_TYPE_CHECK_INSTANCE_TYPE (v_object, TYPE_UI_BUILDER));
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
		g_return_if_fail (g_value_type_compatible (G_TYPE_FROM_INSTANCE (v_object), G_VALUE_TYPE (value)));
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
		value->data[0].v_pointer = v_object;
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
		ui_builder_ref (value->data[0].v_pointer);
#line 485 "UIBuilder.c"
	} else {
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
		value->data[0].v_pointer = NULL;
#line 489 "UIBuilder.c"
	}
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	if (old) {
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
		ui_builder_unref (old);
#line 495 "UIBuilder.c"
	}
}


void value_take_ui_builder (GValue* value, gpointer v_object) {
	UIBuilder* old;
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	g_return_if_fail (G_TYPE_CHECK_VALUE_TYPE (value, TYPE_UI_BUILDER));
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	old = value->data[0].v_pointer;
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	if (v_object) {
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
		g_return_if_fail (G_TYPE_CHECK_INSTANCE_TYPE (v_object, TYPE_UI_BUILDER));
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
		g_return_if_fail (g_value_type_compatible (G_TYPE_FROM_INSTANCE (v_object), G_VALUE_TYPE (value)));
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
		value->data[0].v_pointer = v_object;
#line 514 "UIBuilder.c"
	} else {
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
		value->data[0].v_pointer = NULL;
#line 518 "UIBuilder.c"
	}
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	if (old) {
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
		ui_builder_unref (old);
#line 524 "UIBuilder.c"
	}
}


static void ui_builder_class_init (UIBuilderClass * klass) {
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	ui_builder_parent_class = g_type_class_peek_parent (klass);
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	UI_BUILDER_CLASS (klass)->finalize = ui_builder_finalize;
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	g_type_class_add_private (klass, sizeof (UIBuilderPrivate));
#line 536 "UIBuilder.c"
}


static void ui_builder_instance_init (UIBuilder * self) {
	GtkBuilder* _tmp0_;
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	self->priv = UI_BUILDER_GET_PRIVATE (self);
#line 7 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	_tmp0_ = gtk_builder_new ();
#line 7 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	self->priv->builder = _tmp0_;
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	self->ref_count = 1;
#line 550 "UIBuilder.c"
}


static void ui_builder_finalize (UIBuilder* obj) {
	UIBuilder * self;
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	self = G_TYPE_CHECK_INSTANCE_CAST (obj, TYPE_UI_BUILDER, UIBuilder);
#line 7 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	_g_object_unref0 (self->priv->builder);
#line 560 "UIBuilder.c"
}


GType ui_builder_get_type (void) {
	static volatile gsize ui_builder_type_id__volatile = 0;
	if (g_once_init_enter (&ui_builder_type_id__volatile)) {
		static const GTypeValueTable g_define_type_value_table = { value_ui_builder_init, value_ui_builder_free_value, value_ui_builder_copy_value, value_ui_builder_peek_pointer, "p", value_ui_builder_collect_value, "p", value_ui_builder_lcopy_value };
		static const GTypeInfo g_define_type_info = { sizeof (UIBuilderClass), (GBaseInitFunc) NULL, (GBaseFinalizeFunc) NULL, (GClassInitFunc) ui_builder_class_init, (GClassFinalizeFunc) NULL, NULL, sizeof (UIBuilder), 0, (GInstanceInitFunc) ui_builder_instance_init, &g_define_type_value_table };
		static const GTypeFundamentalInfo g_define_type_fundamental_info = { (G_TYPE_FLAG_CLASSED | G_TYPE_FLAG_INSTANTIATABLE | G_TYPE_FLAG_DERIVABLE | G_TYPE_FLAG_DEEP_DERIVABLE) };
		GType ui_builder_type_id;
		ui_builder_type_id = g_type_register_fundamental (g_type_fundamental_next (), "UIBuilder", &g_define_type_info, &g_define_type_fundamental_info, 0);
		g_once_init_leave (&ui_builder_type_id__volatile, ui_builder_type_id);
	}
	return ui_builder_type_id__volatile;
}


gpointer ui_builder_ref (gpointer instance) {
	UIBuilder* self;
	self = instance;
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	g_atomic_int_inc (&self->ref_count);
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	return instance;
#line 585 "UIBuilder.c"
}


void ui_builder_unref (gpointer instance) {
	UIBuilder* self;
	self = instance;
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
	if (g_atomic_int_dec_and_test (&self->ref_count)) {
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
		UI_BUILDER_GET_CLASS (self)->finalize (self);
#line 6 "/home/baedert/Code/Vala/Corebird/src/util/UIBuilder.vala"
		g_type_free_instance ((GTypeInstance *) self);
#line 598 "UIBuilder.c"
	}
}


static void _vala_array_destroy (gpointer array, gint array_length, GDestroyNotify destroy_func) {
	if ((array != NULL) && (destroy_func != NULL)) {
		int i;
		for (i = 0; i < array_length; i = i + 1) {
			if (((gpointer*) array)[i] != NULL) {
				destroy_func (((gpointer*) array)[i]);
			}
		}
	}
}


static void _vala_array_free (gpointer array, gint array_length, GDestroyNotify destroy_func) {
	_vala_array_destroy (array, array_length, destroy_func);
	g_free (array);
}



