#!/bin/bash
###########################################################################
# Coverage: the unit summary truncates long names (issue #359).
#
# summary_trunc_name() (olympia/report.c) cuts a name longer than 15
# bytes back to a word break, then strips trailing stop words ("of",
# "the", ...). For a name with no space in its first 15 bytes, prev_word()
# returns NULL, and the stop-word loop passed that NULL back in, where
# prev_word() compares it with `>` (undefined). Now the loop stops on
# NULL. No sanitizer in our presets catches the comparison, so this
# fixture fails on neither side of the fix; it pins the output a port
# must match.
#
# Each case unpacks the trade-market scenario (Greyfell, 57081), removes
# its orders, and renames unit 4126 (fact/300). One turn runs.
#
# Three checks per case, all required:
#   1. the turn exits 0;
#   2. no AddressSanitizer or UBSan report on stderr;
#   3. faction 300's unit summary line for 4126 ends with the truncated
#      name.
#
# Date-independent via the `test-use-const-report-date` flag.
# Pass:  prints YES and exits 0.   No EXPECT files: nothing else is pinned.
###########################################################################
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../../../.." && pwd)"
. "${ROOT}/tests/olympia/engine.sh"
engine_no_update "$@"
. "${ROOT}/tests/olympia/fixtures/scenario.sh"
SCENARIO="${ROOT}/tests/olympia/regress/trade-market"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

# case|name|summary name
CASES=(
	'unbroken|abcdefghijklmnopqrst|abcdefghijklmno'
	'stop-words|The Lord of the Rings|Lord'
	'word-break|Sword of Kings Forever|Sword of Kings'
	'short|Buyer One|Buyer One'
)

fail=0
for c in "${CASES[@]}"; do
	IFS='|' read -r case name want <<<"${c}"
	dir="${WORK}/${case}"
	mkdir "${dir}" && scenario_unpack "${SCENARIO}" "${dir}" || exit 2
	rm -f "${dir}/lib/orders/300" "${dir}/lib/orders/301"
	NAME="${name}" perl -0pi -e 's/\n4126 char 0\nna [^\n]*\n/\n4126 char 0\nna $ENV{NAME}\n/' \
		"${dir}/lib/fact/300"
	grep -q "^na ${name}\$" "${dir}/lib/fact/300" || { echo "error: ${case}: unit 4126 not renamed"; exit 2; }

	( cd "${dir}" && "${BIN}" -r -l ./lib -S test-use-const-report-date \
		</dev/null >"${dir}/out" 2>"${dir}/err" )
	ec=$?
	if [ "${ec}" -ne 0 ]; then
		echo "NO  (${case}: turn exited ${ec}, want 0)"
		fail=1
		continue
	fi
	if grep -q "AddressSanitizer\|runtime error" "${dir}/err"; then
		echo "NO  (${case}: sanitizer report on stderr)"
		grep -m 3 "AddressSanitizer\|runtime error" "${dir}/err"
		fail=1
	fi
	line="$(grep -m 1 '^0:0::0::4126 ' "${dir}/lib/save/1/300")"
	if [ "${line% "${want}"}" = "${line}" ]; then
		echo "NO  (${case}: summary line '${line}' does not end with ' ${want}')"
		fail=1
	fi
done
if [ "${fail}" -eq 0 ]; then
	echo "YES"
	exit 0
fi
exit 1
