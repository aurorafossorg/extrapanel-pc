#!/usr/bin/env python3

import os
import subprocess
import sys
import shutil

project_name = "extrapanel"
app_id = "org.aurorafoss.extrapanel"

executable_names = ("extrapanel", "extrapanel-daemon", "extrapanel-manager", "extrapanel-tray")

if sys.platform is "win32":
	prefix = "C:/"
else:
	prefix = "/usr/local/"

datadir = os.path.join(prefix, "share")
builddatadir = os.path.join(os.getcwd(), "data")
desktopdir = os.path.join(datadir, "applications")
pkgdatadir = os.path.join(datadir, project_name)
appdatadir = os.path.join(datadir, "appdata")
bindir = os.path.join(prefix, "bin")

print("Installing the executables...")
for executable in os.listdir("build"):
    if(executable in executable_names):
        print("Found executable: ", executable)
        shutil.copy2(os.path.join("build", executable), os.path.join(bindir, executable))

print("Updating icon cache...")
icon_cache_dir = os.path.join(datadir, "icons", "hicolor")
if not os.path.exists(icon_cache_dir):
    os.makedirs(icon_cache_dir)
subprocess.call(["gtk-update-icon-cache", "-qtf", icon_cache_dir])

print("Updating desktop database...")
desktop_database_dir = os.path.join(datadir, "applications")
if not os.path.exists(desktop_database_dir):
    os.makedirs(desktop_database_dir)
subprocess.call(["update-desktop-database", "-q", desktop_database_dir])

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
schemas_dir = os.path.join(datadir, "glib-2.0", "schemas")
if not os.path.exists(schemas_dir):
    os.makedirs(schemas_dir)
subprocess.call(["glib-compile-schemas", schemas_dir])
