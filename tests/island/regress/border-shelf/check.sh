#!/bin/bash
###########################################################################
# Regression: -b and -c (issue #292).
#
# 0, a non-default value and a negative value of each, on the map with
# existing land so the shelf shapes placement. A negative value is clamped to
# 0, so it must match the 0 case.
#
# A border at least as wide as the map excludes all of its water, so a wider
# one must match it (#302): -b 40, 41 and 1000 on the 40 x 40 map, and on
# the 30 x 15 map -b 16 (wider than the height only) and -b 31. Before the
# fix a border wider than the map indexed `working` out of bounds (a UBSan
# report under asan-ubsan; a segfault on the debug build at -b 100000000).
# With no water left, each is "No room for an island!", exit 1 (#305; the
# no-water gate pins that).
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
	"b-40|land-40.map|seed-a|-s 60 -b 40"
	"b-41|land-40.map|seed-a|-s 60 -b 41"
	"b-1000|land-40.map|seed-a|-s 60 -b 1000"
	"wide-b-15|wide-30x15.map|seed-a|-s 20 -b 15"
	"wide-b-16|wide-30x15.map|seed-a|-s 20 -b 16"
	"wide-b-31|wide-30x15.map|seed-a|-s 20 -b 31"
)

# A negative -b or -c is clamped to 0; a border wider than the map is the map.
island_extra() {
	local p
	for p in b-neg=b-0 c-neg=c-0 b-41=b-40 b-1000=b-40 wide-b-16=wide-b-15 wide-b-31=wide-b-15; do
		if ! cmp -s "${WORK}/${p%%=*}/out.1" "${WORK}/${p#*=}/out.1" ||
		   ! cmp -s "${WORK}/${p%%=*}/randseed" "${WORK}/${p#*=}/randseed"; then
			echo "NO  (${p%%=*} and ${p#*=} differ)"
			return 1
		fi
	done
}

island_gate "$@"
