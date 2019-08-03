AM_CPPFLAGS = \
	$(CB_CFLAGS) \
	-include $(CONFIG_HEADER) \
	-DDATADIR=\"$(datadir)\" \
	-DPKGDATADIR=\"$(pkgdatadir)\" \
	-DG_LOG_DOMAIN=\"cawbird\" \
	-I$(top_srcdir)/src/rest/


AM_VALAFLAGS = \
	--thread \
	--enable-deprecated \
	--enable-checking \
	--vapidir $(builddir) \
	--vapidir $(top_srcdir)/vapi \
	--basedir $(srcdir) \
	--directory $(builddir) \
	--gresources $(top_srcdir)/cawbird.gresource.xml \
	-D G_LOG_DOMAIN=\"cawbird\" \
	$(top_srcdir)/vapi/config.vapi \
	$(top_srcdir)/vapi/cawbird-internal.vapi \
	$(top_srcdir)/vapi/rest-0.7.vapi \
	$(top_srcdir)/vapi/libtl.vapi \
	-C \
	$(NULL)

BUILT_SOURCES = \
	cawbird.h \
	cawbird-resources.c

bin_PROGRAMS = cawbird
noinst_LTLIBRARIES = libcawbird.la

libcawbird_la_VALASOURCES = \
	Cawbird.vala \
	MainWindow.vala \
	MainWidget.vala \
	Account.vala \
	HomeTimeline.vala \
	MentionsTimeline.vala \
	SearchPage.vala \
	DMPage.vala \
	IPage.vala \
	DefaultTimeline.vala \
	DMThreadsPage.vala \
	Settings.vala \
	NotificationManager.vala \
	Twitter.vala \
	ProfilePage.vala \
	TweetInfoPage.vala \
	ListStatusesPage.vala \
	ListsPage.vala \
	FavoritesTimeline.vala \
	FilterPage.vala \
	UserEventReceiver.vala \
	DMManager.vala \
	OAuthProxyCallWithBody.vala \
	widgets/TweetListBox.vala \
	widgets/MaxSizeContainer.vala \
	widgets/ScrollWidget.vala \
	widgets/TextButton.vala \
	widgets/DoubleTapButton.vala \
	widgets/ReplyEntry.vala \
	widgets/PixbufButton.vala \
	widgets/BadgeRadioButton.vala \
	widgets/DMPlaceholderBox.vala \
	widgets/AccountCreateWidget.vala \
	widgets/AspectImage.vala \
	widgets/UserListsWidget.vala \
	widgets/ReplyIndicator.vala \
	widgets/MultiMediaWidget.vala \
	widgets/AvatarWidget.vala \
	widgets/AvatarBannerWidget.vala \
	widgets/CropWidget.vala \
	widgets/AddImageButton.vala \
	widgets/CompletionTextView.vala \
	widgets/LazyMenuButton.vala \
	widgets/ImpostorWidget.vala \
	widgets/ChildSizedScroller.vala \
	widgets/FollowButton.vala \
	widgets/MediaButton.vala \
	widgets/ComposeImageManager.vala \
	widgets/FavImageView.vala \
	util/TweetUtils.vala \
	util/Utils.vala \
	util/UserCompletion.vala \
	util/Dirs.vala \
	util/UserUtils.vala \
	list/TweetListEntry.vala \
	list/DMListEntry.vala \
	list/UserListEntry.vala \
	list/DMThreadEntry.vala \
	list/StartConversationEntry.vala \
	list/ListListEntry.vala \
	list/NewListEntry.vala \
	list/FilterListEntry.vala \
	list/UserFilterEntry.vala \
	list/AddListEntry.vala \
	list/SnippetListEntry.vala \
	list/FavImageRow.vala \
	util/Benchmark.vala \
	window/ComposeTweetWindow.vala \
	window/SettingsDialog.vala \
	window/UserListDialog.vala \
	window/ModifyFilterDialog.vala \
	window/AboutDialog.vala \
	window/AccountDialog.vala \
	window/MediaDialog.vala \
	window/ModifySnippetDialog.vala \
	sql/Database.vala \
	sql/InsertStatement.vala \
	sql/UpdateStatement.vala \
	sql/SelectStatement.vala \
	async/Collect.vala \
	model/DMThreadsModel.vala

nodist_libcawbird_la_SOURCES = \
	libcawbird_la_vala.stamp \
	$(libcawbird_la_VALASOURCES:.vala=.c)

cawbird.h cawbird.vapi: libcawbird_la_vala.stamp
$(libcawbird_la_VALASOURCES:.vala=.c): libcawbird_la_vala.stamp


libcawbird_la_SOURCES = \
	CbMedia.c \
	CbMedia.h \
	CbMediaDownloader.c \
	CbMediaDownloader.h \
	CbTypes.c \
	CbTypes.h \
	CbTextTransform.c \
	CbTextTransform.h \
	CbTweet.c \
	CbTweet.h \
	CbFilter.c \
	CbFilter.h \
	CbAvatarCache.c \
	CbAvatarCache.h \
	CbUserCounter.c \
	CbUserCounter.h \
	CbMediaImageWidget.h \
	CbMediaImageWidget.c \
	CbTweetModel.h \
	CbTweetModel.c \
	CbTwitterItem.h \
	CbTwitterItem.c \
	CbDeltaUpdater.h \
	CbDeltaUpdater.c \
	CbUtils.h \
	CbUtils.c \
	CbBundle.h \
	CbBundle.c \
	CbBundleHistory.h \
	CbBundleHistory.c \
	CbSnippetManager.h \
	CbSnippetManager.c \
	CbMediaVideoWidget.h \
	CbMediaVideoWidget.c \
	CbSurfaceProgress.h \
	CbSurfaceProgress.c \
	CbMessageReceiver.h \
	CbMessageReceiver.c \
	CbUserStream.h \
	CbUserStream.c \
	CbComposeJob.h \
	CbComposeJob.c \
	CbGtkCompat.h \
	CbUserCompletionModel.c \
	CbUserCompletionModel.h \
	CbEmojiChooser.c \
	CbEmojiChooser.h \
	rest/rest/rest-param.c \
	rest/rest/rest-params.c \
	rest/rest/rest-proxy.c \
	rest/rest/rest-proxy-call.c \
	rest/rest/rest-proxy-call-private.h \
	rest/rest/rest-main.c \
	rest/rest/rest-private.h \
	rest/rest/oauth-proxy.c \
	rest/rest/oauth-proxy-call.c \
	rest/rest/oauth-proxy-private.h \
	rest/rest/sha1.c \
	rest/rest/sha1.h \
	rest/rest/rest-param.h \
	rest/rest/rest-params.h \
	rest/rest/rest-proxy.h \
	rest/rest/rest-proxy-call.h \
	rest/rest/oauth-proxy.h \
	rest/rest/oauth-proxy-call.h \
	libtl/libtweetlength.h \
	libtl/libtweetlength.c \
	libtl/data.h




libcawbird_la_vala.stamp: $(libcawbird_la_VALASOURCES) Makefile
	@$(VALAC) \
		$(AM_VALAFLAGS) $(CB_VALA_FLAGS) \
		-H cawbird.h \
		--library cawbird \
		--vapi cawbird.vapi \
		$(filter %.vala %.c,$^)
	touch $@

libcawbird_la_LIBADD = $(CB_LIBS)

cawbird_VALASOURCES = \
	main.vala


nodist_cawbird_SOURCES = \
	cawbird_vala.stamp \
	cawbird-resources.c \
	$(cawbird_VALASOURCES:.vala=.c)

cawbird_LDADD = \
	$(CB_LIBS) \
	$(builddir)/libcawbird.la

cawbird_VALAFLAGS = \
	$(CB_VALA_FLAGS) \
	cawbird.vapi

$(cawbird_VALASOURCES:.vala=.c): cawbird_vala.stamp

cawbird_vala.stamp: $(builddir)/libcawbird.la $(builddir)/cawbird.vapi $(cawbird_VALASOURCES) Makefile
	@$(VALAC) \
		$(AM_VALAFLAGS) $(CB_VALA_FLAGS) \
		--pkg cawbird \
		$(filter %.vala %.c,$^)
	touch $@

resource_deps = $(shell $(GLIB_COMPILE_RESOURCES) --generate-dependencies --sourcedir=$(top_srcdir) $(top_srcdir)/cawbird.gresource.xml)
cawbird-resources.c: $(top_srcdir)/cawbird.gresource.xml $(resource_deps) Makefile
	XMLLINT=$(XMLLINT) $(GLIB_COMPILE_RESOURCES) --target $@ --generate --sourcedir=$(top_srcdir) --c-name cawbird $<

CLEANFILES = \
	libcawbird_la_vala.stamp \
	cawbird_vala.stamp \
	$(libcawbird_la_VALASOURCES:.vala=.c) \
	$(nodist_cawbird_SOURCES) \
	cawbird.vapi \
	cawbird.h

EXTRA_DIST = \
	$(libcawbird_la_VALASOURCES) \
	$(cawbird_VALASOURCES) \
	$(cawbird_SOURCES) \
	$(resource_deps)
