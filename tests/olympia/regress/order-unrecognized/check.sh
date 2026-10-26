#!/bin/bash
###########################################################################
# Regression: an order that fails to parse is reported, and the unit's
# next order runs (issue #248).
#
# Extracts the frozen scenario (scenario.patch over the shared
# tests/olympia/fixtures/world.tgz) and runs one turn. Two nobles and one
# player entity have unrecognized orders ahead of valid ones; a fourth noble
# is a control with only a valid order. See order-unrecognized.lua and
# README.md.
#
# Five checks, all required:
#   1. the report lines: each bad order is echoed and followed by
#      "Unrecognized command.", and the order after it runs (the waits
#      finish, the realname takes effect). Before the fix none of the bad
#      orders was reported and nothing after them ran;
#   2. no order is left queued for the three units with bad orders;
#   3. coverage: (unrecognized) is rejected exactly 4 times, and wait:ok
#      has a nonzero count, in the turn's --coverage dump;
#   4. EXPECT.sha256: each faction's report and unit state, byte for byte
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

FILES=(save/1/300 save/1/301 save/1/302 save/1/303 fact/300 fact/301 fact/302 fact/303)
# file|count|text -- the line must appear exactly count times in lib/<file>
LINES=(
	"save/1/300|1|:> frobnicate the widgets"
	"save/1/300|1|:Unrecognized command."
	"save/1/300|1|:Wait finished: three days have passed."
	"save/1/301|1|:> frobnicate"
	"save/1/301|1|:> glorp 5"
	"save/1/301|2|:Unrecognized command."
	"save/1/301|1|:Wait finished: two days have passed."
	"save/1/302|1|:> frobnicate"
	"save/1/302|1|:Unrecognized command."
	"save/1/302|1|:> realname Third Player Renamed"
	"fact/302|1| fn Third Player Renamed"
	"save/1/303|0|:Unrecognized command."
	"save/1/303|1|:Wait finished: three days have passed."
)
# units whose queued orders must all have been taken this turn
DRAINED=(4126 8651 302)

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

fail=0
for l in "${LINES[@]}"; do
	f="${l%%|*}"; rest="${l#*|}"; want="${rest%%|*}"; text="${rest#*|}"
	got="$(grep -cF -- "${text}" "${WORK}/lib/${f}")"
	if [ "${got}" -ne "${want}" ]; then
		echo "NO  (${f}: '${text}' appears ${got} times, want ${want})"
		fail=1
	fi
done
for u in "${DRAINED[@]}"; do
	left="$(cat "${WORK}"/lib/orders/* 2>/dev/null | grep -c "^${u}:")"
	if [ "${left}" -ne 0 ]; then
		echo "NO  (unit ${u} still has ${left} queued orders)"
		fail=1
	fi
done
n="$(awk -F'\t' '$1 == "(unrecognized)" { print $2 }' "${WORK}/coverage.tsv")"
[ "${n:-0}" -eq 4 ] || { echo "NO  ((unrecognized) rejected=${n:-0}, want 4)"; fail=1; }
n="$(awk -F'\t' 'NR == 1 { for (i = 1; i <= NF; i++) if ($i == "ok") col = i; next }
	$1 == "wait" { print $col }' "${WORK}/coverage.tsv")"
[ "${n:-0}" -gt 0 ] || { echo "NO  (verb 'wait' did not reach ok: ok=${n:-0})"; fail=1; }
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
