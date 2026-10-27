#!/bin/bash
###########################################################################
# Regression: a large -c shelf is fast and does not overflow the stack
# (issue #307).
#
# make_shelf() recursed into all four neighbors for each step of -c, marked
# or not: about 4^shelf calls per land square and `shelf` frames deep. On
# land-40.map (122 land squares) -c 13 took 18 s, each step 4 times longer,
# and -c 100000000 overflowed the stack (exit 139). Now one breadth-first
# pass from every land square marks the same squares: water within shelf
# north/south/east/west steps of land.
#
# -c 13 and -c 20 place islands as before; -c 29 leaves a single water
# square; -c 30 covers all the water ("No room for an island!", #305), and
# so does -c 100000000. Each stage must finish within TIMEOUT seconds.
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

TIMEOUT=10

# name|map|randseed|stage args|...
CASES=(
	"c-13|land-40.map|seed-a|-b 0 -c 13"
	"c-20|land-40.map|seed-a|-b 0 -c 20"
	"c-29|land-40.map|seed-a|-b 0 -c 29"
	"c-30|land-40.map|seed-a|-b 0 -c 30"
	"c-huge|land-40.map|seed-a|-b 0 -c 100000000"
)

island_gate "$@"
