#!/bin/bash
###########################################################################
# Regression: --island-iterations at its bounds (issue #290).
#
# -i 2 and -i 10 (the default) at size 99, and -i 2 on the smallest map.
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
	"i2|--seed 5 -i 2"
	"i10|--seed 5 -i 10"
	"i2-size-10|--seed 5 -i 2 --size 10"
)

genesis_gate "$@"
