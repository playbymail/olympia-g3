#!/bin/bash
###########################################################################
# Regression: map shape (issue #292).
#
# A non-square map (30 wide, 15 tall), and a map whose rows 3, 7 and 11 are a
# different length from row 0: island skips those rows, so the output has 17
# rows.
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
	"wide|wide-30x15.map|seed-a|-s 40"
	"ragged|ragged-20.map|seed-a|-s 40"
)

island_extra() {
	local n
	n="$(wc -l <"${WORK}/ragged/out.1" | tr -d " ")"
	if [ "${n}" != "17" ]; then
		echo "NO  (ragged map printed ${n} rows, want 17)"
		return 1
	fi
}

island_gate "$@"
