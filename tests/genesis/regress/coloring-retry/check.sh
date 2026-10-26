#!/bin/bash
###########################################################################
# Regression: the ocean 4-coloring retry (issue #290).
#
# With these seeds the requested ocean count can't be 4-colored under mapgen's
# 8-neighbor, column-wrapping adjacency, so add_oceans() re-partitions with one
# ocean fewer. stderr records the retry ("N oceans not 4-colorable").
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
	"size-13|--seed 68 --size 13 -n 5"
	"size-20|--seed 8 --size 20 -n 7"
	"size-40|--seed 39 --size 40 -n 12"
)

genesis_gate "$@"
