#!/bin/bash
###########################################################################
# Regression: genesis-g3 defaults and --seed (issue #290).
#
# No arguments gives seed 0, size 99, 9 oceans, 10 island iterations and 6
# start cities. Three other seeds must each give a different world, so a
# generator that ignores --seed fails.
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
	"none|"
	"seed-1|--seed 1"
	"seed-2|--seed 2"
	"seed-12345|--seed 12345"
)

genesis_gate "$@"
