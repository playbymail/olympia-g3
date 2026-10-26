#!/bin/bash
###########################################################################
# Regression: guard-pillage combat + per-battle keyed RNG (issue #25).
#
# Extracts the frozen scenario (scenario.patch over the shared
# tests/olympia/fixtures/world.tgz) and runs one turn. The pillager
# (Warlord Grok, faction 300) issues `pillage 1` in a province guarded by a
# different faction's unit (Captain Vigil, faction 301, `guard 1`). That drives
#     v_pillage -> attack_guard_units -> combat_top
# i.e. the combat resolution path migrated onto a per-battle keyed RNG stream
# (lib/rng.{c,h}; begin_battle()/crnd() in combat.c). The committed manifest
# pins the resulting battle report + final unit state, so a regression in the
# combat resolution or the keyed-RNG derivation is caught here -- in this
# subsystem's own small golden tree, NOT the 206-file main manifest.
#
# EXPECT.json pins the post-turn --state-export snapshot (#104) next to the
# hashes. The hashes stay the strict gate; the JSON diff shows *which* unit,
# item or location moved when they fail (and is what a port is debugged with).
#
# NOTE: this fixture does NOT exercise issue #4's guard-dedup branch. That
# branch is unreachable through the pillage path (a guard found by
# loop_here(province) can never be in the pillager's stack-only l_a), so the
# #4 fix is output-neutral for every constructible game state -- verified by an
# A/B build (fixed vs buggy => byte-identical report). See README.md.
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

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
scenario_unpack "${HERE}" "${WORK}" || exit 2

( cd "${WORK}" && "${BIN}" -r -l ./lib -S test-use-const-report-date \
	--state-export "${WORK}/state.json" </dev/null >/dev/null 2>&1 )
ec=$?
if [ "${ec}" -ne 0 ]; then
	echo "NO  (olympia-g3 turn failed: exit ${ec})"
	exit 1
fi

# Hash the battle reports + final unit state for both factions.
manifest() { ( cd "${WORK}/lib" && shasum -a 256 \
	save/1/300 save/1/301 fact/300 fact/301 ); }

if [ "${1:-}" = "--update" ]; then
	manifest > "${HERE}/EXPECT.sha256"
	cp "${WORK}/state.json" "${HERE}/EXPECT.json"
	echo "updated ${HERE}/EXPECT.sha256 and EXPECT.json"
	exit 0
fi

fail=0
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
