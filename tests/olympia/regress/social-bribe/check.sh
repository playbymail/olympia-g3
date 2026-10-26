#!/bin/bash
###########################################################################
# Regression: the social family ok (issue #146).
#
# Extracts the frozen scenario (scenario.patch over the shared
# tests/olympia/fixtures/world.tgz) and runs one turn. In Forest a briber
# bribes a mark, who reports it, and an inciter incites a mob against the
# mark (incite, then use 675: the mob attacks); in Greyfell a noble
# terrorizes the hireling it formed into fear loyalty. Each order starts.
# See social-bribe.lua and README.md.
#
# Three checks, all required:
#   1. coverage: every verb:outcome in CELLS has a nonzero count in the
#      turn's --coverage dump, and every use cell in USE_CELLS in its
#      --use-coverage dump, so the backlog cells this fixture claims stay
#      true, and every phase cell in PHASE_CELLS acts in its
#      --phase-coverage dump (#227);
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

FILES=(save/1/300 save/1/301 save/1/302 save/1/303 fact/300 fact/301 fact/302 fact/303)
CELLS=(bribe:ok incite:ok terrorize:ok)
USE_CELLS=(skill:675:ok)
PHASE_CELLS=(weekly_prisoner_escape_check:escape)

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
scenario_unpack "${HERE}" "${WORK}" || exit 2

( cd "${WORK}" && "${BIN}" -r -l ./lib -S test-use-const-report-date \
	--coverage "${WORK}/coverage.tsv" \
	--phase-coverage "${WORK}/phase-coverage.tsv" \
	--use-coverage "${WORK}/use-coverage.tsv" \
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
use_cells "${WORK}/use-coverage.tsv" "${USE_CELLS[@]}" || fail=1
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
