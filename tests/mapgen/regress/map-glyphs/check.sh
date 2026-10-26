#!/bin/bash
###########################################################################
# Regression: map holes, special glyphs and sea lanes (issues #274, #276,
# #272).
#
# Runs mapgen-g3 on this directory's own Map, Regions and Land (with the
# standard Cities and randseed) and asserts: (1) clean exit, and (2) gate, loc,
# road and stderr match the committed sha256 manifest (EXPECT.sha256).
#
# Map is the standard fixture map with these squares changed:
#   (0,40) #           hole in row 0: its north neighbours are off the map
#   (39,10-11) ##      two adjacent holes; one is bridged
#   (20,25) #          a single hole inside land; bridged
#   (1,10-13) ;:~"     the sea-lane glyphs (sl 1)
#   (2,36-48)          ppp^vppp{}ppp: Uldim pairs (uf 1-4) as region boundaries
#   (2,58) *           named city alone in the sea: fix_terrain can't infer
#   (10,18) *          named city inside land: terrain inferred
#   (77,30-37)         sss][sss: Summerbridge pair (sf 1-2)
# Regions names every new region (unnamed regions crashed before #273) and has
# one collision (2,37). Land has one entry whose glyph does not match (2,36).
#
# Before the #274 fix, mapgen-g3 crashed on the holes (SIGSEGV, exit 139).
# Before the #272 fix, random_province_gates() gated to (r1,c2), which with
# this seed is a hole, so new_gate() crashed (SIGSEGV, exit 139).
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
cp -p "${FIX}/"{Cities,randseed} "${WORK}/"     || exit 2
cp -p "${HERE}/"{Map,Regions,Land} "${WORK}/"   || exit 2

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
