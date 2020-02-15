#!/usr/bin/env python3

import os
import subprocess
import sys
import shutil

project_name = "extrapanel"
app_id = "org.aurorafoss.extrapanel"

executable_names = ("extrapanel", "extrapanel-daemon", "extrapanel-manager", "extrapanel-tray")

if 'DESTDIR' in os.environ:
	prefix = os.environ['DESTDIR']
	print("Dir: ", prefix)
else:
	if sys.platform is "win32":
		prefix = "C:/"
	else:
		prefix = "/usr/"

datadir = os.path.join(prefix, "share")
builddatadir = os.path.join(os.getcwd(), "data")
desktopdir = os.path.join(datadir, "applications")
pkgdatadir = os.path.join(datadir, project_name)
appdatadir = os.path.join(datadir, "appdata")
bindir = os.path.join(prefix, "bin")
iconcachedir = os.path.join(datadir, "icons", "hicolor")
schemasdir = os.path.join(datadir, "glib-2.0", "schemas")

print("Creating non existing folders...")
for path in [prefix, datadir, bindir, desktopdir, pkgdatadir, appdatadir, iconcachedir, schemasdir]:
	if not os.path.exists(path):
		os.makedirs(path)

print("Installing the executables...")
for executable in os.listdir("build"):
    if(executable in executable_names):
        print("Found executable: ", executable)
        shutil.copy2(os.path.join("build", executable), os.path.join(bindir, executable))

if not "--no-gnome-update" in sys.argv:
	print("Updating icon cache...")
	subprocess.call(["gtk-update-icon-cache", "-qtf", iconcachedir])

	print("Updating desktop database...")
	subprocess.call(["update-desktop-database", "-q", desktopdir])

print("Copying desktop and appdata files...")
src_desktop = os.path.join("data", "org.aurorafoss.extrapanel.desktop")
dest_desktop = os.path.join(desktopdir, "org.aurorafoss.extrapanel.desktop")
shutil.copyfile(src_desktop, dest_desktop)

src_appdata = os.path.join("data", "org.aurorafoss.extrapanel.appdata.xml")
dest_appdata = os.path.join(appdatadir, "org.aurorafoss.extrapanel.appdata.xml")
shutil.copyfile(src_appdata, dest_appdata)

print("Compiling GLib resources...")
src_resources_dir = os.path.join(app_id + ".gresource.xml")
os.chdir("data");
subprocess.call(["glib-compile-resources", src_resources_dir])
os.chdir("..");
dest_resources_dir = os.path.join(pkgdatadir, app_id + ".gresource")
shutil.copyfile(os.path.join("data", app_id + ".gresource"), dest_resources_dir)

print("Compiling GSettings schemas...")
subprocess.call(["glib-compile-schemas", schemasdir])

print("Done")