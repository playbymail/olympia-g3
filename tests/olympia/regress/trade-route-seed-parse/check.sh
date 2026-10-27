#!/bin/bash
###########################################################################
# Regression: reading the trade-route seed (issue #338).
#
# init_trade_routes() (olympia/buy.c) read lib/trade_routes and
# lib/trade-route-seed with fscanf("%llu"). How far that reads a long
# token is up to the C library: for 512 or more zeros followed by 13,
# macOS read 1 or 0 where glibc read 13. Now read_trade_route_seed() reads
# the token as strtoull(s, NULL, 10) does, on every platform: leading
# whitespace, an optional sign, then decimal digits; a value past
# 2^64 - 1 is 2^64 - 1, and "-n" is 2^64 - n.
#
# Each case extracts the shared base world, writes one seed file, then
# loads and saves the DB (-S, no -r). save_trade_routes() writes the seed
# in effect back to lib/trade_routes as a plain decimal number.
#
# Three checks per case, all required:
#   1. the run exits 0;
#   2. no AddressSanitizer or UBSan report on stderr;
#   3. the saved lib/trade_routes is the wanted seed, or, for a file with
#      no digits, is left as it was (no seed is in effect, so none is saved).
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

# name|file under lib|perl printing its contents|wanted lib/trade_routes ('-': unchanged)
CASES=(
	'plain|trade_routes|print "13\n"|13'
	'zeros-511|trade_routes|print "0" x 511, "13\n"|13'
	'zeros-512|trade_routes|print "0" x 512, "13\n"|13'
	'zeros-600|trade_routes|print "0" x 600, "13\n"|13'
	'plus-zeros|trade_routes|print "+", "0" x 511, "13\n"|13'
	'whitespace|trade_routes|print " \n\t 42 trailing\n"|42'
	'max|trade_routes|print "18446744073709551615\n"|18446744073709551615'
	'overflow|trade_routes|print "18446744073709551616\n"|18446744073709551615'
	'overflow-long|trade_routes|print "9" x 600, "\n"|18446744073709551615'
	'negative|trade_routes|print "-1\n"|18446744073709551615'
	'negative-overflow|trade_routes|print "-18446744073709551616\n"|18446744073709551615'
	'hex|trade_routes|print "0x1f\n"|0'
	'no-digits|trade_routes|print "seed\n"|-'
	'input-zeros|trade-route-seed|print "0" x 600, "13\n"|13'
)

fail=0
for c in "${CASES[@]}"; do
	IFS='|' read -r name file text want <<<"${c}"
	dir="${WORK}/${name}"
	mkdir "${dir}" && tar zxf "${WORLD}" -C "${dir}" || exit 2
	if [ -e "${dir}/lib/trade_routes" ] || [ -e "${dir}/lib/trade-route-seed" ]; then
		echo "error: the base world already has a trade-route seed file"
		exit 2
	fi
	perl -e "${text}" >"${dir}/lib/${file}" || exit 2
	cp -p "${dir}/lib/${file}" "${WORK}/${name}.orig" || exit 2

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
	if [ "${want}" = "-" ]; then
		if ! cmp -s "${WORK}/${name}.orig" "${dir}/lib/trade_routes"; then
			echo "NO  (${name}: lib/trade_routes changed, want it left as it was)"
			fail=1
		fi
	elif [ "$(cat "${dir}/lib/trade_routes" 2>/dev/null)" != "${want}" ]; then
		echo "NO  (${name}: saved seed is '$(head -c 40 "${dir}/lib/trade_routes" 2>/dev/null)', want '${want}')"
		fail=1
	fi
done
if [ "${fail}" -eq 0 ]; then
	echo "YES"
	exit 0
fi
exit 1
