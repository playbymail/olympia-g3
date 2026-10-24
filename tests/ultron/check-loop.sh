#!/bin/bash
###########################################################################
# Check for the Ultron loop driver (loop.py, issue #106).
#
#   1. Two 3-turn runs on trade-routes with one seed: every turn's order
#      files, state export and coverage.tsv must be byte-identical.
#   2. A 3-turn run through inject-crash.sh with an "ultron-crash" order
#      injected on turn 2 must stop there and freeze a fixture, and the
#      fixture's check.sh must reproduce the failure (YES).
#
# Pass: prints YES and exits 0. Uses OLYMPIA_PRESET (default debug).
###########################################################################
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../.." && pwd)"
SCENARIO="${ROOT}/tests/olympia/regress/trade-routes/scenario.tgz"
LOOP=(python3 -B "${HERE}/loop.py" --scenario "${SCENARIO}" --turns 3 --seed 1)

W="$(mktemp -d)"
trap 'rm -rf "${W}"' EXIT
fail=0

"${LOOP[@]}" --work "${W}/a" >/dev/null || { echo "NO  (run a failed)"; exit 1; }
"${LOOP[@]}" --work "${W}/b" >/dev/null || { echo "NO  (run b failed)"; exit 1; }
for t in "${W}"/a/turn-*; do
	n="$(basename "${t}")"
	for f in orders state.json coverage.tsv; do
		diff -r "${t}/${f}" "${W}/b/${n}/${f}" >/dev/null ||
			{ echo "NO  (${n}/${f} differs between runs)"; fail=1; }
	done
done

"${LOOP[@]}" --work "${W}/c" --engine "${HERE}/inject-crash.sh" \
	--inject 2:400:4126:ultron-crash >/dev/null && { echo "NO  (injected crash not detected)"; fail=1; }
fx=("${W}"/c/fixtures/ultron-trade-routes-s1-t002-*)
if [ -x "${fx[0]}/check.sh" ]; then
	[ "$("${fx[0]}/check.sh")" = "YES" ] || { echo "NO  (frozen fixture does not reproduce)"; fail=1; }
else
	echo "NO  (no fixture frozen for turn 2)"; fail=1
fi
[ -d "${W}/c/turn-003" ] && { echo "NO  (loop ran past the failed turn)"; fail=1; }

[ "${fail}" -eq 0 ] && echo "YES"
exit "${fail}"
