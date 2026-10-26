#!/bin/bash
###########################################################################
# Regression: a failed output write is fatal (issue #290).
#
# genesis-g3 writes Map, Regions, Land, Cities and randseed in that order.
# Each case plants a directory where one of them goes, so its fopen() fails:
# genesis perror()s "genesis: can't write <file>: Is a directory" and exits
# 1, leaving the files written before it. The image case gives --image a
# path in a missing directory: all five world files are written, then the
# BMP fails and genesis exits 1.
#
# Runs each case in CASES in its own empty directory and checks the exit
# status and stderr (EXPECT.log) and every file written (EXPECT.sha256).
# See tests/genesis/genesis.sh.
#
# Pass:  prints YES and exits 0.   Update: ./check.sh --update (C build only)
###########################################################################
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${HERE}/../../genesis.sh"

CASES=(
	"map|--size 10"
	"regions|--size 10"
	"land|--size 10"
	"cities|--size 10"
	"randseed|--size 10"
	"image|--size 10 --image missing/world.bmp"
)

genesis_setup() {	# args: case name, case directory
	case "$1" in
	map)      mkdir "$2/Map" ;;
	regions)  mkdir "$2/Regions" ;;
	land)     mkdir "$2/Land" ;;
	cities)   mkdir "$2/Cities" ;;
	randseed) mkdir "$2/randseed" ;;
	esac
}

genesis_gate "$@"
