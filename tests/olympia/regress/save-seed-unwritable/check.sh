#!/bin/bash
###########################################################################
# Regression: a failed seed save is fatal (issue #240).
#
# save_seed() tested fopen()'s FILE * with `>= 0`, which is always true, so
# when lib/randseed could not be created it ran fwrite()/fclose() on NULL
# and the engine crashed (SIGSEGV) at the start of save_db(). Now it reports
# the failure and exits 1, before save_db() writes anything else.
#
# Runs one turn on the shared base world with lib/randseed replaced by a
# directory, so save_seed()'s fopen() fails. A directory makes the open
# fail even when run as root, unlike chmod.
#
# Four checks, all required:
#   1. exit status 1 (not a crash, not success);
#   2. stderr reports "couldn't write ./lib/randseed:";
#   3. lib/randseed is still a directory (nothing wrote through it);
#   4. lib/system and lib/master are as they were before the turn: the
#      rest of save_db() did not run.
#
# Date-independent via the `test-use-const-report-date` flag.
# Pass:  prints YES and exits 0.   No EXPECT files: the base world is the spec.
###########################################################################
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../../../.." && pwd)"
. "${ROOT}/tests/olympia/engine.sh"
engine_no_update "$@"
WORLD="${ROOT}/tests/olympia/fixtures/world.tgz"

[ -f "${WORLD}" ] || { echo "error: missing ${WORLD} (run tests/olympia/fixtures/build-world.sh)"; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

for run in base test; do
	mkdir "${WORK}/${run}" && tar zxf "${WORLD}" -C "${WORK}/${run}" || exit 2
done
rm -f "${WORK}/test/lib/randseed" && mkdir "${WORK}/test/lib/randseed" || exit 2

( cd "${WORK}/test" && "${BIN}" -r -l ./lib -S test-use-const-report-date \
	</dev/null >"${WORK}/test.out" 2>"${WORK}/test.err" )
ec=$?
if [ "${ec}" -ne 1 ]; then
	echo "NO  (olympia-g3 turn exited ${ec}, want 1)"
	exit 1
fi

fail=0
if ! grep -q "^couldn't write ./lib/randseed:" "${WORK}/test.err"; then
	echo "NO  (no \"couldn't write ./lib/randseed:\" on stderr)"
	fail=1
fi
if [ ! -d "${WORK}/test/lib/randseed" ]; then
	echo "NO  (lib/randseed is no longer a directory)"
	fail=1
fi
for f in system master; do
	if ! cmp -s "${WORK}/base/lib/${f}" "${WORK}/test/lib/${f}"; then
		echo "NO  (lib/${f} was rewritten after the seed save failed)"
		fail=1
	fi
done
if [ "${fail}" -eq 0 ]; then
	echo "YES"
	exit 0
fi
exit 1
