#!/bin/bash
###########################################################################
# Regression: a failed seed save is fatal (issue #240).
#
# lib/rnd.c's save_seed() tested fopen()'s FILE * with `>= 0`, which is
# always true, so when randseed could not be created mapgen-g3 ran
# fwrite()/fclose() on NULL and crashed (SIGSEGV). Now it reports the
# failure and exits 1.
#
# Runs mapgen-g3 on the standard map fixtures with randseed replaced by a
# directory, so save_seed()'s fopen() fails. Checks: (1) exit status 1
# (not a crash, not success); (2) stderr reports "couldn't write randseed:".
#
# Pass:  prints YES and exits 0.
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
mkdir "${WORK}/randseed" || exit 2

( cd "${WORK}" && "${BIN}" >"${WORK}/out" 2>"${WORK}/err" )
ec=$?
if [ "${ec}" -ne 1 ]; then
	echo "NO  (mapgen-g3 exited ${ec}, want 1)"
	exit 1
fi
if ! grep -q "^couldn't write randseed:" "${WORK}/err"; then
	echo "NO  (no \"couldn't write randseed:\" on stderr)"
	exit 1
fi
echo "YES"
exit 0
