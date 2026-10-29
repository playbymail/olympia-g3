#!/bin/bash
###########################################################################
# Regression: STOP interrupting the collect, make, repair and sail orders
# an earlier turn left running (issue #361).
#
# Extracts the frozen scenario.tgz, a lib one turn into a game, and runs
# turn 2. On day 0 a STOP interrupts each running order: a partial collect
# on land and from a ship, a one-day and a multi-day make, three partial
# repairs (damage and defense, defense only, damage only), a sail and a
# use 601 in mid-voyage, and a collect and a repair with nothing done yet.
# Then each unit's next order runs. See stop-running.lua,
# stop-running-stop.lua and README.md.
#
# Three checks, all required:
#   1. coverage: every phase cell in PHASE_CELLS has acted in the turn's
#      --phase-coverage dump, and every verb:outcome in CELLS has a nonzero
#      count in its --coverage dump;
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
. "${ROOT}/tests/olympia/fixtures/coverage.sh"

FILES=()
for pl in 300 301 302 303 304 305 306 307 308 309 310; do
	FILES+=(save/2/${pl} fact/${pl})
done
CELLS=(collect:ok sail:ok use:ok)
PHASE_CELLS=(process_interrupted_units:interrupt)

[ -f "${HERE}/scenario.tgz" ] || { echo "error: missing scenario.tgz (run ./build-scenario.sh)"; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
tar zxf "${HERE}/scenario.tgz" -C "${WORK}" || exit 2

( cd "${WORK}" && "${BIN}" -r -l ./lib -S test-use-const-report-date \
	--coverage "${WORK}/coverage.tsv" \
	--phase-coverage "${WORK}/phase-coverage.tsv" \
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
