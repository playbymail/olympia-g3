#!/bin/bash
###########################################################################
# Regression: a # hole in the bottom-right corner (issue #287).
#
# Runs mapgen-g3 on the standard fixtures with this directory's Map and
# Regions. Map makes (79,74-78) land, (79,79) a # hole and (79,0) land, so the
# hole sits at (max_row, max_col) and is bridged e-w across the column wrap.
# main()'s final "highest province" line read map[max_row][max_col]->region,
# NULL for that hole, so mapgen-g3 crashed (SIGSEGV, exit 139) after writing
# gate, loc and road but before saving randseed. It now prints
# rc_to_region(max_row, max_col), the same number for every map that ran
# before.
#
# Asserts: (1) clean exit, and (2) gate, loc, road, stderr and the saved
# randseed match the committed sha256 manifest (EXPECT.sha256).
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

manifest() { ( cd "${WORK}" && shasum -a 256 gate loc road stderr randseed ); }

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
