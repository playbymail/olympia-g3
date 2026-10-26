#!/bin/bash
###########################################################################
# Regression: -s (issue #292).
#
# An explicit size, and -s 0, -s -5 and -s -1000, which are below 1 and so
# fall back to the random size: each must match the run with no -s.
#
# Before the #294 fix, a negative size counted the random draws up from the
# negative value, not 0: -s -5 gave 9 provinces, not 14, and -s -1000 passed
# malloc() a wrapped length ("Unable to allocate memory for island data!",
# exit 1; an ASan abort under asan-ubsan).
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
	"s-neg-large|ocean-40.map|seed-a|-s -1000"
)

# A size below 1 is the random size.
island_extra() {
	local p
	for p in s-0=random s-neg=random s-neg-large=random; do
		if ! cmp -s "${WORK}/${p%%=*}/out.1" "${WORK}/${p#*=}/out.1" ||
		   ! cmp -s "${WORK}/${p%%=*}/randseed" "${WORK}/${p#*=}/randseed"; then
			echo "NO  (${p%%=*} and ${p#*=} differ)"
			return 1
		fi
	done
}

island_gate "$@"
