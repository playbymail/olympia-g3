#!/bin/bash
###########################################################################
# Regression: guard-pillage combat + per-battle keyed RNG (issue #25).
#
# Extracts the frozen scenario (scenario.tgz) and runs one turn. The pillager
# (Warlord Grok, faction 300) issues `pillage 1` in a province guarded by a
# different faction's unit (Captain Vigil, faction 301, `guard 1`). That drives
#     v_pillage -> attack_guard_units -> combat_top
# i.e. the combat resolution path migrated onto a per-battle keyed RNG stream
# (lib/rng.{c,h}; begin_battle()/crnd() in combat.c). The committed manifest
# pins the resulting battle report + final unit state, so a regression in the
# combat resolution or the keyed-RNG derivation is caught here -- in this
# subsystem's own small golden tree, NOT the 206-file main manifest.
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
PRESET="${OLYMPIA_PRESET:-debug}"
BIN="${ROOT}/build/${PRESET}/olympia-g3"

[ -x "${BIN}" ] || { echo "error: missing ${BIN} (build the ${PRESET} preset first)"; exit 2; }
[ -f "${HERE}/scenario.tgz" ] || { echo "error: missing scenario.tgz (run ./build-scenario.sh)"; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
tar zxf "${HERE}/scenario.tgz" -C "${WORK}" || exit 2

( cd "${WORK}" && "${BIN}" -r -l ./lib -S test-use-const-report-date </dev/null >/dev/null 2>&1 )
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
	echo "updated ${HERE}/EXPECT.sha256"
	exit 0
fi

if diff -u "${HERE}/EXPECT.sha256" <(manifest) >/dev/null; then
	echo "YES"
	exit 0
else
	echo "NO  (output changed vs EXPECT.sha256)"
	diff -u "${HERE}/EXPECT.sha256" <(manifest)
	exit 1
fi
