#!/bin/bash
###########################################################################
# Regression: map holes in the last row and column are bridged (issue #285).
#
# Runs mapgen-g3 on the standard fixtures with this directory's Map and
# Regions. Map adds three # holes with land on both sides:
#   (35,79)  last column, in a land strip (rows 30-40): bridged n-s
#   (79,35)  last row, in a land strip (cols 30-40): bridged e-w
#   (20,79)  last column, land at (20,77-78) and (20,0-1): bridged e-w
#            across the column wrap
# bridge_map_holes() scanned rows 0..max_row-1 and columns 0..max_col-1, so
# holes in the last row or column were never bridged. It now scans
# 0..max_row and 0..max_col.
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
