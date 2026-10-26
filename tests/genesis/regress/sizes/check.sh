#!/bin/bash
###########################################################################
# Regression: map sizes and the ocean cap (issue #290).
#
# --size 10, 36 and 99 (the bounds and a middle size). The ocean count is
# capped to min(ceil(size/3), 12): --size 10 with the default 9 oceans and
# --size 30 -n 50 are both clamped, with a warning on stderr.
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
	"size-10|--seed 3 --size 10"
	"size-36|--seed 3 --size 36"
	"size-99|--seed 3 --size 99"
	"ocean-cap|--size 30 -n 50"
)

genesis_gate "$@"
