#!/bin/bash
###########################################################################
# Regression: regions with no Regions entry (issue #273).
#
# Runs mapgen-g3 on the standard fixtures with this directory's Regions,
# which drops the 'Great Sea' and 'Orwald' seeds. Their regions are left
# unnamed (inside_names[] NULL): an unnamed land region and an unnamed sea.
# Before the fix, mark_bad_locs() and random_tile_from_each_region() passed
# the NULL name to strcmp(), and island_allowed() walked it with *p, so
# mapgen-g3 crashed (SIGSEGV, exit 139). An unnamed region is now never
# 'Impassable Mountains' and never 'Deep', and prints as '??'.
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
cp -p "${HERE}/Regions" "${WORK}/"                           || exit 2

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
