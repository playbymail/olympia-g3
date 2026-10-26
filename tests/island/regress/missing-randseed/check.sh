#!/bin/bash
###########################################################################
# Regression: no randseed (issue #292).
#
# load_seed() reports "randseed could not be opened." with printf, so the
# message is the first line of stdout, above the map (questioned in #292).
# The seed is then all zero bytes, and save_seed() writes a new randseed.
# This pins the current behavior.
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

island_gate "$@"
