#!/bin/bash
###########################################################################
# Regression: the recruitment family refused and failing (issue #130).
#
# Extracts the frozen scenario (scenario.patch over the shared
# tests/olympia/fixtures/world.tgz) and runs one turn. One faction's noble,
# in a tower with no peasants and with no recruitment skill, issues every
# recruitment verb and each start fails; the player entity issues them too
# and is refused. A second faction's skilled noble, where oly.mob has spent
# the mob cookie, fails raise and rally past the skill check.
# See recruitment-refused.lua and README.md.
#
# Three checks, all required:
#   1. coverage: every verb:outcome in CELLS has a nonzero count in the
#      turn's --coverage dump, so the backlog cells this fixture claims stay
#      true;
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

FILES=(save/1/300 save/1/301 fact/300 fact/301)
CELLS=()
for v in recruit form raise rally; do
	CELLS+=("${v}:fail" "${v}:rejected")
done

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
