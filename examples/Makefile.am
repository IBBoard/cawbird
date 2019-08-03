
AM_CPPFLAGS = \
	$(CB_CFLAGS) \
	-I$(top_builddir)/src \
	-I$(top_srcdir)/src \
	-include $(CONFIG_HEADER) \
	-DDATADIR=\"$(datadir)\" \
	-DPKGDATADIR=\"$(pkgdatadir)\" \
	-D DEBUG

AM_VALAFLAGS = \
	$(CB_VALA_FLAGS) \
	--enable-checking \
	--enable-experimental \
	--vapidir $(top_builddir)/src \
	--vapidir $(top_srcdir)/vapi \
	--pkg cawbird-internal \
	--pkg cawbird \
	--enable-deprecated \
	--gresources $(top_srcdir)/cawbird.gresource.xml \
	-C \
	-g

resource_deps = $(shell $(GLIB_COMPILE_RESOURCES) --generate-dependencies --sourcedir=$(top_srcdir) $(top_srcdir)/cawbird.gresource.xml)
cawbird-resources.c: $(top_srcdir)/cawbird.gresource.xml $(resource_deps) Makefile
	XMLLINT=$(XMLLINT) $(GLIB_COMPILE_RESOURCES) --target $@ --generate --sourcedir=$(top_srcdir) --c-name cawbird $<


noinst_bin_PROGRAMS = \
	tweetstates \
	accountdialog

noinst_bindir = $(abs_top_builddir)

tweetstates_SOURCES = tweetstates.vala cawbird-resources.c
tweetstates_LDADD = $(CB_LIBS) $(top_builddir)/src/libcawbird.la

accountdialog_SOURCES = accountdialog.vala cawbird-resources.c
accountdialog_LDADD = $(CB_LIBS) $(top_builddir)/src/libcawbird.la

CLEANFILES = cawbird-resources.c
