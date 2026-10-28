#!/bin/bash
###########################################################################
# Regression: a regular player's character is told when its NPC token
# vanishes (issue #355).
#
# Extracts the frozen scenario (scenario.patch over the shared
# tests/olympia/fixtures/world.tgz) and runs one turn. Holder One holds
# the Horn of the Savages, whose one unit, a band of savages, is flying
# over deep ocean. On day 15 the band plunges into the sea and dies,
# and kill_char destroys the token with its last unit. Before the fix, it
# tested player(who_has) == sub_pl_regular, a faction id (300) against a
# subkind (49), so the holder was never told. See token-vanish.lua and
# README.md.
#
# Three checks, all required:
#   1. the band plunges into the sea on day 15 of the Holders' report;
#   2. the Holders' report says the token vanishes, also on day 15;
#   3. EXPECT.sha256: the Holders' report and unit state, byte for byte.
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

FILES=(save/1/300 fact/300)

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
scenario_unpack "${HERE}" "${WORK}" || exit 2

( cd "${WORK}" && "${BIN}" -r -l ./lib -S test-use-const-report-date \
	</dev/null >/dev/null 2>"${WORK}/stderr" )
ec=$?
if [ "${ec}" -ne 0 ]; then
	echo "NO  (olympia-g3 turn failed: exit ${ec})"
	exit 1
fi
# The sanitizers report on stderr; pass it through.
grep -E "ERROR: (Address|Undefined)Sanitizer|runtime error:" "${WORK}/stderr"

manifest() { ( cd "${WORK}/lib" && shasum -a 256 "${FILES[@]}" ); }

if [ "${1:-}" = "--update" ]; then
	manifest > "${HERE}/EXPECT.sha256"
	echo "updated ${HERE}/EXPECT.sha256"
	exit 0
fi

fail=0
# Report lines are <who>:<flags>::<?>:<day>:<text>.
if ! grep -qE '^[0-9]+:[0-9]+::[0-9]+:15:.*plunges into the sea' \
		"${WORK}/lib/save/1/300"; then
	echo "NO  (the band did not plunge into the sea on day 15)"
	fail=1
fi
if ! grep -qE '^[0-9]+:[0-9]+::[0-9]+:15:Horn of the Savages~\[[0-9a-z]+\] vanishes\.' \
		"${WORK}/lib/save/1/300"; then
	echo "NO  (the Holders were not told the token vanished)"
	fail=1
fi
if ! diff -u "${HERE}/EXPECT.sha256" <(manifest) >/dev/null; then
	echo "NO  (output changed vs EXPECT.sha256)"
	diff -u "${HERE}/EXPECT.sha256" <(manifest)
	fail=1
fi
if [ "${fail}" -eq 0 ]; then
	echo "YES"
	exit 0
fi
exit 1
