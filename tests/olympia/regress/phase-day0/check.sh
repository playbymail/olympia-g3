#!/bin/bash
###########################################################################
# Regression: day 0 and day 1 of the turn (issue #232, phase backlog
# parent #227).
#
# Extracts the frozen scenario (scenario.patch over the shared
# tests/olympia/fixtures/world.tgz) and runs one turn. It starts with the
# state an earlier turn leaves: idle independents of each kind, NPC tokens,
# a running order, a pending buy and a freshly restocked market. Savages
# come for a tower, day 0 gives the NPCs orders, adds and melts token
# units, and handles two stops, and day 1 matches the buy. See
# phase-day0.lua and README.md.
#
# Three checks, all required:
#   1. coverage: every phase cell in PHASE_CELLS acts in the turn's
#      --phase-coverage dump (#227), so the backlog cells this fixture
#      claims stay true;
#   2. EXPECT.sha256: each faction's report and unit state, byte for byte
#      (the strict gate);
#   3. EXPECT.json: the post-turn --state-export snapshot (shows *what*
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
. "${ROOT}/tests/olympia/fixtures/coverage.sh"

FILES=(save/1/300 save/1/301 save/1/302 save/1/303 save/1/304 save/1/305
	save/1/306 save/1/307 fact/300 fact/301 fact/302 fact/303 fact/304
	fact/305 fact/306 fact/307)
PHASE_CELLS=(init_savage_attacks:spawn queue_npc_orders:unsworn
	queue_npc_orders:undead queue_npc_orders:savage queue_npc_orders:mob
	queue_npc_orders:bandit check_token_units:melt check_token_units:add
	process_interrupted_units:interrupt process_interrupted_units:idle
	match_all_trades:trade)

[ -x "${BIN}" ] || { echo "error: missing ${BIN} (build the ${PRESET} preset first)"; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
scenario_unpack "${HERE}" "${WORK}" || exit 2

( cd "${WORK}" && "${BIN}" -r -l ./lib -S test-use-const-report-date \
	--phase-coverage "${WORK}/phase-coverage.tsv" \
	--state-export "${WORK}/state.json" </dev/null >/dev/null 2>&1 )
ec=$?
if [ "${ec}" -ne 0 ]; then
	echo "NO  (olympia-g3 turn failed: exit ${ec})"
	exit 1
fi

fail=0
phase_cells "${WORK}/phase-coverage.tsv" "${PHASE_CELLS[@]}" || fail=1
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
