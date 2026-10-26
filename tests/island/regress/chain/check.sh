#!/bin/bash
###########################################################################
# Regression: chained runs (issue #292).
#
# island < map | island | island | island: each stage reads the previous map
# and the randseed the previous stage left. The two three-stage cases run the
# same sizes in a different order, so they must differ.
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
	"four|ocean-40.map|seed-a||||"
	"small-first|ocean-40.map|seed-b|-s 30|-s 60|-s 90"
	"large-first|ocean-40.map|seed-b|-s 90|-s 60|-s 30"
)

# The order of the stages matters.
island_extra() {
	if cmp -s "${WORK}/small-first/out.3" "${WORK}/large-first/out.3"; then
		echo "NO  (stage order did not change the result)"
		return 1
	fi
}

island_gate "$@"
