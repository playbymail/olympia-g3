#!/bin/bash
###########################################################################
# Regression: the top id range stops at MAX_BOXES - 1 (issue #245).
#
# new_ent() (olympia/code.c) minted storms, and its fallback ranges, with
# rnd_alloc_num(79000, MAX_BOXES). rnd_alloc_num() treats `high` as
# inclusive, and bx[] has MAX_BOXES entries, so a draw of 150000 read
# bx[150000], one past the array. When that read was NULL, new_ent()
# returned 150000 and alloc_box() failed its `n < MAX_BOXES` assert. Now
# those calls pass MAX_BOXES - 1.
#
# Runs one turn on the shared base world with lib/randseed set to SEED.
# Under that seed the turn's 632nd mint draw (counter 631) is a fog storm
# whose draw lands on 150000 with the old range. With the fix the draw
# is rejected and redrawn (rng_draw's mask is the same, 0x1ffff), so the
# storm gets 127766. Every other draw is unchanged: mint draws are keyed
# on the stream counter.
#
# Three checks, all required:
#   1. the turn exits 0 (before the fix: an assert, exit 134 on debug, or
#      a heap-buffer-overflow under asan-ubsan);
#   2. storm 127766 is in lib/misc, the id the redraw gives;
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
WORLD="${ROOT}/tests/olympia/fixtures/world.tgz"
SEED='bug-245-1004...'	# 16 bytes with the newline

[ -x "${BIN}" ] || { echo "error: missing ${BIN} (build the ${PRESET} preset first)"; exit 2; }
[ -f "${WORLD}" ] || { echo "error: missing ${WORLD} (run tests/olympia/fixtures/build-world.sh)"; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
tar zxf "${WORLD}" -C "${WORK}" || exit 2
printf '%s\n' "${SEED}" >"${WORK}/lib/randseed" || exit 2

( cd "${WORK}" && "${BIN}" -r -l ./lib -S test-use-const-report-date \
	</dev/null >"${WORK}/turn.out" 2>&1 )
ec=$?
if [ "${ec}" -ne 0 ]; then
	echo "NO  (olympia-g3 turn failed: exit ${ec})"
	grep -m 3 -i "assert\|AddressSanitizer" "${WORK}/turn.out"
	exit 1
fi

if ! grep -q '^127766 storm fog$' "${WORK}/lib/misc"; then
	echo "NO  (storm 127766 is not in lib/misc)"
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
