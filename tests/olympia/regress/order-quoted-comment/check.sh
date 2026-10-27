#!/bin/bash
###########################################################################
# Regression: a # inside quoted order text is not a comment (issue #315).
#
# remove_comment() (olympia/input.c) meant to skip quoted text, but its
# inner loop started on the opening quote and never advanced, so every #
# cut the order, and a quote at the end of a line walked the scan past
# the string's NUL. Now a quote counts at the start of a token, as in
# parse_line(): a # inside it is kept, an unterminated quote runs to the
# end of the line, and an apostrophe inside a word is ordinary text.
#
# Extracts the frozen scenario (scenario.patch over the shared
# tests/olympia/fixtures/world.tgz) and runs one turn. Six nobles each
# rename themselves with one `name` order. See order-quoted-comment.lua
# and README.md.
#
# Four checks, all required:
#   1. the turn exits 0 with no AddressSanitizer or UBSan report;
#   2. each noble's new name, and the order as echoed in its report;
#   3. EXPECT.sha256: each faction's report and unit state, byte for byte
#      (the strict gate);
#   4. EXPECT.json: the post-turn --state-export snapshot (shows *what*
#      changed when the hashes fail).
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

FILES=(save/1/300 save/1/301 save/1/302 save/1/303 save/1/304 save/1/305
	fact/300 fact/301 fact/302 fact/303 fact/304 fact/305)
# file|whole line (x) or substring (s)|text
LINES=(
	'fact/300|x|na Joe #1'
	"fact/301|x|na Joe's keep"
	'fact/302|x|na Ann #2'
	'fact/303|x|na Bob # x'
	'fact/304|x|na Cal '
	'fact/305|x|na Dee'
	'save/1/300|s|:> name "Joe #1"'
	"save/1/301|s|:> name Joe's keep "
	"save/1/302|s|:> name 'Ann #2' "
	'save/1/303|s|:> name "Bob # x'
	'save/1/304|s|:> name Cal "'
	'save/1/305|s|:> name Dee '
)

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
scenario_unpack "${HERE}" "${WORK}" || exit 2

( cd "${WORK}" && "${BIN}" -r -l ./lib -S test-use-const-report-date \
	--state-export "${WORK}/state.json" </dev/null >"${WORK}/turn.out" 2>&1 )
ec=$?
if [ "${ec}" -ne 0 ]; then
	echo "NO  (olympia-g3 turn failed: exit ${ec})"
	exit 1
fi

fail=0
if grep -q "AddressSanitizer\|runtime error" "${WORK}/turn.out"; then
	echo "NO  (sanitizer report in the turn's output)"
	grep -m 3 "AddressSanitizer\|runtime error" "${WORK}/turn.out"
	fail=1
fi
for l in "${LINES[@]}"; do
	f="${l%%|*}"; rest="${l#*|}"; how="${rest%%|*}"; text="${rest#*|}"
	if [ "${how}" = x ]; then
		got="$(grep -cxF -- "${text}" "${WORK}/lib/${f}")"
	else
		got="$(grep -cF -- "${text}" "${WORK}/lib/${f}")"
	fi
	if [ "${got}" -ne 1 ]; then
		echo "NO  (${f}: '${text}' appears ${got} times, want 1)"
		fail=1
	fi
done
[ "${fail}" -eq 0 ] || exit 1

manifest() { ( cd "${WORK}/lib" && shasum -a 256 "${FILES[@]}" ); }

if [ "${1:-}" = "--update" ]; then
	manifest > "${HERE}/EXPECT.sha256"
	cp "${WORK}/state.json" "${HERE}/EXPECT.json"
	echo "updated ${HERE}/EXPECT.sha256 and EXPECT.json"
	exit 0
fi

if ! diff -u "${HERE}/EXPECT.sha256" <(manifest) >/dev/null; then
	echo "NO  (output changed vs EXPECT.sha256)"
	diff -u "${HERE}/EXPECT.sha256" <(manifest)
	fail=1
fi
if ! diff -u "${HERE}/EXPECT.json" "${WORK}/state.json" >/dev/null; then
	echo "NO  (state export changed vs EXPECT.json)"
	diff -u "${HERE}/EXPECT.json" "${WORK}/state.json"
	fail=1
fi
if [ "${fail}" -eq 0 ]; then
	echo "YES"
	exit 0
fi
exit 1
