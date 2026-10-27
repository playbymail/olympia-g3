#!/bin/bash
###########################################################################
# Regression: a raft sails with no crew, never pays a short-handed
# penalty, and gets no wind bonus (issue #350).
#
# move_exit_water() and check_captain_loses_sailors() (olympia/move.c)
# switched on the ship's subkind with cases only for roundship and galley,
# and failed assert(FALSE) for a raft (exit 134). Now a raft needs no crew:
# move_exit_water() adds no days for missing hands, and
# check_captain_loses_sailors() returns at once. The wind bonus was already
# roundship-only.
#
# Each case extracts the shared base world, drops lib/master, and puts a
# ship at plain 10113 (10013, to its north, is ocean) with captain 1001
# (player 200, Sailing 601) aboard. One turn runs.
#
#   sail       raft, no sailors. 1001 sails north, then south.
#   lose       raft, 9 sailors. 1001 sails north; deckhand 1002 aboard
#              waits a day, then takes 2 sailors mid-voyage
#              (check_captain_loses_sailors).
#   lose-ship  the control: the lose case on a roundship. It pays the
#              penalty, which shows the case reaches that path.
#
# Checks, all required:
#   1. the turn exits 0 (before the fix: 134 for the raft cases);
#   2. no AddressSanitizer or UBSan report on stderr;
#   3. the report lines below each appear exactly once in lib/save/1/200,
#      and the forbidden lines not at all.
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

CAPTAIN=' sl\t601 2 0 0 0\n'
DECKHAND='1002 char 0\nna Deckhand\nLI\n wh 61102\nCH\n lo 200\n he 100\n at 60\n df 60\n\n'

# case|ship subkind|captain's sailors|deckhand (y/n)|orders (; separated)
CASES=(
	'sail|raft|0|n|1001:sail north;1001:sail south'
	'lose|raft|9|y|1001:sail north;1002:wait time 1;1002:get 1001 19 2'
	'lose-ship|roundship|9|y|1001:sail north;1002:wait time 1;1002:get 1001 19 2'
)

# case|count|line -- the report line (after "<unit>:0::0:<day>:") in
# lib/save/1/200 must appear exactly count times
LINES=(
	'sail|1|1001:0::0:1:Sailing to Ocean~[aa13] will take two days.'
	'sail|1|1001:0::0:2:Arrival at Ocean~[aa13].'
	'sail|1|1001:0::0:3:Sailing to Plain~[ab13] will take two days.'
	'sail|1|1001:0::0:4:Arrival at Plain~[ab13].'
	'lose|1|1001:0::0:1:Sailing to Ocean~[aa13] will take two days.'
	'lose|1|1002:0::0:2:Took two~sailors from Rafter~[1001].'
	'lose|1|1001:0::0:2:Arrival at Ocean~[aa13].'
	'lose|0|1001:0::0:2:Loss of crew will cause travel to take an extra day.'
	'lose-ship|1|1002:0::0:2:Took two~sailors from Rafter~[1001].'
	'lose-ship|1|1001:0::0:2:Loss of crew will cause travel to take an extra day.'
	'lose-ship|1|1001:0::0:3:Arrival at Ocean~[aa13].'
)

fail=0
for c in "${CASES[@]}"; do
	IFS='|' read -r name kind sailors deck orders <<<"${c}"
	dir="${WORK}/${name}"
	mkdir "${dir}" && tar zxf "${WORLD}" -C "${dir}" || exit 2
	rm -f "${dir}/lib/master"
	printf '61102 ship %s\nLI\n wh 10113\n\n' "${kind}" >>"${dir}/lib/ship"
	{
		printf '1001 char 0\nna Rafter\n'
		[ "${sailors}" -eq 0 ] || printf 'il\t19 %d\n' "${sailors}"
		printf 'LI\n wh 61102\nCH\n lo 200\n he 100\n'"${CAPTAIN}"' at 60\n df 60\n\n'
		[ "${deck}" = n ] || printf "${DECKHAND}"
	} >>"${dir}/lib/fact/200"
	tr ';' '\n' <<<"${orders}" >"${dir}/lib/orders/200"

	( cd "${dir}" && "${BIN}" -r -l ./lib -S test-use-const-report-date \
		</dev/null >"${dir}/out" 2>"${dir}/err" )
	ec=$?
	if [ "${ec}" -ne 0 ]; then
		echo "NO  (${name}: turn exited ${ec}, want 0)"
		tail -n 2 "${dir}/err"
		fail=1
		continue
	fi
	if grep -q "AddressSanitizer\|runtime error" "${dir}/err"; then
		echo "NO  (${name}: sanitizer report on stderr)"
		grep -m 3 "AddressSanitizer\|runtime error" "${dir}/err"
		fail=1
	fi
	for l in "${LINES[@]}"; do
		IFS='|' read -r lcase count want <<<"${l}"
		[ "${lcase}" = "${name}" ] || continue
		got="$(grep -cxF "${want}" "${dir}/lib/save/1/200")"
		if [ "${got}" -ne "${count}" ]; then
			echo "NO  (${name}: ${got} report lines '${want}', want ${count})"
			fail=1
		fi
	done
	if [ "${kind}" = raft ] && grep -q ':The crew of a ' "${dir}/lib/save/1/200"; then
		echo "NO  (${name}: the raft was told it is short of crew)"
		fail=1
	fi
done
if [ "${fail}" -eq 0 ]; then
	echo "YES"
	exit 0
fi
exit 1
