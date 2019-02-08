subdir('icons')

data_dir = include_directories('.')
ui_dir = include_directories('ui')

# Import needed modules
gnome= import('gnome')
i18n = import('i18n')

# Do the work
install_data('org.aurorafoss.extrapanel.desktop',
                install_dir: desktopdir)

install_data('org.aurorafoss.extrapanel.appdata.xml',
                install_dir: appdatadir)

resources = gnome.compile_resources(app_id,
                                    app_id + '.gresource.xml',
                                    install: true,
                                    install_dir: pkgdatadir,
                                    gresource_bundle: true)

uiSources += [resources]