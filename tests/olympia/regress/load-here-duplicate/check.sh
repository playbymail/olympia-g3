#!/bin/bash
###########################################################################
# Regression: a stale unit listed more than once in a here list (#331).
#
# check_here() (olympia/check.c) walks each here list with loop_here,
# which iterates over a copy, and removes every unit whose location is
# elsewhere. remove_from_here_list() removes all copies of the unit from
# the real list, so on the copy's second entry it failed
# assert(in_here_list(loc, who)) at loc.c:241 (exit 134). Now check_here()
# skips an entry that is already gone.
#
# Each case extracts the shared base world and lists unit 1023, which is
# elsewhere, several times in the here list of city 58706 (`hl 1009`),
# then loads and saves the DB (-S, no -r).
#
# Four checks per case, all required:
#   1. the run exits 0 (before the fix: 134);
#   2. no AddressSanitizer or UBSan report on stderr;
#   3. stderr reports removing [1023] from the here list of [58706] once;
#   4. the saved lib/loc lists only 1009 in 58706's here list.
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

# name|here list of 58706
CASES=(
	'twice|1009 1023 1023'
	'apart|1023 1009 1023'
	'thrice|1023 1023 1009 1023'
)

fail=0
for c in "${CASES[@]}"; do
	IFS='|' read -r name hl <<<"${c}"
	dir="${WORK}/${name}"
	mkdir "${dir}" && tar zxf "${WORLD}" -C "${dir}" || exit 2
	lib="${dir}/lib/loc"
	HL="${hl}" perl -0pi -e \
		's/(\n58706 loc city\n.*?\n hl) 1009 \n/$1 $ENV{HL}\n/s or exit 1' \
		"${lib}" || { echo "error: city 58706 in lib/loc is not as expected"; exit 2; }

	( cd "${dir}" && "${BIN}" -l ./lib -S </dev/null >"${dir}/out" 2>"${dir}/err" )
	ec=$?
	if [ "${ec}" -ne 0 ]; then
		echo "NO  (${name}: load exited ${ec}, want 0)"
		fail=1
		continue
	fi
	if grep -q "AddressSanitizer\|runtime error" "${dir}/err"; then
		echo "NO  (${name}: sanitizer report on stderr)"
		grep -m 3 "AddressSanitizer\|runtime error" "${dir}/err"
		fail=1
	fi
	got="$(grep -c 'check_here: removing \[1023\] from here list of \[58706\]' "${dir}/err")"
	if [ "${got}" -ne 1 ]; then
		echo "NO  (${name}: ${got} reports of removing [1023], want 1)"
		fail=1
	fi
	got="$(awk '/^58706 loc city$/ { f = 1 } f && /^ hl / { print; exit }' "${lib}")"
	if [ "${got}" != " hl 1009 " ]; then
		echo "NO  (${name}: saved here list of 58706 is '${got}', want ' hl 1009 ')"
		fail=1
	fi
done
if [ "${fail}" -eq 0 ]; then
	echo "YES"
	exit 0
fi
exit 1
