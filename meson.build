project('extrapanel', 'd',
	version: '0.0.1',
	license: 'AGPLv3')

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

# Declare the app id
app_id = 'org.aurorafoss.extrapanel'

# Subdirs
sources = []
subdir('data')
subdir('src')

src_include_dir = include_directories('src')

exec = executable('extrapanel', sources, dependencies: [gtkd_dep],
					d_args: '-d', include_directories: src_include_dir,
					install: true)

# Postbuild
meson.add_install_script('build-aux/meson/postinstall.py')
