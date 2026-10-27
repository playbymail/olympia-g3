#!/bin/bash
###########################################################################
# Regression: a stray file in lib/orders (issue #332).
#
# load_orders() (olympia/order.c) loads lib/orders/<name> for every name
# starting with a digit, as player atoi(name). load_player_orders() then
# asserted that the player had a player section and no orders yet:
#   - a file named after a box that is not a player (orders/10101, a
#     province) dereferenced a NULL rp_player() (SIGSEGV, exit 139);
#   - two names atoi() reads as the same player (orders/206 and
#     orders/206.bak) failed `orders == NULL` on the second (exit 134).
# Now load_orders() reports each one and skips it.
#
# Each case extracts the shared base world, writes the order files, then
# loads and saves the DB (-S, no -r). Directory order is up to the file
# system, so the checks count reports instead of naming the file.
#
# Four checks per case, all required:
#   1. the run exits 0 (before the fix: 139 or 134);
#   2. no AddressSanitizer or UBSan report on stderr;
#   3. stderr has the wanted number of each report;
#   4. the saved lib/orders holds exactly the wanted files and lines: the
#      queued orders for player 206 once, nothing for 10101.
#
# Pass:  prints YES and exits 0.   No EXPECT files: the checks are inline.
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

ORDER='1009:wait 1'

# name|order files written|not-a-player reports|already-loaded reports|saved orders files
CASES=(
	'not-player|10101|1|0|'
	'backup|206 206.bak|0|1|206'
	'both|10101 206 206.bak|1|1|206'
)

fail=0
for c in "${CASES[@]}"; do
	IFS='|' read -r name files want_np want_dup want_saved <<<"${c}"
	dir="${WORK}/${name}"
	mkdir "${dir}" && tar zxf "${WORLD}" -C "${dir}" || exit 2
	for f in ${files}; do
		printf '%s\n' "${ORDER}" >"${dir}/lib/orders/${f}" || exit 2
	done

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
	got="$(grep -c '^ERROR: orders/10101 but \[10101\] is not a player$' "${dir}/err")"
	if [ "${got}" -ne "${want_np}" ]; then
		echo "NO  (${name}: ${got} not-a-player reports, want ${want_np})"
		fail=1
	fi
	got="$(grep -c '^ERROR: orders/206[.bak]* but orders for \[206\] are already loaded$' "${dir}/err")"
	if [ "${got}" -ne "${want_dup}" ]; then
		echo "NO  (${name}: ${got} already-loaded reports, want ${want_dup})"
		fail=1
	fi
	got="$(cd "${dir}/lib/orders" && ls | tr '\n' ' ' | sed 's/ $//')"
	if [ "${got}" != "${want_saved}" ]; then
		echo "NO  (${name}: saved lib/orders holds '${got}', want '${want_saved}')"
		fail=1
	fi
	for f in ${want_saved}; do
		if [ "$(cat "${dir}/lib/orders/${f}")" != "${ORDER}" ]; then
			echo "NO  (${name}: saved lib/orders/${f} is not the one order)"
			fail=1
		fi
	done
done
if [ "${fail}" -eq 0 ]; then
	echo "YES"
	exit 0
fi
exit 1
