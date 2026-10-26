#!/bin/bash
###########################################################################
# Regression: an empty map on stdin is an error (issue #295).
#
# With no map rows, the start-square scan found count = 0 and island called
# rnd(1, 0). rnd() assumes high >= low: its mask loop started from
# r = (int)0xffffffff = -1, and r >>= 1 keeps a negative int at -1, so
# island never finished. Blank lines (LF or CRLF) are skipped by the read
# loop, so a file of them is empty too.
#
# Now island prints "No map on stdin!" on stderr and exits 1 before it loads
# the seed: stdout is empty and randseed is unchanged. Before the fix this
# gate does not finish.
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
	"empty|empty.map|seed-a|"
	"blank-lines|blank-lines.map|seed-a|"
	"crlf-lines|crlf-lines.map|seed-a|-s 20"
)

# Nothing printed, and the seed left as it was.
island_extra() {
	local c
	for c in empty blank-lines crlf-lines; do
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
