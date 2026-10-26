#!/bin/bash
###########################################################################
# Regression: usage errors (issue #292).
#
# An unknown option and an option with no argument each print the usage line
# and exit 1, before reading the map or the seed. opterr = 0 suppresses
# getopt's own messages, and the gate runs the generator as argv[0]
# "island-g3", so the usage line is the same on every host.
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

island_gate "$@"
