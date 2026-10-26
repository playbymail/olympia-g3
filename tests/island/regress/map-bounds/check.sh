#!/bin/bash
###########################################################################
# Regression: a map bigger than island's arrays is an error (issue #299).
#
# map, working, distance and ids are [MAX_MAP][MAX_MAP] (120), and each map
# row holds 119 characters and a NUL. The read loop never checked the row
# count, and sscanf("%[^\r\n]") had no field width, so a map taller than
# 120 rows or a row longer than 119 characters wrote past the arrays
# (an ASan stack-buffer-overflow; on the debug build an abort, or rows that
# ran together). A row of a different length, which island skips, was still
# read into map[] first, and fgets() split lines longer than 199 characters.
#
# Now island prints "Map taller than 120 rows!" or "Map row longer than 119
# characters!" on stderr and exits 1 before it loads the seed. A map of
# exactly 120 rows of 119 characters still works, and blank lines after
# row 120 are ignored, as blank lines are anywhere.
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
	"max-size|max-size.map|seed-a|-s 30"
	"blank-tail|blank-tail.map|seed-a|-s 30"
	"too-tall|too-tall.map|seed-a|-s 30"
	"too-wide|too-wide.map|seed-a|-s 30"
	"long-skipped-row|long-skipped-row.map|seed-a|-s 30"
	"split-line|split-line.map|seed-a|-s 30"
)

# A rejected map prints nothing and leaves the seed as it was.
island_extra() {
	local c
	for c in too-tall too-wide long-skipped-row split-line; do
		if [ -s "${WORK}/${c}/out.1" ]; then
			echo "NO  (${c}: stdout is not empty)"
			return 1
		fi
		if ! cmp -s "${WORK}/${c}/randseed" "${ISLAND_FIX}/seed-a"; then
			echo "NO  (${c}: randseed changed)"
			return 1
		fi
	done
}

island_gate "$@"
