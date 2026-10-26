#!/bin/bash
###########################################################################
# Regression: usage errors (issue #292).
#
# An unknown option and an option with no argument each print the usage line
# and exit 1, before reading the map or the seed. opterr = 0 suppresses
# getopt's own messages, and the gate runs the generator as argv[0]
# "island-g3", so the usage line is the same on every host.
#
# island_extra also runs the generator by its full path: the usage line must
# still name island-g3. Before the #300 fix it printed argv[0] as given.
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
	"unknown|ocean-40.map|seed-a|-x"
	"missing-arg|ocean-40.map|seed-a|-s"
)

# The usage line names island-g3 however the generator is invoked (#300).
island_extra() {
	local want="Usage: island-g3 -b border_width -c continental_shelf_width -s size"
	local got
	got="$(cd "${WORK}" && "${BIN}" -x 2>&1 </dev/null)"
	if [ "${got}" != "${want}" ]; then
		echo "NO  (usage by full path: ${got})"
		return 1
	fi
}

island_gate "$@"
