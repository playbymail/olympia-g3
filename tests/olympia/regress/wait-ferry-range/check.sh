#!/bin/bash
###########################################################################
# Regression: `wait ferry` with an out-of-range entity id is "not a ship"
# (issue #349).
#
# check_wait_conditions() (olympia/c1.c) tested is_ship(p->a1) before it
# checked the id, and is_ship() reads bx[n] unchecked (oly.h subkind()).
# An id past MAX_BOXES read outside bx (exit 139). Now the ferry case checks
# valid_box() first and reports the id as not a ship, like an in-range id
# that is not a ship.
#
# Extracts the shared base world, drops lib/master, adds noble 1000
# (player 200) in plain 10113, and queues three waits: an id past
# MAX_BOXES, a negative id, and the plain itself (the in-range control).
# One turn runs.
#
# Checks, all required:
#   1. the turn exits 0 (before the fix: 139);
#   2. no AddressSanitizer or UBSan report on stderr;
#   3. the report lines below each appear exactly once in lib/save/1/200:
#      every wait finishes at once with "is not a ship".
#
# Date-independent via the `test-use-const-report-date` flag.
# Pass:  prints YES and exits 0.   No EXPECT files: nothing else is pinned.
###########################################################################
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../../../.." && pwd)"
. "${ROOT}/tests/olympia/engine.sh"
engine_no_update "$@"
WORLD="${ROOT}/tests/olympia/fixtures/world.tgz"

[ -f "${WORLD}" ] || { echo "error: missing ${WORLD} (run tests/olympia/fixtures/build-world.sh)"; exit 2; }

ORDERS=(
	'wait ferry 2147483647'
	'wait ferry -5'
	'wait ferry 10113'
)
LINES=(
	'> wait ferry 2147483647'
	'Wait finished: [2147483647] is not a ship'
	'> wait ferry -5'
	'Wait finished: [0] is not a ship'
	'> wait ferry 10113'
	'Wait finished: [ab13] is not a ship'
)

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
tar zxf "${WORLD}" -C "${WORK}" || exit 2
rm -f "${WORK}/lib/master"
printf '1000 char 0\nna Waiter\nLI\n wh 10113\nCH\n lo 200\n he 100\n\n' >>"${WORK}/lib/fact/200"
printf '1000:%s\n' "${ORDERS[@]}" >"${WORK}/lib/orders/200"

( cd "${WORK}" && "${BIN}" -r -l ./lib -S test-use-const-report-date \
	</dev/null >"${WORK}/out" 2>"${WORK}/err" )
ec=$?
if [ "${ec}" -ne 0 ]; then
	echo "NO  (turn exited ${ec}, want 0)"
	exit 1
fi

fail=0
if grep -q "AddressSanitizer\|runtime error" "${WORK}/err"; then
	echo "NO  (sanitizer report on stderr)"
	grep -m 3 "AddressSanitizer\|runtime error" "${WORK}/err"
	fail=1
fi
for want in "${LINES[@]}"; do
	got="$(grep -cxF "1000:0::0:1:${want}" "${WORK}/lib/save/1/200")"
	if [ "${got}" -ne 1 ]; then
		echo "NO  (${got} report lines '${want}', want 1)"
		fail=1
	fi
done
if [ "${fail}" -eq 0 ]; then
	echo "YES"
	exit 0
fi
exit 1
