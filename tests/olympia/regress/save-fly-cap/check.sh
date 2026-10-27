#!/bin/bash
###########################################################################
# Regression: print_item() saves fly_cap under its own test (issue #314).
#
# print_item() (olympia/io.c) wrote the `fc` (fly_cap) line under
# `if (p->ride_cap)`. An item with a fly_cap but no ride_cap lost it on
# save, and every item with a ride_cap got an `fc 0` line. Now the
# test is `if (p->fly_cap)`.
#
# The fixture extracts the base world, gives box 13 (archer, no rc and
# no fc) an `fc 75` line, then loads and saves the DB (-S, no -r).
#
# Checks, all required:
#   1. the load exits 0;
#   2. box 13 is saved with `fc 75`;
#   3. box 14 (knight, rc 100 and fly_cap 0) is saved with no fc line;
#   4. box 54 (rc 150, fc 150) keeps its `fc 150`;
#   5. no `fc 0` line is saved anywhere in lib/item.
#
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
tar zxf "${WORLD}" -C "${WORK}" || exit 2
lib="${WORK}/lib/item"

box() {		# args: n; print box n of lib/item
	awk -v n="$1" 'BEGIN { RS = "" } $1 == n && $2 == "item"' "${lib}"
}

# Give the archer a fly_cap and no ride_cap.
if ! box 13 | grep -q '^na archer$' || box 13 | grep -q '^ [rf]c '; then
	echo "error: box 13 is not an archer without rc/fc in lib/item"
	exit 2
fi
awk 'BEGIN { RS = ""; ORS = "\n\n" }
	$1 == 13 && $2 == "item" { sub(/\n lc 100/, "&\n fc 75") } { print }' \
	"${lib}" >"${lib}.new" && mv "${lib}.new" "${lib}" || exit 2
box 13 | grep -q '^ fc 75$' || { echo "error: could not add fc 75 to box 13"; exit 2; }

( cd "${WORK}" && "${BIN}" -l ./lib -S </dev/null >"${WORK}/out" 2>&1 )
ec=$?
if [ "${ec}" -ne 0 ]; then
	echo "NO  (load exited ${ec}, want 0)"
	exit 1
fi

fail=0
if ! box 13 | grep -q '^ fc 75$'; then
	echo "NO  (box 13 lost its fc 75)"
	fail=1
fi
if box 14 | grep -q '^ fc '; then
	echo "NO  (box 14 has an fc line: $(box 14 | grep '^ fc '))"
	fail=1
fi
if ! box 54 | grep -q '^ fc 150$'; then
	echo "NO  (box 54 lost its fc 150)"
	fail=1
fi
n="$(grep -c '^ fc 0$' "${lib}")"
if [ "${n}" -ne 0 ]; then
	echo "NO  (${n} fc 0 lines in lib/item)"
	fail=1
fi
if [ "${fail}" -eq 0 ]; then
	echo "YES"
	exit 0
fi
exit 1
