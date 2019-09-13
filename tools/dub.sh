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

if [ "$1" == "test" ]; then
	dub $@ :unit
fi
