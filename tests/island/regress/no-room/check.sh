#!/bin/bash
###########################################################################
# Regression: an island larger than the water (issue #292).
#
# tiny-8.map leaves 4 x 4 water inside the border. -s 100 prints "Not enough
# room to expand island!" and the partial island of 16 provinces, exit 0.
# With -b 0 the whole map is water.
#
# Runs each case in CASES in its own empty directory and checks the exit
# status and stderr (EXPECT.log), and every stage's stdout and the final
# randseed (EXPECT.sha256). See tests/island/island.sh.
#
# Pass:  prints YES and exits 0.   Update: ./check.sh --update (C build only)
###########################################################################
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${HERE}/../../island.sh"

# name|map|randseed|stage args|...
CASES=(
	"border-2|tiny-8.map|seed-a|-s 100"
	"border-0|tiny-8.map|seed-a|-s 100 -b 0"
)

island_gate "$@"
