#!/bin/bash
###########################################################################
# Regression: a failed seed save is fatal (issue #292).
#
# randseed is a directory, so save_seed()'s fopen() fails: island prints
# "couldn't write randseed:" and perror's "Is a directory" on stderr and
# exits 1 before it prints the map. (load_seed() opens the directory for
# reading without an error on macOS and glibc, and the read fails.)
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
	"randseed-dir|ocean-40.map|-|-s 20"
)

island_setup() {	# args: case name, case directory
	mkdir "$2/randseed"
}

island_gate "$@"
