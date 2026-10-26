#!/bin/bash
###########################################################################
# Regression: --defer-oceans (issue #290).
#
# Oceans are carved out of the water left after the islands and Mt. Olympus
# grow, with the default frontier growth. Seed 7 is plain frontier growth;
# seed 6 leaves landlocked water named as lakes ("Lake Quenmar"); seed 27
# recasts the pool's "Great Sea" as "Great Lake". Tiny water bodies are
# filled with land (the "tiny filled" count on stderr). At size 10 the ocean
# count is clamped and the start cities need a spacing retry.
#
# Runs each case in CASES in its own empty directory and checks the exit
# status and stderr (EXPECT.log) and every file written (EXPECT.sha256).
# See tests/genesis/genesis.sh.
#
# Pass:  prints YES and exits 0.   Update: ./check.sh --update (C build only)
###########################################################################
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${HERE}/../../genesis.sh"

CASES=(
	"frontier|-D --seed 7"
	"lakes|-D --seed 6"
	"great-lake|-D --seed 27"
	"size-10|-D --size 10"
)

genesis_extra() {
	if ! grep -q "	Great Lake$" "${WORK}/great-lake/Regions"; then
		echo "NO  (seed 27 Regions has no \"Great Lake\")"
		return 1
	fi
}

genesis_gate "$@"
