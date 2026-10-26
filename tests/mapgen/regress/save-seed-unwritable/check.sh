#!/bin/bash
###########################################################################
# Regression: save_seed() reports a failed fopen() (issue #240).
#
# lib/rnd.c's save_seed() tested fopen()'s FILE * with `>= 0`, which is
# always true, so when randseed could not be created mapgen-g3 ran
# fwrite()/fclose() on NULL and crashed (SIGSEGV) after writing the map.
#
# Runs mapgen-g3 on the standard map fixtures twice, with no randseed file
# in either (so both use the same built-in seed):
#   ref:   randseed is absent, so save_seed() creates it;
#   test:  randseed is a directory, so save_seed()'s fopen() fails.
#
# Checks on the test run: (1) clean exit (no crash); (2) stderr reports
# "couldn't write randseed:"; (3) gate/loc/road match the ref run.
#
# Pass:  prints YES and exits 0.   No EXPECT files: the ref run is the spec.
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

for run in ref test; do
	mkdir "${WORK}/${run}" || exit 2
	cp -p "${FIX}/"{Cities,Land,Map,Regions} "${WORK}/${run}/" || exit 2
done
mkdir "${WORK}/test/randseed" || exit 2

for run in ref test; do
	( cd "${WORK}/${run}" && "${BIN}" >"${WORK}/${run}.out" 2>"${WORK}/${run}.err" )
	ec=$?
	if [ "${ec}" -ne 0 ]; then
		echo "NO  (mapgen-g3 ${run} run failed: exit ${ec})"
		exit 1
	fi
done

fail=0
if ! grep -q "^couldn't write randseed:" "${WORK}/test.err"; then
	echo "NO  (no \"couldn't write randseed:\" on stderr)"
	fail=1
fi
for f in gate loc road; do
	if ! cmp -s "${WORK}/ref/${f}" "${WORK}/test/${f}"; then
		echo "NO  (${f} differs from the ref run)"
		fail=1
	fi
done
if [ "${fail}" -eq 0 ]; then
	echo "YES"
	exit 0
fi
exit 1
