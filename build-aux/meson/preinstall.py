#!/usr/bin/env python3

import subprocess
import sys

print("Fetching \"daemonize\" dependency...")
subprocess.call(["dub", "fetch", "daemonize"])

print("Building \"daemonize\" dependency with compiler \"{0}\"...".format(sys.argv[1]))
result = subprocess.call(["dub", "build", "daemonize", "--compiler=" + sys.argv[1]])

print("Done")
sys.exit(result)