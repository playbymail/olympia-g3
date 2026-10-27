#!/bin/bash
###########################################################################
# Regression: an orphaned unit with no location to touch (issue #330).
#
# check_indep() (olympia/check.c) swears every character with no player to
# the independent player. set_lord() then calls touch_loc(), whose
# touch_loc_pl() (olympia/day.c) takes viewloc() of the unit's location.
# For a unit that is nowhere, or that sits directly in a region, viewloc()
# is 0, and loc_depth(0) failed assert(FALSE) at u.c:386 (exit 134). Now
# touch_loc_pl() returns when viewloc() is 0: there is no location to mark.
#
# Each case extracts the shared base world and edits garrison unit 1009 in
# lib/fact/207: it drops the unit's `lo 207` (no player) and either drops
# its `wh 58706` (nowhere) or points it at region 58761. The DB is then
# loaded and saved (-S, no -r).
#
# Four checks per case, all required:
#   1. the run exits 0 (before the fix: 134);
#   2. no AddressSanitizer or UBSan report on stderr;
#   3. stderr reports swearing unit [1009] to the independent player once;
#   4. the saved lib/fact/100 holds unit 1009: the repair was saved.
#
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

# name|new location for unit 1009 in place of 58706 (empty: nowhere)
CASES=(
	'nowhere|'
	'region|58761'
)

fail=0
for c in "${CASES[@]}"; do
	IFS='|' read -r name wh <<<"${c}"
	dir="${WORK}/${name}"
	mkdir "${dir}" && tar zxf "${WORLD}" -C "${dir}" || exit 2
	lib="${dir}/lib/fact/207"
	WH="${wh}" perl -0pi -e \
		's/(\n1009 char garrison\n.*?) wh 58706\n(.*?) lo 207\n/$1 . ($ENV{WH} eq "" ? "" : " wh $ENV{WH}\n") . $2/se or exit 1' \
		"${lib}" || { echo "error: unit 1009 in lib/fact/207 is not as expected"; exit 2; }

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
	got="$(grep -c 'check_indep: swearing unit \[1009\] to ' "${dir}/err")"
	if [ "${got}" -ne 1 ]; then
		echo "NO  (${name}: ${got} reports of swearing unit [1009], want 1)"
		fail=1
	fi
	if ! grep -q '^1009 char ' "${dir}/lib/fact/100"; then
		echo "NO  (${name}: unit 1009 is not in the saved lib/fact/100)"
		fail=1
	fi
done
if [ "${fail}" -eq 0 ]; then
	echo "YES"
	exit 0
fi
exit 1
