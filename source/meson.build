source_dir = include_directories('.')

conf = configuration_data()
conf.set('VERSION', meson.project_version())
conf.set('pkgdatadir', pkgdatadir)
conf.set('builddatadir', builddatadir)

generated_main = configure_file(input:  'main.d.in',
                                output: 'main.d',
                                configuration: conf,
                                install: true,
                                install_dir: get_option('bindir'))


uiSources += ['source/extrapanel/app/app.d',
            'source/extrapanel/plugin/plugin.d',
            'source/extrapanel/plugin/browser.d',
            'source/extrapanel/util/util.d',
            'source/extrapanel/util/config.d',
            'source/extrapanel/util/exception.d',
            'source/extrapanel/util/paths.d',
            'source/extrapanel/util/logger.d',
            generated_main]

daemonSources += ['source/extrapanel/daemon/daemon.d',
            'source/extrapanel/connection/boilerplate.d',
            'source/extrapanel/connection/bluetooth.d',
            'source/extrapanel/connection/wifi.d',
            'source/extrapanel/connection/usb.d',
            'source/extrapanel/connection/debug.d',
            'source/extrapanel/plugin/plugin.d',
            'source/extrapanel/plugin/runner.d',
            'source/extrapanel/util/config.d',
            'source/extrapanel/util/paths.d',
            'source/extrapanel/util/logger.d']

traySources += ['source/extrapanel/tray/tray.d']