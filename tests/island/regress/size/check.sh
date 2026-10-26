#!/bin/bash
###########################################################################
# Regression: -s (issue #292).
#
# An explicit size; -s 0, which falls back to the random size and must match
# the run with no -s; and -s -5. A negative size also takes the random path,
# but the draws count up from -5, not 0, so the island is 5 provinces
# smaller than the random one (9, not 14). This pins that behavior.
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
	"s-50|ocean-40.map|seed-a|-s 50"
	"s-1|ocean-40.map|seed-a|-s 1"
	"random|ocean-40.map|seed-a|"
	"s-0|ocean-40.map|seed-a|-s 0"
	"s-neg|ocean-40.map|seed-a|-s -5"
)

# -s 0 is the random size.
island_extra() {
	local p
	for p in s-0=random; do
		if ! cmp -s "${WORK}/${p%%=*}/out.1" "${WORK}/${p#*=}/out.1" ||
		   ! cmp -s "${WORK}/${p%%=*}/randseed" "${WORK}/${p#*=}/randseed"; then
			echo "NO  (${p%%=*} and ${p#*=} differ)"
			return 1
		fi
	done
}

island_gate "$@"
