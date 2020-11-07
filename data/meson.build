i18n = import('i18n')

install_data(
  'uk.co.ibboard.cawbird.gschema.xml',
  install_dir: join_paths(get_option('datadir'), 'glib-2.0', 'schemas')
)
meson.add_install_script('meson_post_install.py')

i18n.merge_file(
  input:  'uk.co.ibboard.cawbird.desktop.in',
  output: 'uk.co.ibboard.cawbird.desktop',
  po_dir: '../po/',
  type:   'desktop',
  install: true,
  install_dir: join_paths(get_option('datadir'), 'applications')
)

if get_option('appdata')
  i18n.merge_file(
    input:  'uk.co.ibboard.cawbird.appdata.xml.in',
    output: 'uk.co.ibboard.cawbird.appdata.xml',
    po_dir: '../po/',
    type:   'xml',
    install: true,
    install_dir: join_paths(get_option('datadir'), 'metainfo')
  )
endif

install_man('cawbird.1')

conf = configuration_data()
conf.set('bindir', join_paths(get_option('prefix'), 'bin'))

configure_file(
  input: 'uk.co.ibboard.cawbird.service.in',
  output: 'uk.co.ibboard.cawbird.service',
  configuration: conf,
  install_dir: join_paths(get_option('datadir'), 'dbus-1/services')
)

gnome.compile_schemas(build_by_default: true)

# Install all application icons in one go
install_subdir(
  'hicolor',
  install_dir: join_paths(get_option('datadir'), 'icons')
)
