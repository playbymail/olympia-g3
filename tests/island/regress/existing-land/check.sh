#!/bin/bash
###########################################################################
# Regression: placement around existing land (issue #292).
#
# land-40.map has a block of plains and mountains with a start city in the
# north-west and a forest strip in the south-east. The continental shelf and
# the distance-from-land pass keep the new island clear of both; island starts
# it on a square farthest from land.
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
	"seed-a|land-40.map|seed-a|"
	"seed-b|land-40.map|seed-b|"
	"sized|land-40.map|seed-c|-s 120"
)

island_gate "$@"
