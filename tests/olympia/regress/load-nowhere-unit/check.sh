#!/bin/bash
###########################################################################
# Regression: a character that is nowhere is moved to the Nowhere
# province on load, and the turn runs (issue #347).
#
# check_nowhere() (olympia/check.c) only warned about a character with no
# location. The turn then took its location: with a queued order,
# exec_precedence() -> here_pos() (stack.c) read bx[0] (exit 139); with no
# order, the auto-attack scan failed valid_box(where) at combat.c (exit
# 134). Now check_nowhere() moves the character to nowhere_loc.
#
# Each case extracts the shared base world, drops lib/master (so every box
# file is scanned), and appends character 1000 to lib/fact/200 with no LI
# (nowhere). The `stop` case also queues `1000:stop`. One turn runs.
#
# Five checks per case, all required:
#   1. the turn exits 0 (before the fix: 139 with the order, 134 without);
#   2. no AddressSanitizer or UBSan report on stderr;
#   3. stderr warns that unit [1000] is nowhere, then that it was moved to
#      the Nowhere province (lib/system nl=), each exactly once;
#   4. the saved lib/fact/200 places unit 1000 in the Nowhere province;
#   5. the `stop` case's report echoes the order: it ran.
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

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

# name|order queued for unit 1000 (empty: none)
CASES=(
	'stop|stop'
	'idle|'
)

fail=0
for c in "${CASES[@]}"; do
	IFS='|' read -r name order <<<"${c}"
	dir="${WORK}/${name}"
	mkdir "${dir}" && tar zxf "${WORLD}" -C "${dir}" || exit 2
	rm -f "${dir}/lib/master"
	printf '1000 char 0\nna Lost\nCH\n lo 200\n he 100\n\n' >>"${dir}/lib/fact/200"
	[ -z "${order}" ] || printf '1000:%s\n' "${order}" >"${dir}/lib/orders/200"
	nl="$(sed -n 's/^nl=//p' "${dir}/lib/system")"
	[ -n "${nl}" ] || { echo "error: no nl= in lib/system"; exit 2; }

	( cd "${dir}" && "${BIN}" -r -l ./lib -S test-use-const-report-date \
		</dev/null >"${dir}/out" 2>"${dir}/err" )
	ec=$?
	if [ "${ec}" -ne 0 ]; then
		echo "NO  (${name}: turn exited ${ec}, want 0)"
		fail=1
		continue
	fi
	if grep -q "AddressSanitizer\|runtime error" "${dir}/err"; then
		echo "NO  (${name}: sanitizer report on stderr)"
		grep -m 3 "AddressSanitizer\|runtime error" "${dir}/err"
		fail=1
	fi
	got="$(grep -c 'warning: unit \[1000\] is nowhere' "${dir}/err")"
	if [ "${got}" -ne 1 ]; then
		echo "NO  (${name}: ${got} nowhere warnings for unit [1000], want 1)"
		fail=1
	fi
	got="$(grep -c 'moved to ' "${dir}/err")"
	if [ "${got}" -ne 1 ]; then
		echo "NO  (${name}: ${got} 'moved to' reports, want 1)"
		fail=1
	fi
	if ! perl -0ne "exit !/\n1000 char 0\n(?:na .*\n)?LI\n wh ${nl}\n/" "${dir}/lib/fact/200"; then
		echo "NO  (${name}: the saved lib/fact/200 does not place unit 1000 in ${nl})"
		fail=1
	fi
	if [ -n "${order}" ] && ! grep -q "^1000:.*:> ${order}\$" "${dir}/lib/save/1/200"; then
		echo "NO  (${name}: the report does not echo '> ${order}' for unit 1000)"
		fail=1
	fi
done
if [ "${fail}" -eq 0 ]; then
	echo "YES"
	exit 0
fi
exit 1
