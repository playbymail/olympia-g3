#!/bin/bash
###########################################################################
# Regression: trade-route buyer secret in d_find_buy() (issue #46).
#
# Extracts the frozen scenario (scenario.tgz) and runs the pending FIND BUY
# turn under three RNG secrets. The noble (Trader One, faction 400) stands in
# the buyer city Greyfell holding a tradegood (myrrh) that the source city
# Areth Pirn produces, and issues `use 733 <good>` (FIND BUY). That drives
#     v_find_buy -> d_find_buy
# whose 50%% buyer test is `md5_int(city_sold, where, item, SECRET) & 1`, where
# SECRET is the per-game trade-route secret introduced in #46.
#
# Three runs pin the secret's effect on the noble's report:
#   1. default secret (0xb05c0e)  -> Greyfell IS a buyer            (EXPECT.sha256)
#   2. -G 1                        -> Greyfell is NOT a buyer (EXPECT-seeded.sha256)
#   3. -G 1 again                  -> byte-identical to run 2  (determinism)
# and the two pinned hashes must differ (the secret actually changes the buyer
# set) -- a regression in the secret derivation, the persistence, or the md5
# keying is caught here, in this subsystem's own small golden tree.
#
# The secret is turn-INDEPENDENT by design (a buyer must stay a buyer next
# turn); see olympia/buy.c and doc/rng-state-granularity.md. This fixture
# additionally checks the seed-persistence side effect: lib/trade_routes is
# written (with the seed) under -G and absent under the default.
#
# Date-independent via the `test-use-const-report-date` flag.
# Pass:  prints YES and exits 0.   Re-baseline: ./check.sh --update
###########################################################################
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../../../.." && pwd)"
PRESET="${OLYMPIA_PRESET:-debug}"
BIN="${ROOT}/build/${PRESET}/olympia-g3"

[ -x "${BIN}" ] || { echo "error: missing ${BIN} (build the ${PRESET} preset first)"; exit 2; }
[ -f "${HERE}/scenario.tgz" ] || { echo "error: missing scenario.tgz (run ./build-scenario.sh)"; exit 2; }

# Run the measured turn on a fresh extraction with the given extra flags and
# print a sha256 of the noble's report (the FIND BUY verdict + resulting
# routes), or "TURNFAIL" on a non-zero engine exit.
report_hash() {		# args: extra olympia flags...
	local W rc TURN
	W="$(mktemp -d)"
	tar zxf "${HERE}/scenario.tgz" -C "${W}" || { rm -rf "${W}"; echo "TURNFAIL"; return; }
	( cd "${W}" && "${BIN}" -r -l ./lib "$@" -S test-use-const-report-date </dev/null >/dev/null 2>&1 )
	rc=$?
	if [ "${rc}" -ne 0 ]; then rm -rf "${W}"; echo "TURNFAIL"; return; fi
	TURN="$(ls "${W}/lib/save" | sort -n | tail -1)"
	shasum -a 256 < "${W}/lib/save/${TURN}/400" | awk '{print $1}'
	rm -rf "${W}"
}

# Run the measured turn and print the persisted per-game seed, or "(none)".
routes_file() {		# args: extra olympia flags...
	local W
	W="$(mktemp -d)"
	tar zxf "${HERE}/scenario.tgz" -C "${W}" >/dev/null 2>&1
	( cd "${W}" && "${BIN}" -r -l ./lib "$@" -S test-use-const-report-date </dev/null >/dev/null 2>&1 )
	if [ -f "${W}/lib/trade_routes" ]; then cat "${W}/lib/trade_routes"; else echo "(none)"; fi
	rm -rf "${W}"
}

H_DEFAULT="$(report_hash)"
H_SEEDED="$(report_hash -G 1)"
H_SEEDED2="$(report_hash -G 1)"
RF_DEFAULT="$(routes_file)"
RF_SEEDED="$(routes_file -G 1)"

if [ "${1:-}" = "--update" ]; then
	printf '%s\n' "${H_DEFAULT}" > "${HERE}/EXPECT.sha256"
	printf '%s\n' "${H_SEEDED}"  > "${HERE}/EXPECT-seeded.sha256"
	echo "updated EXPECT.sha256 (default) and EXPECT-seeded.sha256 (-G 1)"
	exit 0
fi

EXP_DEFAULT="$(cat "${HERE}/EXPECT.sha256" 2>/dev/null)"
EXP_SEEDED="$(cat "${HERE}/EXPECT-seeded.sha256" 2>/dev/null)"

fail=0
[ "${H_DEFAULT}" = "${EXP_DEFAULT}" ] || { echo "NO  (default-secret report changed vs EXPECT.sha256)"; fail=1; }
[ "${H_SEEDED}"  = "${EXP_SEEDED}"  ] || { echo "NO  (-G 1 report changed vs EXPECT-seeded.sha256)"; fail=1; }
[ "${H_SEEDED}"  = "${H_SEEDED2}"   ] || { echo "NO  (-G 1 not deterministic across runs)"; fail=1; }
[ "${H_DEFAULT}" != "${H_SEEDED}"   ] || { echo "NO  (the secret did not change the buyer verdict)"; fail=1; }
[ "${RF_DEFAULT}" = "(none)" ]        || { echo "NO  (default flow wrote lib/trade_routes: '${RF_DEFAULT}')"; fail=1; }
[ "${RF_SEEDED}"  = "1" ]             || { echo "NO  (-G 1 did not persist seed 1 to lib/trade_routes: '${RF_SEEDED}')"; fail=1; }

if [ "${fail}" -eq 0 ]; then
	echo "YES"
	exit 0
fi
exit 1
