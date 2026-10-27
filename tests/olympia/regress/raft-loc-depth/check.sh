#!/bin/bash
###########################################################################
# Regression: a raft is a ship at building depth, and a hostile unit can
# attack an occupied raft (issue #348).
#
# loc_depth() (olympia/u.c) had no case for sub_raft or sub_raft_notdone
# and failed assert(FALSE) at u.c:386. check_nowhere() calls it for every
# location, so any raft in the world aborted the load (exit 134). Past that,
# fort_covers() (olympia/combat.c) had no raft case either and failed its
# own assert(FALSE) in combat. Now loc_depth() returns LOC_build for both
# raft subkinds, and fort_covers() gives a raft no cover (a raft has no
# defense to add).
#
# Each case extracts the shared base world, drops lib/master (so every box
# file is scanned), and appends to lib/ship a raft 61102 and a
# raft-in-progress 61103 at plain 10113:
#
#   load    both rafts empty. -l ./lib -S: load, check_db(), save.
#   attack  noble 1001 (independent player 100) aboard raft 61102, and
#           noble 1000 (player 200) in plain 10113, hostile to the raft
#           (ah 61102). One turn: 1000 auto-attacks the raft on day 1.
#
# Checks, all required:
#   1. the run exits 0 (before the fix: 134);
#   2. no AddressSanitizer or UBSan report on stderr;
#   3. the saved lib/ship holds both rafts;
#   4. attack: 1000's report shows "> [auto-attack c102]", and the combat
#      log (lib/save/1/210) shows the combat between Raider and the raft.
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

fail=0
for name in load attack; do
	dir="${WORK}/${name}"
	mkdir "${dir}" && tar zxf "${WORLD}" -C "${dir}" || exit 2
	rm -f "${dir}/lib/master"
	printf '61102 ship raft\nLI\n wh 10113\n\n61103 ship raft-in-progress\nLI\n wh 10113\n\n' \
		>>"${dir}/lib/ship"
	if [ "${name}" = attack ]; then
		printf '1000 char 0\nna Raider\nah 61102\nLI\n wh 10113\nCH\n lo 200\n he 100\n at 60\n df 60\n\n' \
			>>"${dir}/lib/fact/200"
		printf '1001 char 0\nna Rafter\nLI\n wh 61102\nCH\n lo 100\n he 100\n at 60\n df 60\n\n' \
			>>"${dir}/lib/fact/100"
		args=(-r -l ./lib -S test-use-const-report-date)
	else
		args=(-l ./lib -S)
	fi

	( cd "${dir}" && "${BIN}" "${args[@]}" </dev/null >"${dir}/out" 2>"${dir}/err" )
	ec=$?
	if [ "${ec}" -ne 0 ]; then
		echo "NO  (${name}: exited ${ec}, want 0)"
		tail -n 2 "${dir}/err"
		fail=1
		continue
	fi
	if grep -q "AddressSanitizer\|runtime error" "${dir}/err"; then
		echo "NO  (${name}: sanitizer report on stderr)"
		grep -m 3 "AddressSanitizer\|runtime error" "${dir}/err"
		fail=1
	fi
	for want in '61102 ship raft' '61103 ship raft-in-progress'; do
		if ! grep -qx "${want}" "${dir}/lib/ship"; then
			echo "NO  (${name}: the saved lib/ship has no '${want}')"
			fail=1
		fi
	done
	[ "${name}" = attack ] || continue
	if ! grep -q '^1000:.*:> \[auto-attack c102\]$' "${dir}/lib/save/1/200"; then
		echo "NO  (${name}: unit 1000 did not auto-attack the raft)"
		fail=1
	fi
	if ! grep -q ':Combat between Raider~\[1000\] and Raft~\[c102\] on day 1$' "${dir}/lib/save/1/210"; then
		echo "NO  (${name}: no combat with the raft in the combat log)"
		fail=1
	fi
done
if [ "${fail}" -eq 0 ]; then
	echo "YES"
	exit 0
fi
exit 1
