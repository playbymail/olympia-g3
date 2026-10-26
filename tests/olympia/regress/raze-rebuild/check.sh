#!/bin/bash
###########################################################################
# Regression: a deleted box does not stay in the chain cache (issue #246).
#
# add_next_chain() and add_sub_chain() (olympia/code.c) cache the last box
# they added and append the next box of the same kind (or subkind) after it
# without walking the chain. delete_box() unlinked a box but left the cache
# alone, so a box added after the cached box was deleted was linked after a
# box that was no longer on the chain, and was lost from loop_kind and
# loop_subkind. Now remove_next_chain()/remove_sub_chain() drop the cache
# when they remove the cached box.
#
# Extracts the frozen scenario (scenario.patch over the shared
# tests/olympia/fixtures/world.tgz) and runs one turn. In Greyfell a noble
# builds a tower under its lower unformed id (1375) on day 4, razes it on
# day 5 and builds a second tower under its higher unformed id (3743) on
# day 6. No weather day falls between the raze and the second build, so
# nothing else is added in between. See raze-rebuild.lua and README.md.
#
# Three checks, all required:
#   1. the turn exits 0;
#   2. the second tower is in lib/loc, which save_db writes by walking the
#      T_loc chain (before the fix it was off the chain and landed in
#      lib/misc);
#   3. EXPECT.sha256: every file in the post-turn lib, byte for byte.
#
# Date-independent via the `test-use-const-report-date` flag.
# Pass:  prints YES and exits 0.   Re-baseline: ./check.sh --update
###########################################################################
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../../../.." && pwd)"
PRESET="${OLYMPIA_PRESET:-debug}"
BIN="${ROOT}/build/${PRESET}/olympia-g3"
. "${ROOT}/tests/olympia/fixtures/scenario.sh"

SECOND=3743	# the razer's higher unformed id; the tower built after the raze

[ -x "${BIN}" ] || { echo "error: missing ${BIN} (build the ${PRESET} preset first)"; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
scenario_unpack "${HERE}" "${WORK}" || exit 2

( cd "${WORK}" && "${BIN}" -r -l ./lib -S test-use-const-report-date \
	</dev/null >"${WORK}/turn.out" 2>&1 )
ec=$?
if [ "${ec}" -ne 0 ]; then
	echo "NO  (olympia-g3 turn failed: exit ${ec})"
	grep -m 3 -i "assert\|AddressSanitizer\|runtime error" "${WORK}/turn.out"
	exit 1
fi

if ! grep -q "^${SECOND} loc tower-in-progress\$" "${WORK}/lib/loc"; then
	echo "NO  (tower ${SECOND} is not in lib/loc: it fell off the T_loc chain)"
	exit 1
fi

manifest() {
	( cd "${WORK}/lib" && find . -type f -print | LC_ALL=C sort \
		| xargs shasum -a 256 )
}

if [ "${1:-}" = "--update" ]; then
	manifest > "${HERE}/EXPECT.sha256"
	echo "updated ${HERE}/EXPECT.sha256"
	exit 0
fi

if ! diff -u "${HERE}/EXPECT.sha256" <(manifest) >/dev/null; then
	echo "NO  (output changed vs EXPECT.sha256)"
	diff -u "${HERE}/EXPECT.sha256" <(manifest)
	exit 1
fi
echo "YES"
exit 0
