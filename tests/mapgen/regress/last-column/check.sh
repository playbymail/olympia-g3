#!/bin/bash
###########################################################################
# Regression: province scans skip the last map column (issue #275).
#
# Runs mapgen-g3 on the standard fixtures with this directory's Map and
# Regions. Map makes the last column (79) land for rows 5-75, with a start
# city, a safe haven, at (40,79); Regions names the strip "Far East".
# random_province(), not_random_province() and the safe-haven pass of
# mark_bad_locs() scanned columns 0..max_col-1 (rows were 0..max_row), so
# no random gate or random city could land in column 79. They now scan
# 0..max_col. In the standard fixtures column 79 is all ocean, so their
# output does not change.
#
# Asserts: (1) clean exit, and (2) gate, loc, road and stderr match the
# committed sha256 manifest (EXPECT.sha256).
#
# Pass:  prints YES and exits 0.   Update manifest: ./check.sh --update
###########################################################################
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../../../.." && pwd)"
FIX="${ROOT}/tests/mapgen/fixtures"
. "${ROOT}/tests/mapgen/mapgen.sh"
mapgen_no_update "$@"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
cp -p "${FIX}/"{Cities,Map,Regions,Land,randseed} "${WORK}/" || exit 2
cp -p "${HERE}/"{Map,Regions} "${WORK}/"                     || exit 2

( cd "${WORK}" && "${BIN}" >/dev/null 2>"${WORK}/stderr" )
ec=$?
if [ "${ec}" -ne 0 ]; then
	echo "NO  (mapgen-g3 crashed/failed: exit ${ec})"
	exit 1
fi

manifest() { ( cd "${WORK}" && shasum -a 256 gate loc road stderr ); }

if [ "${1:-}" = "--update" ]; then
	manifest > "${HERE}/EXPECT.sha256"
	echo "updated ${HERE}/EXPECT.sha256"
	exit 0
fi

if diff -u "${HERE}/EXPECT.sha256" <(manifest) >/dev/null; then
	echo "YES"
	exit 0
else
	echo "NO  (output changed vs EXPECT.sha256)"
	diff -u "${HERE}/EXPECT.sha256" <(manifest)
	exit 1
fi
