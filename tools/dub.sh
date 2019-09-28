#!/usr/bin/env bash

set -e

PACKAGES="$(find source/extrapanel -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)"

coverage_tmp_folder=".dub-coverage"

if [[ "$*" == *"--coverage"* ]]
then
	mkdir -p $coverage_tmp_folder
	DUB_COVERAGE="1"
fi

exit_trap() {
    if [[ $DUB_COVERAGE == "1" ]]
	then
		USELESS_DUB_COVERAGE_OUTPUT="
-home-
-root-
-tmp-
..-
"
		for useless in $USELESS_DUB_COVERAGE_OUTPUT; do
			rm -rf -- "$useless"*.lst
		done

		mv -f "$coverage_tmp_folder"/* .
		rm -rf "$coverage_tmp_folder"
	fi
}

trap exit_trap EXIT

for subprojects in $PACKAGES; do
	dub "$@" ":$subprojects"
	if [[ "$DUB_COVERAGE" == "1" ]]
	then
		find . -name "source-extrapanel-$subprojects-*.lst" -print0 | xargs -0r mv -t "$coverage_tmp_folder"
	fi
done