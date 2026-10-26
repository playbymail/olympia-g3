#!/bin/bash
###########################################################################
# Regression: month-end gold and ranks (issue #234, phase backlog
# parent #227).
#
# Extracts the frozen scenario (scenario.patch over the shared
# tests/olympia/fixtures/world.tgz) and runs turn 8, when every faction
# gains a noble point. Two garrisons bound to a lord's castle forward their
# tax to the castle and to its owner, who ranks as a lord; a priest's
# temple collects offerings; and a player that has sent no orders for two
# turns is dropped (auto_quit=2). See phase-month-gold.lua and README.md.
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

FILES=(save/8/300 save/8/301 save/8/302 fact/300 fact/301 fact/302)
PHASE_CELLS=(garrison_gold:castle garrison_gold:owner
	add_noble_points:point temple_income:offering auto_drop:drop
	determine_noble_ranks:rank)

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
