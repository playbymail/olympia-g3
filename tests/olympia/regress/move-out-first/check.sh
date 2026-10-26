#!/bin/bash
###########################################################################
# Regression: MOVE to a destination that only the outer location reaches
# moves out first, the same as MOVE in a direction (issue #253).
#
# Extracts the frozen scenario (scenario.patch over the shared
# tests/olympia/fixtures/world.tgz) and runs one turn. Three nobles in
# Greyfell [57081] move to the Plain [13450], west of Greyfell's province
# the Forest [13451]: by id, by direction, and by a bad argument followed
# by the Plain's code. See move-out-first.lua and README.md.
#
# Four checks, all required:
#   1. the report lines: each noble assumes 'move out' first and arrives in
#      the Plain. Before the fix the two destination orders stopped at
#      "No visible route" and the nobles stayed in Greyfell;
#   2. each noble ends the turn in the Plain;
#   3. EXPECT.sha256: each faction's report and unit state, byte for byte
#      (the strict gate);
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

PLAIN=13450
NOBLES=(4126 8651 8159)
FILES=(save/1/300 save/1/301 save/1/302 fact/300 fact/301 fact/302)
# file|count|text -- the line must appear exactly count times in lib/<file>
LINES=(
	"save/1/300|2|:> move 13450"
	"save/1/300|1|:No visible route from Greyfell~[d21] to 13450."
	"save/1/300|1|:(assuming 'move out' first)"
	"save/1/300|1|:Arrival at Plain~[bs50]."
	"save/1/301|2|:> move west"
	"save/1/301|1|:(assuming 'move out' first)"
	"save/1/301|1|:Arrival at Plain~[bs50]."
	"save/1/302|2|:> move nowhere bs50"
	"save/1/302|1|:No visible route from Greyfell~[d21] to bs50."
	"save/1/302|1|:(assuming 'move out' first)"
	"save/1/302|1|:Arrival at Plain~[bs50]."
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

fail=0
for l in "${LINES[@]}"; do
	f="${l%%|*}"; rest="${l#*|}"; want="${rest%%|*}"; text="${rest#*|}"
	got="$(grep -cF -- "${text}" "${WORK}/lib/${f}")"
	if [ "${got}" -ne "${want}" ]; then
		echo "NO  (${f}: '${text}' appears ${got} times, want ${want})"
		fail=1
	fi
done
for u in "${NOBLES[@]}"; do
	if ! grep -q "\"id\": ${u}, .*\"where\": ${PLAIN}," "${WORK}/state.json"; then
		echo "NO  (noble ${u} did not end the turn in the Plain [${PLAIN}])"
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
