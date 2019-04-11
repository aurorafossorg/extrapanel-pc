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


uiSources += ['src/app/app.d',
            'src/plugin/plugin.d',
            'src/plugin/browser.d',
            'src/util/util.d',
            'src/util/config.d',
            'src/util/exception.d',
            'src/util/paths.d',
            'src/util/logger.d',
            generated_main]

daemonSources += ['src/daemon/daemon.d',
            'src/connection/boilerplate.d',
            'src/connection/bluetooth.d',
            'src/connection/wifi.d',
            'src/connection/usb.d',
            'src/connection/debug.d',
            'src/plugin/plugin.d',
            'src/plugin/runner.d',
            'src/util/config.d',
            'src/util/paths.d',
            'src/util/logger.d']

traySources += ['src/tray/tray.d']