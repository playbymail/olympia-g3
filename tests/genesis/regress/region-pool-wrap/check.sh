#!/bin/bash
###########################################################################
# Regression: region names wrap the name pool (issue #290).
#
# A size-99 world has more land regions than the name pool holds, so later
# regions reuse names with a numeric suffix ("Ironvale 2").
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
	"seed-1|--seed 1 --size 99"
)

genesis_extra() {
	if ! grep -q "	Ironvale 2$" "${WORK}/seed-1/Regions"; then
		echo "NO  (Regions has no \"Ironvale 2\")"
		return 1
	fi
}

genesis_gate "$@"
