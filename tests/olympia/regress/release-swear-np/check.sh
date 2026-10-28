#!/bin/bash
###########################################################################
# Regression: a new owner who can't pay a unit's NPs is an engine bug,
# not a free transfer (issue #352).
#
# Extracts the frozen scenario (scenario.patch over the shared
# tests/olympia/fixtures/world.tgz) and runs one turn. Captor One frees
# Captive One, a prisoner marked swear_on_release, and drop_stack swears
# it to the Captors, who have no NPs left. set_lord's callers check the
# NPs first; this one doesn't. Before the fix, set_lord logged
# "assert fail", moved the unit anyway, refunded its old faction and
# reported "Paid 2 NPs" (exit 0). Now deduct_np's failure fails an
# assertion. See release-swear-np.lua and README.md.
#
# Three checks, all required:
#   1. exit status 134;
#   2. stderr reports the assertion failure in swear.c;
#   3. no AddressSanitizer or UBSan report on stderr.
#
# Pass:  prints YES and exits 0.   No EXPECT files: the checks are inline.
###########################################################################
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../../../.." && pwd)"
. "${ROOT}/tests/olympia/engine.sh"
engine_no_update "$@"
. "${ROOT}/tests/olympia/fixtures/scenario.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
scenario_unpack "${HERE}" "${WORK}" || exit 2

# the outer 2>/dev/null drops the shell's own "Abort trap" notice
( cd "${WORK}" && "${BIN}" -r -l ./lib -S test-use-const-report-date \
	</dev/null >/dev/null 2>"${WORK}/stderr" ) 2>/dev/null
ec=$?

fail=0
if [ "${ec}" -ne 134 ]; then
	echo "NO  (olympia-g3 turn exited ${ec}, want 134)"
	fail=1
fi
if ! grep -q 'assertion failure: .*swear\.c ([0-9]*): FALSE' "${WORK}/stderr"; then
	echo "NO  (stderr does not report the set_lord assertion in swear.c)"
	fail=1
fi
if grep -q "AddressSanitizer\|runtime error" "${WORK}/stderr"; then
	echo "NO  (sanitizer report on stderr)"
	grep -m 3 "AddressSanitizer\|runtime error" "${WORK}/stderr"
	fail=1
fi
if [ "${fail}" -eq 0 ]; then
	echo "YES"
	exit 0
fi
exit 1
