#!/bin/bash
###########################################################################
# Regenerate scenario.tgz for the guard-pillage combat regression test.
#
# This is a ONE-TIME authoring tool, NOT run by check.sh. It drives the
# engine's own bootstrap to build a tiny, valid game, then freezes the
# pre-turn library as scenario.tgz (pure data: extract + run a turn + hash).
#
# What it builds, starting from the bare-map fixture (tests/olympia/fixtures):
#   - one-time world init is run and baked (seed_has_been_run saved);
#   - two regular factions are minted via the add-player path (-a):
#       300 "Pillager Horde" (noble Warlord Grok)
#       301 "Guard Order"    (noble Captain Vigil)
#   - both nobles are poofed into plain province 10113 (non-safe, has loot),
#     the pillager is armed with 50 soldiers, the guard with 20 + `guard`;
#   - orders: pillager `pillage 1`, guard `guard 1`.
#
# Running a turn then drives v_pillage -> attack_guard_units -> combat_top,
# i.e. the migrated per-battle keyed RNG (issue #25). NOTE: this does NOT
# exercise the issue #4 guard-dedup branch -- that branch is unreachable
# through the pillage path (a guard found by loop_here(province) can never be
# in the pillager's stack-only l_a). See README.md.
#
# Usage:  ./build-scenario.sh      (writes ./scenario.tgz)
###########################################################################
set -eu
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../../../.." && pwd)"
PRESET="${OLYMPIA_PRESET:-debug}"
BIN="${ROOT}/build/${PRESET}/olympia-g3"
SEED_LIB="${ROOT}/tests/olympia/fixtures/lib.tgz"

[ -x "${BIN}" ] || { echo "error: missing ${BIN} (build the ${PRESET} preset first)"; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
cd "${WORK}"

tar zxf "${SEED_LIB}"
rm -f lib/master

# startloc (also bakes the one-time world init on this first load)
"${BIN}" -l ./lib -s </dev/null >/dev/null 2>&1

# two factions, each a starting noble (start-city index 0 / 1)
mkdir -p act/300 act/301
printf 'Pillager Horde\nWarlord Grok\n0\nP Layer One\npillager@example.com\n' > act/300/Join-g3
printf 'Guard Order\nCaptain Vigil\n1\nP Layer Two\nguard@example.com\n'      > act/301/Join-g3
"${BIN}" -l ./lib -a -S </dev/null >/dev/null 2>&1

# discover the minted noble ids (the single unit under each new faction)
PIL="$(awk '/^ un /{print $2; exit}' lib/fact/300)"
GRD="$(awk '/^ un /{print $2; exit}' lib/fact/301)"
[ -n "${PIL}" ] && [ -n "${GRD}" ] || { echo "error: could not find minted nobles"; exit 2; }

# sculpt: both into plain province 10113, arm + set the guard
printf 'be %s\npoof 10113\nadditem 12 50\nbe %s\npoof 10113\nadditem 12 20\nguard 1\nsave\n' \
	"${PIL}" "${GRD}" | "${BIN}" -l ./lib -i >/dev/null 2>&1

# turn orders
mkdir -p lib/orders
printf '%s:pillage 1\n' "${PIL}" > lib/orders/300
printf '%s:guard 1\n'   "${GRD}" > lib/orders/301

# freeze the pre-turn world
tar czf "${HERE}/scenario.tgz" lib
echo "wrote ${HERE}/scenario.tgz  (pillager=${PIL} guard=${GRD} province=10113)"
