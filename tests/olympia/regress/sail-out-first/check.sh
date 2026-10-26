#!/bin/bash
###########################################################################
# Regression: SAIL to a destination that only the outer location reaches
# sails out first, the same as SAIL in a direction (issue #266).
#
# Extracts the frozen scenario (scenario.patch over the shared
# tests/olympia/fixtures/world.tgz) and runs one turn. Three captains, each
# aboard a crewed roundship docked at the island [59113] in the Ocean
# [13198], sail to the Ocean [13199], east of [13198]: by id, by direction,
# and by a bad argument followed by [13199]'s code. See sail-out-first.lua
# and README.md.
#
# Four checks, all required:
#   1. the report lines: each captain assumes 'sail out' first, arrives in
#      [13198], then in [13199]. Before the fix the two destination orders
#      stopped at "No visible route" and the ships stayed at the island;
#   2. each ship ends the turn in [13199], in the saved lib/ship;
#   3. EXPECT.sha256: each faction's report and unit state, and the ship
#      file, byte for byte (the strict gate);
#   4. EXPECT.json: the post-turn --state-export snapshot (shows *what*
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

EAST=13199		# the Ocean east of the island's Ocean [13198]
SHIPS=(61319 69557 64623)
FILES=(save/1/300 save/1/301 save/1/302 fact/300 fact/301 fact/302 ship)
# file|count|text -- the line must appear exactly count times in lib/<file>
LINES=(
	"save/1/300|2|:> sail 13199"
	"save/1/300|1|:No visible route from Island~[a113] to 13199."
	"save/1/300|1|:(assuming 'sail out' first)"
	"save/1/300|1|:Arrival at Ocean~[bp98]."
	"save/1/300|1|:Arrival at Ocean~[bp99]."
	"save/1/301|2|:> sail east"
	"save/1/301|1|:(assuming 'sail out' first)"
	"save/1/301|1|:Arrival at Ocean~[bp98]."
	"save/1/301|1|:Arrival at Ocean~[bp99]."
	"save/1/302|2|:> sail nowhere bp99"
	"save/1/302|1|:No visible route from Island~[a113] to bp99."
	"save/1/302|1|:(assuming 'sail out' first)"
	"save/1/302|1|:Arrival at Ocean~[bp98]."
	"save/1/302|1|:Arrival at Ocean~[bp99]."
)

[ -x "${BIN}" ] || { echo "error: missing ${BIN} (build the ${PRESET} preset first)"; exit 2; }

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

# block <file> <id>: print entity <id>'s block from a saved lib file
block() { awk -v id="$2" '$1 == id && NF >= 2 { on = 1 } on && $0 == "" { exit } on' "${WORK}/lib/$1"; }

fail=0
for l in "${LINES[@]}"; do
	f="${l%%|*}"; rest="${l#*|}"; want="${rest%%|*}"; text="${rest#*|}"
	got="$(grep -cF -- "${text}" "${WORK}/lib/${f}")"
	if [ "${got}" -ne "${want}" ]; then
		echo "NO  (${f}: '${text}' appears ${got} times, want ${want})"
		fail=1
	fi
done
for s in "${SHIPS[@]}"; do
	if ! block ship "${s}" | grep -qx " wh ${EAST}"; then
		echo "NO  (ship ${s} did not end the turn in the Ocean [${EAST}])"
		fail=1
	fi
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
