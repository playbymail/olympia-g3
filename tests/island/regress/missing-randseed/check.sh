#!/bin/bash
###########################################################################
# Regression: no randseed (issues #292, #298).
#
# island reports "randseed could not be opened." on stderr and runs from the
# all-zero seed, then save_seed() writes a new randseed. stdout is the map
# alone. Before the #298 fix the message came from load_seed()'s printf(),
# so it was the first line of the map on stdout.
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
	"no-seed|ocean-40.map|-|-s 20"
)

# stdout is the 40-row map and nothing else.
island_extra() {
	if [ "$(head -1 "${WORK}/no-seed/out.1")" != "$(head -1 "${ISLAND_FIX}/ocean-40.map")" ] ||
	   [ "$(wc -l <"${WORK}/no-seed/out.1" | tr -d " ")" != "40" ]; then
		echo "NO  (stdout is not just the map)"
		return 1
	fi
}

island_gate "$@"
