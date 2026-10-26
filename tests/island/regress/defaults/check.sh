#!/bin/bash
###########################################################################
# Regression: island-g3 defaults and the seed (issue #292).
#
# No arguments: border 2, shelf 3, and a random size (the sum of two
# geometric draws of rnd(0, 99)). The all-ocean map with three different
# randseeds must give three different islands, so a generator that ignores
# randseed fails.
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
	"seed-a|ocean-40.map|seed-a|"
	"seed-b|ocean-40.map|seed-b|"
	"seed-c|ocean-40.map|seed-c|"
)

island_gate "$@"
