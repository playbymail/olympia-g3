#!/bin/bash
###########################################################################
# Regression: `wait top` / `wait stack` from the GM player (issue #249).
#
# Extracts the frozen scenario (scenario.patch over the shared
# tests/olympia/fixtures/world.tgz) and runs one turn. The GM player (200),
# which has no units, waits `top`, `not top time 1`, `stack <herald> time 2`
# and `not stack <herald>`; the herald, a lone noble, waits `top` as a
# control. See wait-gm-stack.lua and README.md.
#
# Four checks, all required:
#   1. the turn runs to the end (before the fix it aborted at the
#      kind(who) == T_char assert in stack_leader()), and each wait finishes
#      with the reason in WAITS;
#   2. coverage: wait:ok has a nonzero count in the turn's --coverage dump;
#   3. EXPECT.sha256: the GM's and the faction's reports and the faction's
#      unit state, byte for byte (the strict gate);
#   4. EXPECT.json: the post-turn --state-export snapshot (shows *what*
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

FILES=(save/1/200 save/1/300 fact/300)
CELLS=(wait:ok)
# faction:reason -- the report line "Wait finished: <reason>"
WAITS=(
	"200:we are the stack leader"
	"200:one day has passed."
	"200:two days have passed."
	"200:Herald One~[4126] is not stacked with us."
	"300:we are the stack leader"
)

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
for w in "${WAITS[@]}"; do
	f="${w%%:*}"; why="${w#*:}"
	if ! grep -qF ":Wait finished: ${why}" "${WORK}/lib/save/1/${f}"; then
		got="$(grep -F 'Wait finished:' "${WORK}/lib/save/1/${f}" | sed 's/.*Wait finished: //')"
		echo "NO  (faction ${f}: no wait finished with '${why}'; got '${got}')"
		fail=1
	fi
done
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
