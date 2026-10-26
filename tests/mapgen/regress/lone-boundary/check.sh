#!/bin/bash
###########################################################################
# Regression: a lone Uldim/Summerbridge boundary glyph (issue #281).
#
# Runs mapgen-g3 on the standard fixtures with this directory's Map and
# Regions. Map adds, in open sea:
#   (2,36-42)  ppp^ppp    a single boundary square; only the west side seeded
#   (2,44-51)  ppp{}ppp   a pair; only the west side seeded, so the unnamed
#                         scan reaches '}' before the land east of it
#   (2,53-59)  sss]sss    a single boundary square; neither side seeded
#   (77,25-31) ppp[ppp    the Regions seed is on the boundary square itself
# Before the fix, a flood that touched a boundary square already claimed by
# another region asserted in flood_land_inside() (exit 134). A flood now
# treats another region's boundary square as a wall.
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
