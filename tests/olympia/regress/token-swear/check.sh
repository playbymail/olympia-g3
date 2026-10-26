#!/bin/bash
###########################################################################
# Regression: an NPC token's units swear to the token's new holder when it
# changes hands (issue #251).
#
# Extracts the frozen scenario (scenario.patch over the shared
# tests/olympia/fixtures/world.tgz) and runs one turn. Day 0 adds the band
# of savages the Holders' token controls; on day 8 Holder One gives the
# token to Taker One, and move_token swears the band to the Takers there
# and then. Before the fix, swear_token_units tested
# subkind(unit) == T_char, swore nobody, and the band stayed with the
# Holders until check_token_units repaired it at month end (day 30).
# See token-swear.lua and README.md.
#
# Four checks, all required:
#   1. the turn's stderr has no "fixing token owner": the month-end repair
#      found nothing to fix;
#   2. the Takers' report pays for the band on day 8, the day of the give;
#   3. the Holders' report has no month-end "renounces loyalty";
#   4. EXPECT.sha256: both factions' reports and unit state and the misc
#      log, byte for byte.
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

FILES=(save/1/200 save/1/300 save/1/301 fact/300 fact/301)

[ -x "${BIN}" ] || { echo "error: missing ${BIN} (build the ${PRESET} preset first)"; exit 2; }

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
if grep -q "fixing token owner" "${WORK}/stderr"; then
	echo "NO  (month end had to fix the token unit's owner:" \
		"$(grep "fixing token owner" "${WORK}/stderr"))"
	fail=1
fi
# Report lines are <who>:<flags>::<?>:<day>:<text>.
if ! grep -qE '^[0-9]+:[0-9]+::[0-9]+:8:Paid [0-9]+ NPs? for Savage' \
		"${WORK}/lib/save/1/301"; then
	echo "NO  (the Takers did not get the band on day 8, the day of the give)"
	fail=1
fi
if grep -q "renounces loyalty" "${WORK}/lib/save/1/300"; then
	echo "NO  (the band renounced the Holders at month end, not at the give)"
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
