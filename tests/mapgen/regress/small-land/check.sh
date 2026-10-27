#!/bin/bash
###########################################################################
# Regression: a map too small for mapgen's random picks (issue #329).
#
# random_province(), not_random_province() and random_island() (mapgen/
# mapgen.c) count the unmarked squares they can choose from and draw
# rnd(1, count). With nothing left the count is 0, and rnd(1, 0) loops
# forever, so mapgen-g3 hung in make_gates(). Now each one reports
# "<function>: no unmarked <province|island> left to choose" and exits 1.
# The check makes no random draw, so every map that ran before is
# unchanged.
#
# Each case writes a 20x20 Map with the standard Cities and randseed,
# its own Regions and an empty Land:
#   one-land  all water but one plains square (the issue's repro);
#   few-land  all water but a row of five plains squares;
#   all-land  all plains, so there is no water to put islands in.
#
# Two checks per case, both required:
#   1. exit status 1 within TIMEOUT seconds (before the fix it hangs: 142);
#   2. the last line on stderr is the case's report.
#
# Pass:  prints YES and exits 0.   No EXPECT files: the checks are inline.
###########################################################################
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../../../.." && pwd)"
FIX="${ROOT}/tests/mapgen/fixtures"
. "${ROOT}/tests/mapgen/mapgen.sh"
mapgen_no_update "$@"
TIMEOUT=20

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

# name|perl printing the Map|Regions (\n, \t escapes)|last stderr line
CASES=(
	'one-land|for $r (0..19) { $l = "," x 20; substr($l, 5, 1) = "p" if $r == 5; print "$l\n" }|0,0\tGreat Sea\n5,5\tOrwald\n|random_province: no unmarked province left to choose'
	'few-land|for $r (0..19) { $l = "," x 20; substr($l, 2, 5) = "ppppp" if $r == 2; print "$l\n" }|0,0\tGreat Sea\n2,2\tOrwald\n|random_province: no unmarked province left to choose'
	'all-land|for $r (0..19) { print "p" x 20, "\n" }|2,2\tOrwald\n|random_island: no unmarked island left to choose'
)

fail=0
for c in "${CASES[@]}"; do
	IFS='|' read -r name map regions want <<<"${c}"
	dir="${WORK}/${name}"
	mkdir "${dir}" || exit 2
	cp -p "${FIX}/"{Cities,randseed} "${dir}/" || exit 2
	perl -e "${map}" >"${dir}/Map" || exit 2
	printf '%b' "${regions}" >"${dir}/Regions" || exit 2
	: >"${dir}/Land"

	( cd "${dir}" && perl -e 'alarm shift; exec @ARGV' "${TIMEOUT}" \
		"${BIN}" >/dev/null 2>"${dir}/stderr" )
	ec=$?
	if [ "${ec}" -ne 1 ]; then
		echo "NO  (${name}: mapgen-g3 exited ${ec}, want 1; 142 is the ${TIMEOUT}s timeout)"
		fail=1
		continue
	fi
	got="$(tail -n 1 "${dir}/stderr")"
	if [ "${got}" != "${want}" ]; then
		echo "NO  (${name}: last stderr line is '${got}', want '${want}')"
		fail=1
	fi
done
if [ "${fail}" -eq 0 ]; then
	echo "YES"
	exit 0
fi
exit 1
