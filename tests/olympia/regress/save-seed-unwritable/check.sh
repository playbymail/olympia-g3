#!/bin/bash
###########################################################################
# Regression: save_seed() reports a failed fopen() (issue #240).
#
# save_seed() tested fopen()'s FILE * with `>= 0`, which is always true, so
# when lib/randseed could not be created it ran fwrite()/fclose() on NULL
# and the engine crashed (SIGSEGV) at the start of save_db().
#
# Runs one turn on the shared base world twice, with lib/randseed removed
# in both (so both start from the same built-in seed):
#   ref:   lib/randseed is absent, so save_seed() creates it;
#   test:  lib/randseed is a directory, so save_seed()'s fopen() fails.
# A directory makes the open fail even when run as root, unlike chmod.
#
# Four checks, all required, on the test run:
#   1. clean exit (no crash);
#   2. stderr reports "couldn't write ./lib/randseed:";
#   3. lib/randseed is still a directory (nothing wrote through it);
#   4. every other file in lib matches the ref run byte for byte: a failed
#      seed save changes nothing else that save_db() writes.
#
# Date-independent via the `test-use-const-report-date` flag.
# Pass:  prints YES and exits 0.   No EXPECT files: the ref run is the spec.
###########################################################################
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../../../.." && pwd)"
PRESET="${OLYMPIA_PRESET:-debug}"
BIN="${ROOT}/build/${PRESET}/olympia-g3"
WORLD="${ROOT}/tests/olympia/fixtures/world.tgz"

[ -x "${BIN}" ] || { echo "error: missing ${BIN} (build the ${PRESET} preset first)"; exit 2; }
[ -f "${WORLD}" ] || { echo "error: missing ${WORLD} (run tests/olympia/fixtures/build-world.sh)"; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

for run in ref test; do
	mkdir "${WORK}/${run}" && tar zxf "${WORLD}" -C "${WORK}/${run}" || exit 2
	rm -f "${WORK}/${run}/lib/randseed" || exit 2
done
mkdir "${WORK}/test/lib/randseed" || exit 2

for run in ref test; do
	( cd "${WORK}/${run}" && "${BIN}" -r -l ./lib -S test-use-const-report-date \
		</dev/null >"${WORK}/${run}.out" 2>"${WORK}/${run}.err" )
	ec=$?
	if [ "${ec}" -ne 0 ]; then
		echo "NO  (olympia-g3 ${run} turn failed: exit ${ec})"
		exit 1
	fi
done

fail=0
if ! grep -q "^couldn't write ./lib/randseed:" "${WORK}/test.err"; then
	echo "NO  (no \"couldn't write ./lib/randseed:\" on stderr)"
	fail=1
fi
if [ ! -d "${WORK}/test/lib/randseed" ]; then
	echo "NO  (lib/randseed is no longer a directory)"
	fail=1
fi
if ! diff -r -x randseed "${WORK}/ref/lib" "${WORK}/test/lib" >/dev/null; then
	echo "NO  (lib differs from the ref run outside randseed)"
	diff -rq -x randseed "${WORK}/ref/lib" "${WORK}/test/lib"
	fail=1
fi
if [ "${fail}" -eq 0 ]; then
	echo "YES"
	exit 0
fi
exit 1
