#!/bin/bash
###########################################################################
# Regression: land movement and flight (issue #117).
#
# Extracts the frozen scenario (scenario.patch over the shared
# tests/olympia/fixtures/world.tgz) and runs one turn. Two walkers
# loop Greyfell -> Forest -> Plain -> Forest -> Plain -> Forest, one with the
# long verbs (enter, exit, s, north, west, east) and one with their aliases
# (in, out, south, n, w, e); a rider on a winged horse flies to the Plain and
# back. See build-scenario.sh and README.md.
#
# Three checks, all required:
#   1. coverage: every verb in VERBS reaches its `ok` outcome (the turn's
#      --coverage dump), so the backlog cells this fixture claims stay true;
#   2. EXPECT.sha256: the factions' reports and unit state, byte for byte
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

FILES=(save/1/300 save/1/301 save/1/302 fact/300 fact/301 fact/302)
VERBS=(enter exit s north west east in out south n w e fly)

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
for v in "${VERBS[@]}"; do
	n="$(awk -F'\t' -v v="${v}" '
		NR == 1 { for (i = 1; i <= NF; i++) if ($i == "ok") col = i; next }
		$1 == v { print $col }' "${WORK}/coverage.tsv")"
	[ "${n:-0}" -gt 0 ] || { echo "NO  (verb '${v}' did not reach ok: ok=${n:-0})"; fail=1; }
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
