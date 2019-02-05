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


sources += ['src/app/app.d',
            'src/connection/connection.d',
            'src/connection/wifi.d',
            'src/plugin/plugin.d',
            'src/util/util.d',
            'src/util/config.d',
            generated_main]