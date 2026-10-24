#!/bin/bash
###########################################################################
# Regression: press, rumors, posts and messages (issue #118).
#
# Extracts the frozen scenario (scenario.patch over the shared
# tests/olympia/fixtures/world.tgz) and runs one turn. A crier writes press
# and a rumor to the Times, posts a notice in Greyfell and messages another
# faction's noble, each once to succeed and again with text that is refused;
# its player opts out of the Times. See player-press.lua and README.md.
#
# Three checks, all required:
#   1. coverage: every verb:outcome in CELLS has a nonzero count in the
#      turn's --coverage dump, so the backlog cells this fixture claims stay
#      true;
#   2. EXPECT.sha256: the factions' reports and unit state, plus the Times
#      files the turn writes (press, rumors, and the mailing list that
#      `times 1` drops the faction from), byte for byte (the strict gate);
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

FILES=(save/1/300 save/1/301 fact/300 fact/301 times_press times_rumor totimes)
CELLS=(message:ok post:ok press:ok rumor:ok times:ok
	message:fail post:fail press:fail rumor:fail)

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
