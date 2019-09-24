#!/usr/bin/env bash

set -e

PACKAGES="
ui
manager
tray
daemon
"

for subprojects in $PACKAGES; do
	dub $@ :$subprojects
done