project('extrapanel', 'd',
	version: '0.0.1',
	license: 'GPLv3')

# Declare required directories
datadir = get_option('datadir')
prefix = get_option('prefix')
appdatadir = join_paths (datadir, 'appdata')
icondir = join_paths (datadir, 'icons')
desktopdir = join_paths (datadir, 'applications')
pkgdatadir = join_paths(prefix, datadir, meson.project_name())
builddatadir = join_paths(meson.current_build_dir(), 'data')

# Dependencie Versions
gtkd_ver = '>=3.6'

# Dependencies
gtkd_dep = dependency('gtkd-3', version: gtkd_ver)
riverd_core_dep = dependency('riverd-core', method: 'dub')
riverd_lua_dep = dependency('riverd-lua', method: 'dub')

# Declare the app id
app_id = 'org.aurorafoss.extrapanel'

# Subdirs
uiSources = []
daemonSources = []
traySources = []
subdir('data')
subdir('src')

src_include_dir = include_directories('src')

xpanel_ui = executable('extrapanel', uiSources, dependencies: [gtkd_dep],
					d_args: '-dw', include_directories: src_include_dir,
					install: true)

xpanel_daemon = executable('extrapanel-daemon', daemonSources, dependencies: [riverd_core_dep, riverd_lua_dep],
					d_args: ['-dw', '-d-version=daemon'], include_directories: src_include_dir,
					install: true)

xpanel_tray = executable('extrapanel-tray', traySources, dependencies: [gtkd_dep],
					d_args: ['-dw'], include_directories: src_include_dir,
					install: true)

# Postbuild
meson.add_install_script('build-aux/meson/postinstall.py')
