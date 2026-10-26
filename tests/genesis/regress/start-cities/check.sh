#!/bin/bash
###########################################################################
# Regression: --start-cities (issue #290).
#
# 0 (no start cities), 1, 16 (the maximum), and the default 6 on a size-10
# map, where 6 can't be spaced and place_start_cities() retries with 5.
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
	"none|--seed 4 --start-cities 0"
	"one|--seed 4 --start-cities 1"
	"sixteen|--seed 4 --start-cities 16"
	"spacing-retry|--size 10 --start-cities 6"
)

genesis_gate "$@"
