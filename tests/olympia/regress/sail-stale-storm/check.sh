#!/bin/bash
###########################################################################
# Regression: a ship sails with a dead storm in its bound-storm list
# (issue #250).
#
# Extracts the frozen scenario (scenario.patch over the shared
# tests/olympia/fixtures/world.tgz) and runs one turn. A captain at sea in
# Ocean [13350] binds a wind to its ship, dissipates a rain that the ship
# lists as bound in the pre-#169 shape (so the dead storm stays in the list)
# and sails north to Ocean [13250]. See sail-stale-storm.lua and README.md.
#
# Five checks, all required:
#   1. the turn completes (before the fix it aborted on ilist_delete's range
#      assert when the ship arrived);
#   2. the saved DB: the ship is in Ocean [13250], its bound-storm list
#      holds the wind alone, the wind came north with it and is bound to it,
#      and the rain is gone;
#   3. coverage: use:ok and sail:ok have nonzero counts in the turn's
#      --coverage dump;
#   4. EXPECT.sha256: the faction's report and unit state, byte for byte
#      (the strict gate);
#   5. EXPECT.json: the post-turn --state-export snapshot (shows *what*
#      changed when the hashes fail).
#
# Date-independent via the `test-use-const-report-date` flag.
# Pass:  prints YES and exits 0.   Re-baseline: ./check.sh --update
###########################################################################
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../../../.." && pwd)"
PRESET="${OLYMPIA_PRESET:-debug}"
BIN="${ROOT}/build/${PRESET}/olympia-g3"
. "${ROOT}/tests/olympia/fixtures/scenario.sh"

FILES=(save/1/300 fact/300)
CELLS=(use:ok sail:ok)
SHIP=61319		# the captain's roundship
STALE=99374		# the rain, bound in the pre-#169 shape and dissipated
GUST=88781		# the wind, bound during the turn
NORTH=13250		# Ocean [13250], where the ship sails

[ -x "${BIN}" ] || { echo "error: missing ${BIN} (build the ${PRESET} preset first)"; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
scenario_unpack "${HERE}" "${WORK}" || exit 2

( cd "${WORK}" && "${BIN}" -r -l ./lib -S test-use-const-report-date \
	--coverage "${WORK}/coverage.tsv" \
	--state-export "${WORK}/state.json" </dev/null >/dev/null 2>&1 )
ec=$?
if [ "${ec}" -ne 0 ]; then
	echo "NO  (olympia-g3 turn failed: exit ${ec})"
	exit 1
fi

# block <file> <id>: print entity <id>'s block from a saved lib file
block() { awk -v id="$2" '$1 == id && NF >= 2 { on = 1 } on && $0 == "" { exit } on' "${WORK}/lib/$1"; }

fail=0
ship="$(block ship "${SHIP}")"
gust="$(block misc "${GUST}")"
grep -qx " wh ${NORTH}" <<<"${ship}" ||
	{ echo "NO  (ship ${SHIP} is not in ${NORTH})"; fail=1; }
grep -qx " bs ${GUST} " <<<"${ship}" ||
	{ echo "NO  (ship ${SHIP}'s bound storms are not just ${GUST}: $(grep '^ bs ' <<<"${ship}"))"; fail=1; }
grep -qx " wh ${NORTH}" <<<"${gust}" ||
	{ echo "NO  (storm ${GUST} did not move with the ship to ${NORTH})"; fail=1; }
grep -qx " bs ${SHIP}" <<<"${gust}" ||
	{ echo "NO  (storm ${GUST} is not bound to ship ${SHIP})"; fail=1; }
[ -z "$(block misc "${STALE}")" ] ||
	{ echo "NO  (storm ${STALE} was not dissipated)"; fail=1; }
for cell in "${CELLS[@]}"; do
	v="${cell%%:*}"; o="${cell#*:}"
	n="$(awk -F'\t' -v v="${v}" -v o="${o}" '
		NR == 1 { for (i = 1; i <= NF; i++) if ($i == o) col = i; next }
		$1 == v { print $col }' "${WORK}/coverage.tsv")"
	[ "${n:-0}" -gt 0 ] || { echo "NO  (verb '${v}' did not reach ${o}: ${o}=${n:-0})"; fail=1; }
done
[ "${fail}" -eq 0 ] || exit 1

manifest() { ( cd "${WORK}/lib" && shasum -a 256 "${FILES[@]}" ); }

if [ "${1:-}" = "--update" ]; then
	manifest > "${HERE}/EXPECT.sha256"
	cp "${WORK}/state.json" "${HERE}/EXPECT.json"
	echo "updated ${HERE}/EXPECT.sha256 and EXPECT.json"
	exit 0
fi

if ! diff -u "${HERE}/EXPECT.sha256" <(manifest) >/dev/null; then
	echo "NO  (output changed vs EXPECT.sha256)"
	diff -u "${HERE}/EXPECT.sha256" <(manifest)
	fail=1
fi
if ! diff -u "${HERE}/EXPECT.json" "${WORK}/state.json" >/dev/null; then
	echo "NO  (state export changed vs EXPECT.json)"
	diff -u "${HERE}/EXPECT.json" "${WORK}/state.json"
	fail=1
fi
if [ "${fail}" -eq 0 ]; then
	echo "YES"
	exit 0
fi
exit 1
