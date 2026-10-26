#!/bin/bash
###########################################################################
# Regression: argument range checks (issue #290).
#
# Each range check exits 1 with genesis's own message and writes nothing.
# --pixels and --grid are checked only with --image, so out-of-range values
# without it are accepted (the last two cases). getopt_long's own messages come
# from libc and differ between hosts, so no case gives a bad option.
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
	"size-low|--size 9"
	"size-high|--size 100"
	"oceans-low|-n 0"
	"iterations-low|-i 1"
	"iterations-high|-i 11"
	"start-cities-low|--start-cities -1"
	"start-cities-high|--start-cities 17"
	"pixels-low|--image world.bmp --pixels 0"
	"pixels-high|--image world.bmp --pixels 65"
	"grid-low|--image world.bmp --grid -1"
	"grid-high|--image world.bmp --grid 5"
	"ocean-growth-bad|-D --ocean-growth spiral"
	"bfs-without-defer|--ocean-growth bfs"
	"pixels-without-image|--size 10 --pixels 0"
	"grid-without-image|--size 10 --grid 9"
)

genesis_gate "$@"
