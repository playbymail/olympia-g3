#!/bin/bash
###########################################################################
# Regression: --image BMP output (issue #290).
#
# --pixels at both bounds, --grid at its maximum, and a size whose BMP rows
# need padding to a multiple of 4 bytes (11 * 3 + 12 * 2 = 57 px, 171 bytes).
# The world files must match the run without --image (the no-image case).
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
	"no-image|--seed 9 --size 11"
	"pixels-1|--seed 9 --size 20 --image world.bmp --pixels 1"
	"pixels-64|--seed 9 --size 10 --image world.bmp --pixels 64"
	"grid-4|--seed 9 --size 20 --image world.bmp --grid 4"
	"padded|--seed 9 --size 11 --image world.bmp --pixels 3 --grid 2"
)

# --image is a debug aid; it must not change the world files.
genesis_extra() {
	local f
	for f in Map Regions Land Cities randseed; do
		if ! cmp -s "${WORK}/no-image/${f}" "${WORK}/padded/${f}"; then
			echo "NO  (--image changed ${f})"
			return 1
		fi
	done
}

genesis_gate "$@"
