#!/bin/bash
###########################################################################
# Regression: secret-sea-route NULL deref in bridge_mountain_sup()
#
# Seed 'S000000000000002' (this dir's randseed) drives bridge_mountain_ports()
# down a path where a mountain port city's only ocean neighbour shuffles into
# the last direction slot (dir_vector[8]). Before the fix, the off-by-one in
# adjacent_tile_water() returned NULL for a slot-8 hit, and bridge_mountain_sup()
# then dereferenced NULL in add_road() -> SIGSEGV. After the fix it emits valid
# "secret sea route" roads.
#
# This check runs mapgen-g3 on the standard map fixtures with the reproducer
# seed and asserts: (1) clean exit (no crash), and (2) gate/loc/road match the
# committed sha256 manifest (EXPECT.sha256).
#
# Pass:  prints YES and exits 0.   Update manifest: ./check.sh --update
###########################################################################
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../../../.." && pwd)"
PRESET="${OLYMPIA_PRESET:-debug}"
BIN="${ROOT}/build/${PRESET}/mapgen-g3"
FIX="${ROOT}/tests/mapgen/fixtures"

[ -x "${BIN}" ] || { echo "error: missing ${BIN} (build the ${PRESET} preset first)"; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
cp -p "${FIX}/"{Cities,Land,Map,Regions} "${WORK}/" || exit 2
cp -p "${HERE}/randseed" "${WORK}/randseed"          || exit 2

( cd "${WORK}" && "${BIN}" >/dev/null 2>&1 )
ec=$?
if [ "${ec}" -ne 0 ]; then
	echo "NO  (mapgen-g3 crashed/failed on reproducer seed: exit ${ec})"
	exit 1
fi

manifest() { ( cd "${WORK}" && shasum -a 256 gate loc road ); }

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
