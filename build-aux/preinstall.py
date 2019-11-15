#!/usr/bin/env python3

import os
import subprocess
import sys
import shutil

project_name = "extrapanel"
app_id = "org.aurorafoss.extrapanel"

if sys.platform == "win32":
	prefix = "C:/"
else:
	prefix = "/usr/local/"

datadir = os.path.join(prefix, "share")

appdatadir = os.path.join(datadir, "appdata")
icondir = os.path.join(datadir, "icons")
pkgdatadir = os.path.join(datadir, project_name)
builddatadir = os.path.join(os.getcwd(), "data")

main_original = open(os.path.join("source/extrapanel", sys.argv[1], "main.d.in")).read()
main_original = main_original.replace("@pkgdatadir@", pkgdatadir)
main_original = main_original.replace("@builddatadir@", builddatadir)

main_generated = open("build-aux/main.d", "w")
main_generated.write(main_original)
main_generated.close()

src_resources_dir = os.path.join(app_id + ".gresource.xml")
os.chdir("data");
subprocess.call(['glib-compile-resources', src_resources_dir])
os.chdir("..");