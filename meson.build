project('Cawbird', ['vala', 'c'],
        version: '1.5',
        default_options: [
          'buildtype=debug'
        ])

prefix = get_option('prefix')
localedir = join_paths(prefix, get_option('localedir'))

gnome = import('gnome')
srcdir = include_directories('src')

# This is apparently bad practice, but it solves our "undefined reference to symbol 'floor@@GLIBC_2.2.5'" build problem
cc = meson.get_compiler('c')
libm = cc.find_library('m', required : false)
oauth = cc.find_library('oauth')

min_glib_version = '2.44'

glib_dep = dependency('glib-2.0', version: '>=' + min_glib_version)
gtk_dep  = dependency('gtk+-3.0', version: '>=3.22')
rest_dep = dependency('rest-0.7')
json_dep = dependency('json-glib-1.0')
sql_dep  = dependency('sqlite3')
soup_dep = dependency('libsoup-2.4')

cb_deps = [
  glib_dep,
  gtk_dep,
  rest_dep,
  json_dep,
  sql_dep,
  soup_dep,
  oauth,
  libm
]

# Options
enable_debug = get_option('buildtype') == 'debug' or get_option('buildtype') == 'debugoptimized'
enable_video = get_option('video')
enable_spellcheck = get_option('spellcheck')
enable_examples = get_option('examples')
enable_x11 = get_option('x11')
use_windows_behaviour = get_option('mswindows')

# Project arguments

add_project_arguments('-DGETTEXT_PACKAGE="cawbird"', language: 'c')
add_project_arguments('-DDATADIR="' + get_option('datadir') + '"', language: 'c')
add_project_arguments('-DG_LOG_DOMAIN="cawbird"', language: 'c')
add_project_arguments('--enable-deprecated', language: 'vala')

if (enable_debug)
  add_project_arguments('-DDEBUG', language: 'c')
  add_project_arguments('-D', 'DEBUG', language: 'vala')
endif

if (enable_video)
  add_project_arguments('-DVIDEO', language: 'c')
  add_project_arguments('-D', 'VIDEO', language: 'vala')
  cb_deps += [dependency('gstreamer-video-1.0', version: '>= 1.6')]
endif

if (enable_spellcheck)
  add_project_arguments('-DSPELLCHECK', language: 'c')
  add_project_arguments('-D', 'SPELLCHECK', language: 'vala')
  cb_deps += [dependency('gspell-1', version: '>=1.0')]
endif

if (enable_x11)
  add_project_arguments('-DX11', language: 'c')
  add_project_arguments('-D', 'X11', language: 'vala')
  cb_deps += [dependency('x11')]
endif

if (enable_debug)
  warning('Debugging is enabled. Debug level logs will contain the full, plaintext content of ALL tweets and DMs.')
endif

if (use_windows_behaviour)
  add_project_arguments('-D', 'MSWINDOWS', language: 'vala')
endif


cawbird_lib_sources = files([
  'src/Account.vala',
  'src/Cawbird.vala',
  'src/ComposedTweet.vala',
  'src/DMManager.vala',
  'src/DMPage.vala',
  'src/DMThreadsPage.vala',
  'src/DefaultTimeline.vala',
  'src/FavoritesTimeline.vala',
  'src/FilterPage.vala',
  'src/HomeTimeline.vala',
  'src/IPage.vala',
  'src/ListStatusesPage.vala',
  'src/ListsPage.vala',
  'src/MainWidget.vala',
  'src/MainWindow.vala',
  'src/MediaUpload.vala',
  'src/MentionsTimeline.vala',
  'src/NotificationManager.vala',
  'src/OAuthProxyCallWithBody.vala',
  'src/OAuthProxyCallWithQueryString.vala',
  'src/ProfilePage.vala',
  'src/SearchPage.vala',
  'src/Settings.vala',
  'src/TweetInfoPage.vala',
  'src/Twitter.vala',
  'src/UserEventReceiver.vala',
  'src/async/Collect.vala',
  'src/async/CollectById.vala',
  'src/list/AddListEntry.vala',
  'src/list/DMListEntry.vala',
  'src/list/DMThreadEntry.vala',
  'src/list/FilterListEntry.vala',
  'src/list/ListListEntry.vala',
  'src/list/NewListEntry.vala',
  'src/list/SnippetListEntry.vala',
  'src/list/StartConversationEntry.vala',
  'src/list/TweetListEntry.vala',
  'src/list/UserFilterEntry.vala',
  'src/list/UserListEntry.vala',
  'src/list/FavImageRow.vala',
  'src/model/DMThreadsModel.vala',
  'src/sql/Database.vala',
  'src/sql/BaseStatement.vala',
  'src/sql/DeleteStatement.vala',
  'src/sql/InsertStatement.vala',
  'src/sql/SelectStatement.vala',
  'src/sql/UpdateStatement.vala',
  'src/util/Benchmark.vala',
  'src/util/Dirs.vala',
  'src/util/ListUtils.vala',
  'src/util/TweetUtils.vala',
  'src/util/UserCompletion.vala',
  'src/util/UserUtils.vala',
  'src/util/Utils.vala',
  'src/widgets/AccountCreateWidget.vala',
  'src/widgets/AddImageButton.vala',
  'src/widgets/AspectImage.vala',
  'src/widgets/AvatarBannerWidget.vala',
  'src/widgets/AvatarWidget.vala',
  'src/widgets/BadgeRadioButton.vala',
  'src/widgets/CompletionTextView.vala',
  'src/widgets/ComposeImageManager.vala',
  'src/widgets/CropWidget.vala',
  'src/widgets/DMPlaceholderBox.vala',
  'src/widgets/DoubleTapButton.vala',
  'src/widgets/FollowButton.vala',
  'src/widgets/ImpostorWidget.vala',
  'src/widgets/LazyMenuButton.vala',
  'src/widgets/ListBox.vala',
  'src/widgets/MediaButton.vala',
  'src/widgets/MediaButtonSurface.vala',
  'src/widgets/MultiMediaWidget.vala',
  'src/widgets/PixbufButton.vala',
  'src/widgets/ResizableImage.vala',
  'src/widgets/ReplyEntry.vala',
  'src/widgets/ScrollWidget.vala',
  'src/widgets/TextButton.vala',
  'src/widgets/TweetListBox.vala',
  'src/widgets/UserListsWidget.vala',
  'src/widgets/FavImageView.vala',
  'src/window/AboutDialog.vala',
  'src/window/AccountDialog.vala',
  'src/window/ComposeTweetWindow.vala',
  'src/window/ImageDescriptionWindow.vala',
  'src/window/MediaDialog.vala',
  'src/window/ModifyFilterDialog.vala',
  'src/window/ModifySnippetDialog.vala',
  'src/window/SettingsDialog.vala',
  'src/window/UserListDialog.vala',

  # C Sources
  'src/CbTweet.c',
  'src/CbTextTransform.c',
  'src/CbMedia.c',
  'src/CbMediaDownloader.c',
  'src/CbTypes.c',
  'src/CbUserCounter.c',
  'src/CbFilter.c',
  'src/CbAvatarCache.c',
  'src/CbMediaImageWidget.c',
  'src/CbTweetModel.c',
  'src/CbTwitterItem.c',
  'src/CbDeltaUpdater.c',
  'src/CbUtils.c',
  'src/CbBundle.c',
  'src/CbBundleHistory.c',
  'src/CbSnippetManager.c',
  'src/CbSurfaceProgress.c',
  'src/CbMediaVideoWidget.c',
  'src/CbUserStream.c',
  'src/CbMessageReceiver.c',
  'src/CbUserCompletionModel.c',
  'src/CbEmojiChooser.c',

  # libtweetlength sources (TODO: Should be a meson subproject)
  # https://github.com/baedert/libtweetlength
  'src/libtl/libtweetlength.c',

  # Vapi files
  'vapi/cawbird-internal.vapi',
  'vapi/libtl.vapi'
])

# glib resources
cb_resources = gnome.compile_resources(
  'cawbird_resources',
  'cawbird.gresource.xml',
)

# config.h
consumer_key = get_option('consumer_key_base64')
consumer_secret = get_option('consumer_secret_base64')
assert(consumer_key != '' and consumer_secret != '', 'Must specify `consumer_key_base64` and `consumer_secret_base64`')
cdata = configuration_data()
if get_option('localtextdomain')
  cdata.set('LOCALEDIR', 'NULL')
else
  cdata.set_quoted ('LOCALEDIR', localedir)
endif
cdata.set_quoted ('GETTEXT_PACKAGE', 'cawbird')
cdata.set_quoted ('CONSUMER_KEY', consumer_key)
cdata.set_quoted ('CONSUMER_SECRET', consumer_secret)
configure_file(
  #input : 'config.h.meson',
  output: 'config.h',
  configuration: cdata
)

# library (for unit tests)
cb_lib = static_library(
  'cawbird',
  cawbird_lib_sources,
  dependencies: cb_deps,
  include_directories: [srcdir],
  vala_args: [
    meson.source_root() + '/vapi/config.vapi',
    '--target-glib=' + min_glib_version,
    '--vapidir=' + meson.source_root() + '/vapi/',
    '--gresources=' + meson.source_root() + '/cawbird.gresource.xml',
  ],
  c_args: [
    '-Werror=implicit-function-declaration'
  ]
)
cb_dep = declare_dependency(
  link_with: cb_lib,
  dependencies: cb_deps,
  include_directories: [srcdir],
)


# actual executable
executable(
  'cawbird',
  'src/main.vala',
  cb_resources,
  dependencies: cb_dep,
  include_directories: srcdir,
  vala_args: [
    meson.source_root() + '/vapi/config.vapi',
    meson.source_root() + '/vapi/cawbird-internal.vapi',
    meson.source_root() + '/vapi/libtl.vapi',
  ],
  install: true
)

subdir('data')
subdir('po')
subdir('tests')
if enable_examples
  subdir('examples')
endif
