#!/bin/bash
###########################################################################
# Regression: --seed is parsed with strtoull base 0 (issue #290).
#
# 0x10 (hex), 020 (octal) and 16 (decimal) are the same seed, so all three
# cases must write the same files. The stderr banner prints seed=16 for each.
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
	"hex|--seed 0x10 --size 20"
	"octal|--seed 020 --size 20"
	"decimal|--seed 16 --size 20"
)

# The three cases must agree with each other, not just with EXPECT.sha256.
genesis_extra() {
	local f
	for f in Map Regions Land Cities randseed; do
		if ! cmp -s "${WORK}/hex/${f}" "${WORK}/octal/${f}" ||
		   ! cmp -s "${WORK}/hex/${f}" "${WORK}/decimal/${f}"; then
			echo "NO  (${f} differs between 0x10, 020 and 16)"
			return 1
		fi
	done
}

genesis_gate "$@"
