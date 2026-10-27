#!/bin/bash
###########################################################################
# Regression: a map with no land region (issue #328).
#
# gate_continental_tour() (mapgen/mapgen.c) takes one random tile from
# each land region. With no land region the list is empty (NULL), the
# tour loop doesn't run, and the closing line read l[0] through NULL:
# mapgen-g3 died with SIGSEGV (exit 139) just after printing
# "Continental gate tour:". Now it reports "the map has no land region"
# and exits 1.
#
# Each case writes a 20x20 Map with the standard Cities and randseed, a
# Regions file naming only the sea, and an empty Land:
#   water  every square is `,` (the issue's repro);
#   holes  every square is a `#` hole.
#
# Two checks per case, both required:
#   1. exit status 1 (before the fix: 139);
#   2. the last line on stderr is "the map has no land region".
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
WANT='the map has no land region'

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

# name|map glyph
CASES=(
	'water|,'
	'holes|#'
)

fail=0
for c in "${CASES[@]}"; do
	IFS='|' read -r name glyph <<<"${c}"
	dir="${WORK}/${name}"
	mkdir "${dir}" || exit 2
	cp -p "${FIX}/"{Cities,randseed} "${dir}/" || exit 2
	G="${glyph}" perl -e 'print $ENV{G} x 20, "\n" for 1 .. 20' >"${dir}/Map" || exit 2
	printf '0,0\tGreat Sea\n' >"${dir}/Regions" || exit 2
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
	if [ "${got}" != "${WANT}" ]; then
		echo "NO  (${name}: last stderr line is '${got}', want '${WANT}')"
		fail=1
	fi
done
if [ "${fail}" -eq 0 ]; then
	echo "YES"
	exit 0
fi
exit 1
