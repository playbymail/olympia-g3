#!/bin/bash
###########################################################################
# Regression: --ocean-growth bfs (issue #290).
#
# --defer-oceans growing each ocean ring by ring from its origin. This seed
# leaves landlocked water named as lakes.
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
	"bfs-lakes|-D --ocean-growth bfs --seed 11 --size 60"
	"frontier|-D --ocean-growth frontier --seed 11 --size 60"
)

genesis_gate "$@"
