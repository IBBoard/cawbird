ACLOCAL_AMFLAGS = -I m4 ${ACLOCAL_FLAGS}

SUBDIRS = src data po tests

EXTRA_DIST = \
	vapi/config.vapi \
	vapi/rest-0.7.vapi \
	vapi/libtl.vapi \
	vapi/cawbird-internal.vapi \
	cawbird.gresource.xml


update-translations: po/cawbird.pot
	@tx pull --all --force --skip --minimum-perc=1
	@tx push --source
