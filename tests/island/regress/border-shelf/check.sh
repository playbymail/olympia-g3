#!/bin/bash
###########################################################################
# Regression: -b and -c (issue #292).
#
# 0, a non-default value and a negative value of each, on the map with
# existing land so the shelf shapes placement. A negative value is clamped to
# 0, so it must match the 0 case.
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
	"b-0|land-40.map|seed-a|-s 60 -b 0"
	"b-6|land-40.map|seed-a|-s 60 -b 6"
	"b-neg|land-40.map|seed-a|-s 60 -b -1"
	"c-0|land-40.map|seed-a|-s 60 -c 0"
	"c-6|land-40.map|seed-a|-s 60 -c 6"
	"c-neg|land-40.map|seed-a|-s 60 -c -2"
)

# A negative -b or -c is clamped to 0.
island_extra() {
	local p
	for p in b-neg=b-0 c-neg=c-0; do
		if ! cmp -s "${WORK}/${p%%=*}/out.1" "${WORK}/${p#*=}/out.1" ||
		   ! cmp -s "${WORK}/${p%%=*}/randseed" "${WORK}/${p#*=}/randseed"; then
			echo "NO  (${p%%=*} and ${p#*=} differ)"
			return 1
		fi
	done
}

island_gate "$@"
