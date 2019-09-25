#!/usr/bin/env bash

set -e

PACKAGES="
core
ui
manager
tray
daemon
"

for subprojects in $PACKAGES; do
	dub $@ :$subprojects
done
