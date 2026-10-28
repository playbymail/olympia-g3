#!/bin/bash
###########################################################################
# Regression: MAX_SAVAGES caps the savages spawned in a turn, not just the
# count before it (issue #354).
#
# Extracts the frozen scenario (scenario.patch over the shared
# tests/olympia/fixtures/world.tgz) and runs one turn. The world holds 199
# bands of savages, one short of MAX_SAVAGES (200), and the builder's 300
# towers in the plain include several that draw a savage spawn on turn 1.
# init_savage_attacks counted the savages once, before its loop over the
# forts, so every fort that drew the roll spawned a band (three here). Now
# each spawn counts, and the cap stops the rest after the first. See
# savage-cap.lua and README.md.
#
# Three checks, all required:
#   1. the turn exits 0, with no AddressSanitizer or UBSan report;
#   2. the --phase-coverage dump has init_savage_attacks:spawn acted
#      exactly once;
#   3. EXPECT.sha256: the Builders' report and unit state, byte for byte.
#
# Date-independent via the `test-use-const-report-date` flag.
# Pass:  prints YES and exits 0.   Re-baseline: ./check.sh --update
###########################################################################
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../../../.." && pwd)"
. "${ROOT}/tests/olympia/engine.sh"
engine_no_update "$@"
. "${ROOT}/tests/olympia/fixtures/scenario.sh"

FILES=(save/1/300 fact/300)

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
scenario_unpack "${HERE}" "${WORK}" || exit 2

( cd "${WORK}" && "${BIN}" -r -l ./lib -S test-use-const-report-date \
	--phase-coverage "${WORK}/phase-coverage.tsv" \
	</dev/null >/dev/null 2>"${WORK}/stderr" )
ec=$?
if [ "${ec}" -ne 0 ]; then
	echo "NO  (olympia-g3 turn failed: exit ${ec})"
	exit 1
fi
# The sanitizers report on stderr; pass it through.
grep -E "ERROR: (Address|Undefined)Sanitizer|runtime error:" "${WORK}/stderr"

manifest() { ( cd "${WORK}/lib" && shasum -a 256 "${FILES[@]}" ); }

if [ "${1:-}" = "--update" ]; then
	manifest > "${HERE}/EXPECT.sha256"
	echo "updated ${HERE}/EXPECT.sha256"
	exit 0
fi

fail=0
# phase  routine  event  ran  acted
spawns="$(awk -F'\t' '$2 == "init_savage_attacks" && $3 == "spawn" { print $5 }' \
	"${WORK}/phase-coverage.tsv")"
if [ "${spawns}" != "1" ]; then
	echo "NO  (init_savage_attacks spawned ${spawns:-?} bands, want 1)"
	fail=1
fi
if ! diff -u "${HERE}/EXPECT.sha256" <(manifest) >/dev/null; then
	echo "NO  (output changed vs EXPECT.sha256)"
	diff -u "${HERE}/EXPECT.sha256" <(manifest)
	fail=1
fi
if [ "${fail}" -eq 0 ]; then
	echo "YES"
	exit 0
fi
exit 1
