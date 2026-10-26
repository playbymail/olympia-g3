#!/bin/bash
###########################################################################
# Regression: a ship next to a mountain coast rolls for submerged rocks
# (issue #254).
#
# Extracts the frozen scenario (scenario.patch over the shared
# tests/olympia/fixtures/world.tgz) and runs one turn. Six roundships sit at
# sea all month: four on oceans whose only land neighbor is a mountain, two
# (controls) next to a plain or a forest. See coast-rocks.lua and README.md.
#
# Four checks, all required:
#   1. the damage lines: each faction's report has the number of "struck
#      some submerged rocks" and "struck a coastal reef" lines in HITS
#      (before the fix no ship ever struck rocks: the mountain-coast ships
#      rolled for the reef instead);
#   2. phase coverage: ship_coastal_damage:damage acts in the turn's
#      --phase-coverage dump;
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
. "${ROOT}/tests/olympia/fixtures/coverage.sh"

FILES=(save/1/300 save/1/301 save/1/302 save/1/303 save/1/304 save/1/305
	fact/300 fact/301 fact/302 fact/303 fact/304 fact/305)
PHASE_CELLS=(ship_coastal_damage:damage)
# faction:rocks:reefs -- how many of each damage line the report holds
HITS=(300:2:0 301:2:0 302:1:0 303:0:0 304:0:1 305:0:0)
ROCKS="struck some submerged rocks."
REEF="struck a coastal reef."

[ -x "${BIN}" ] || { echo "error: missing ${BIN} (build the ${PRESET} preset first)"; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
scenario_unpack "${HERE}" "${WORK}" || exit 2

( cd "${WORK}" && "${BIN}" -r -l ./lib -S test-use-const-report-date \
	--phase-coverage "${WORK}/phase-coverage.tsv" \
	--state-export "${WORK}/state.json" </dev/null >/dev/null 2>&1 )
ec=$?
if [ "${ec}" -ne 0 ]; then
	echo "NO  (olympia-g3 turn failed: exit ${ec})"
	exit 1
fi

fail=0
for h in "${HITS[@]}"; do
	IFS=: read -r f want_rocks want_reef <<< "${h}"
	rocks="$(grep -cF "${ROCKS}" "${WORK}/lib/save/1/${f}")"
	reef="$(grep -cF "${REEF}" "${WORK}/lib/save/1/${f}")"
	if [ "${rocks}" -ne "${want_rocks}" ] || [ "${reef}" -ne "${want_reef}" ]; then
		echo "NO  (faction ${f}: want ${want_rocks} rocks, ${want_reef} reef; got ${rocks} rocks, ${reef} reef)"
		fail=1
	fi
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
