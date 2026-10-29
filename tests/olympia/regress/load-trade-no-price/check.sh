#!/bin/bash
###########################################################################
# Regression: a loaded trade with a positive quantity and no price is
# dropped at load (issue #358).
#
# trade_list_scan() (olympia/io.c) checked only the item, so it kept a
# `tl` entry such as `1 79 1 0 ...` (BUY 1 iron at 0). v_buy and v_sell
# refuse that ("No price given."), and the traders divide by the price:
# the market report's reduce_qty() (olympia/buy.c) computed has / 0
# (SIGFPE on amd64, exit 136; a UBSan report under asan-ubsan). Now the
# loader drops it, like an entry with a bad item, and says so on stderr.
#
# Each case unpacks the trade-market scenario (Greyfell, 57081), removes
# its orders, and adds one `tl` line to unit 4126 (fact/300) or 8651
# (fact/301). One turn runs.
#
# Four checks per case, all required:
#   1. the turn exits 0;
#   2. no AddressSanitizer or UBSan report on stderr;
#   3. stderr reports the dropped entry exactly once (no-price cases) or
#      never (controls);
#   4. the saved box keeps the priced control's entry and has no `tl`
#      line in the other cases.
#
# Date-independent via the `test-use-const-report-date` flag.
# Pass:  prints YES and exits 0.   No EXPECT files: nothing else is pinned.
###########################################################################
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../../../.." && pwd)"
. "${ROOT}/tests/olympia/engine.sh"
engine_no_update "$@"
. "${ROOT}/tests/olympia/fixtures/scenario.sh"
SCENARIO="${ROOT}/tests/olympia/regress/trade-market"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

# name|unit|box file|tl entry|dropped warnings|saved tl line (empty: none)
CASES=(
	'buy-no-price|4126|fact/300|1 79 1 0 0 0 0 0|1|'
	'sell-no-price|8651|fact/301|2 94 5 0 0 0 0 0|1|'
	'buy-priced|4126|fact/300|1 79 1 1 0 0 0 0|0|tl	1 79 1 1 0 0 0 0'
	'buy-cleared|4126|fact/300|1 79 0 0 0 0 0 0|0|'
)

fail=0
for c in "${CASES[@]}"; do
	IFS='|' read -r name unit box tl warn saved <<<"${c}"
	dir="${WORK}/${name}"
	mkdir "${dir}" && scenario_unpack "${SCENARIO}" "${dir}" || exit 2
	rm -f "${dir}/lib/orders/300" "${dir}/lib/orders/301"
	TL="${tl}" perl -0pi -e "s/(\n${unit} char 0\n.*?)(\nLI\n)/\$1\ntl\t\$ENV{TL}\$2/s" \
		"${dir}/lib/${box}"
	grep -q "^tl	${tl}\$" "${dir}/lib/${box}" || { echo "error: ${name}: tl not added to ${box}"; exit 2; }

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
	got="$(grep -c "trade_list_scan(${unit}): .* has no price" "${dir}/err")"
	if [ "${got}" -ne "${warn}" ]; then
		echo "NO  (${name}: ${got} no-price reports for unit ${unit}, want ${warn})"
		fail=1
	fi
	got="$(perl -0ne "print \$1 if /\n${unit} char 0\n(.*?)\n\n/s" "${dir}/lib/${box}" | grep '^tl')"
	if [ "${got}" != "${saved}" ]; then
		echo "NO  (${name}: saved ${box} has tl '${got}', want '${saved}')"
		fail=1
	fi
done
if [ "${fail}" -eq 0 ]; then
	echo "YES"
	exit 0
fi
exit 1
