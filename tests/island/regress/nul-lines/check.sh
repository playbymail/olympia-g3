#!/bin/bash
###########################################################################
# Regression: a line starting with NUL is skipped (issue #303).
#
# The read loop counted any non-zero sscanf() result as a match. For a line
# starting with NUL, sscanf() sees an empty string and returns EOF (-1),
# writing nothing, so strlen() then read whatever that map row held: a row
# skipped for its length, or uninitialized stack. The output depended on
# stack contents (or UBSan reported an index of -1). Now only a return of 1
# counts, so a NUL-leading line is skipped like a blank line.
#
# Each map is plain.map (20 rows of 20 '.') with a NUL-leading line added:
# first, in the middle, last, and right after a row skipped for its length.
# Each must give the same island as plain.map. A map of only NUL-leading
# lines has no rows: "No map on stdin!", exit 1.
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
	"plain|plain.map|seed-a|-s 30"
	"nul-first|nul-first.map|seed-a|-s 30"
	"nul-middle|nul-middle.map|seed-a|-s 30"
	"nul-last|nul-last.map|seed-a|-s 30"
	"nul-after-skip|nul-after-skip.map|seed-a|-s 30"
	"nul-only|nul-only.map|seed-a|-s 30"
)

# The NUL-leading line is skipped: the same island as plain.map.
island_extra() {
	local c
	for c in nul-first nul-middle nul-last nul-after-skip; do
		if ! cmp -s "${WORK}/${c}/out.1" "${WORK}/plain/out.1" ||
		   ! cmp -s "${WORK}/${c}/randseed" "${WORK}/plain/randseed"; then
			echo "NO  (${c} differs from plain)"
			return 1
		fi
	done
}

island_gate "$@"
