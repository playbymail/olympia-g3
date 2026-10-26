#!/bin/bash
###########################################################################
# Regression: Regions/Land entries with no province (issue #278).
#
# Runs mapgen-g3 on the standard fixtures with this directory's Map, Regions
# and Land:
#   Map      (0,0) is a # hole, so the standard 'Great Sea' seed names a hole
#   Regions  adds (99,99), past the map, and (150,5), past MAX_ROW
#   Land     adds (0,0) (the hole), (150,5) and (-1,3)
# Before the fix, set_regions() and set_province_clumps() read
# map[row][col]-> for the seed square without a check, so mapgen-g3 crashed
# (SIGSEGV, exit 139). Each such entry is now reported on stderr
# ("Regions '<name>': no province at (r,c)" / "Land '<name>': ...") and
# skipped. With 'Great Sea' skipped the sea is unnamed, so this also needs
# the #273 fix.
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
cp -p "${HERE}/"{Map,Regions,Land} "${WORK}/"                || exit 2

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
