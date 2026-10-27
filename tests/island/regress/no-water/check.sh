#!/bin/bash
###########################################################################
# Regression: no water left for an island is an error (issue #305).
#
# Land, shelf and border squares all have distance 0 from land. When every
# water square was excluded, the start-square draw picked from every square
# on the map, land included, so the forced 1-province island could replace
# an existing terrain square or start city. With land-40.map, -s 60 -b 40
# and repro-seed (ISLANDSCAN000028), row 11 column 10 turned from p to d.
#
# Now island prints "No room for an island!" on stderr and exits 1 before
# any draw: stdout is empty and randseed is unchanged. The no-water cases
# are the repro, a map with no water at all, a shelf that covers all the
# water (-c), and on the 30 x 15 map -b 8, which reaches the middle row.
# -b 7 leaves the middle row as water, so it still places an island.
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
	"repro|land-40.map|repro-seed|-s 60 -b 40"
	"all-land|all-land.map|seed-a|-b 0"
	"shelf|one-peak.map|seed-a|-b 0 -c 8"
	"border-middle|wide-30x15.map|seed-a|-s 20 -b 8"
	"border-room|wide-30x15.map|seed-a|-s 20 -b 7"
)

# A no-water case prints nothing and leaves the seed as it was.
island_extra() {
	local c seed
	for c in repro all-land shelf border-middle; do
		seed="${ISLAND_FIX}/seed-a"
		[ "${c}" = repro ] && seed="${HERE}/repro-seed"
		if [ -s "${WORK}/${c}/out.1" ]; then
			echo "NO  (${c}: stdout is not empty)"
			return 1
		fi
		if ! cmp -s "${WORK}/${c}/randseed" "${seed}"; then
			echo "NO  (${c}: randseed changed)"
			return 1
		fi
	done
}

island_gate "$@"
