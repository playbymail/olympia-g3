#!/bin/bash
###########################################################################
# Regression: a city's opium addiction level moves at month end (issue #252).
#
# Extracts the frozen scenario (scenario.patch over the shared
# tests/olympia/fixtures/world.tgz) and runs one turn. The pusher sells
# Greyfell [57081] all 15 opium it wants at level 0, so its level rises to
# 1; nobody sells to Adalgar [57625] at level 3, so its level falls to 2.
# Before the fix, opium_market_delta could not see the sold-out BUY trade
# and Greyfell stayed at level 0. See trade-opium.lua and README.md.
#
# Three checks, all required:
#   1. the saved opium level (`op`) of each city, named so a failure says
#      which branch broke;
#   2. EXPECT.loc: both cities' saved loc entries, opium trades included;
#   3. EXPECT.sha256: the faction's report and unit state, byte for byte.
#
# Date-independent via the `test-use-const-report-date` flag.
# Pass:  prints YES and exits 0.   Re-baseline: ./check.sh --update
###########################################################################
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../../../.." && pwd)"
. "${ROOT}/tests/olympia/engine.sh"
engine_no_update "$@"
. "${ROOT}/tests/olympia/fixtures/scenario.sh"

FILES=(save/1/300 fact/300)
CITIES=(57081 57625)
LEVELS=(57081:1 57625:2)

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
scenario_unpack "${HERE}" "${WORK}" || exit 2

( cd "${WORK}" && "${BIN}" -r -l ./lib -S test-use-const-report-date \
	</dev/null >/dev/null 2>&1 )
ec=$?
if [ "${ec}" -ne 0 ]; then
	echo "NO  (olympia-g3 turn failed: exit ${ec})"
	exit 1
fi

# The saved entry of each city in CITIES, in that order.
locs() {
	local c
	for c in "${CITIES[@]}"; do
		awk -v hd="${c} loc city" '
			$0 == hd { p = 1 }
			p && /^$/ { exit }
			p' "${WORK}/lib/loc"
		echo
	done
}

manifest() { ( cd "${WORK}/lib" && shasum -a 256 "${FILES[@]}" ); }

if [ "${1:-}" = "--update" ]; then
	locs > "${HERE}/EXPECT.loc"
	manifest > "${HERE}/EXPECT.sha256"
	echo "updated ${HERE}/EXPECT.loc and EXPECT.sha256"
	exit 0
fi

fail=0
for cl in "${LEVELS[@]}"; do
	c="${cl%%:*}"; want="${cl#*:}"
	have="$(awk -v hd="${c} loc city" '
		$0 == hd { p = 1 }
		p && /^$/ { exit }
		p && $1 == "op" { print $2 }' "${WORK}/lib/loc")"
	if [ "${have:-0}" != "${want}" ]; then
		echo "NO  (city ${c}: opium level ${have:-0}, want ${want})"
		fail=1
	fi
done
if ! diff -u "${HERE}/EXPECT.loc" <(locs) >/dev/null; then
	echo "NO  (city loc entries changed vs EXPECT.loc)"
	diff -u "${HERE}/EXPECT.loc" <(locs)
	fail=1
fi
if ! diff -u "${HERE}/EXPECT.sha256" <(manifest) >/dev/null; then
	echo "NO  (output changed vs EXPECT.sha256)"
	diff -u "${HERE}/EXPECT.sha256" <(manifest)
	fail=1
fi
if [ "${fail}" -eq 0 ]; then
	echo "YES"
	exit 0
fi
exit 1
