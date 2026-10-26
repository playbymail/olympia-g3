#!/bin/bash
###########################################################################
# Regression: month-end decay and upkeep (issue #234, phase backlog
# parent #227).
#
# Extracts the frozen scenario (scenario.patch over the shared
# tests/olympia/fixtures/world.tgz) and runs turn 13. At month end a
# hindered noble's hinder wears off a step, a spent summon is released, a
# run-down contract unit deserts, old pillage loot and relics decay (one
# relic vanishes), animals die, a ghost warrior evaporates, a body 13 turns
# dead rots, and two collapsed mines count down (one is cleared away). See
# phase-month-decay.lua and README.md.
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
. "${ROOT}/tests/olympia/engine.sh"
engine_no_update "$@"
. "${ROOT}/tests/olympia/fixtures/scenario.sh"
. "${ROOT}/tests/olympia/fixtures/coverage.sh"

FILES=(save/13/300 save/13/301 save/13/302 save/13/303 save/13/304
	save/13/305 fact/300 fact/301 fact/302 fact/303 fact/304 fact/305)
PHASE_CELLS=(decrement_meditation_hinder:decrement loyalty_decay:release
	loyalty_decay:desert pillage_decay:decay relic_decay:decay
	relic_decay:vanish animal_deaths:death ghost_warrior_decay:evaporate
	dead_body_rot:rot collapsed_mine_decay:decrement
	collapsed_mine_decay:clear)

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
