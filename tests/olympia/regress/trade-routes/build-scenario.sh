#!/bin/bash
###########################################################################
# Regenerate scenario.tgz for the trade-routes buyer-secret regression
# test (issue #46).
#
# This is a ONE-TIME authoring tool, NOT run by check.sh. It drives the
# engine's own bootstrap to build a tiny, valid game whose pending turn
# exercises d_find_buy()'s per-game buyer secret, then freezes the pre-turn
# library as scenario.tgz.
#
# What it builds, starting from the bare-map fixture (tests/olympia/fixtures):
#   - one-time world init is run and baked (seed_has_been_run saved);
#   - one regular faction is minted via the add-player path (-a):
#       400 "Trade Test" (noble "Trader One")
#   - the noble learns Trade(730) + Find-tradegood-for-sale(732) +
#     Find-market-for-tradegood(733);
#   - SETUP TURN: the noble, poofed into the source city Areth Pirn (57019),
#     runs `use 732` (FIND SELL). This mints exactly one tradegood (myrrh) and
#     adds a PRODUCE trade record for it in 57019 -- the only sub_tradegood the
#     bare map has, so its id is parsed back out of lib/item;
#   - the noble is then poofed into the buyer city Greyfell (57081), >= 8
#     provinces from the source (the distance d_find_buy requires), and handed
#     5 of the tradegood;
#   - PENDING ORDER (the measured turn): `use 733 <tradegood>` (FIND BUY).
#
# Running the measured turn drives v_find_buy -> d_find_buy, whose 50%% buyer
# test is `md5_int(city_sold, where, item, SECRET) & 1` where SECRET is the
# per-game trade-route secret (issue #46). With the default secret (0xb05c0e)
# Greyfell IS a buyer; with `-G 1` it is NOT -- check.sh pins both.
#
# Date-independent via the `test-use-const-report-date` flag.
#
# Usage:  ./build-scenario.sh      (writes ./scenario.tgz)
###########################################################################
set -eu
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../../../.." && pwd)"
PRESET="${OLYMPIA_PRESET:-debug}"
BIN="${ROOT}/build/${PRESET}/olympia-g3"
SEED_LIB="${ROOT}/tests/olympia/fixtures/lib.tgz"

SRC_CITY=57019		# Areth Pirn  -- produces the tradegood (city_sold)
BUY_CITY=57081		# Greyfell    -- the buyer city under test (where), >= 8 away

[ -x "${BIN}" ] || { echo "error: missing ${BIN} (build the ${PRESET} preset first)"; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
cd "${WORK}"

tar zxf "${SEED_LIB}"
rm -f lib/master

# startloc (also bakes the one-time world init on this first load)
"${BIN}" -l ./lib -s </dev/null >/dev/null 2>&1

# one faction, one starting noble (start-city index 0)
mkdir -p act/400
printf 'Trade Test\nTrader One\n0\nP Word Here\ntrader@example.com\n' > act/400/Join-g3
"${BIN}" -l ./lib -a -S </dev/null >/dev/null 2>&1

# discover the minted noble id (the single unit under the new faction)
NOB="$(awk '/^ un /{print $2; exit}' lib/fact/400)"
[ -n "${NOB}" ] || { echo "error: could not find minted noble"; exit 2; }

# learn the trade skills, place in the source city
printf 'be %s\nknow 730\nknow 732\nknow 733\npoof %s\nsave\n' \
	"${NOB}" "${SRC_CITY}" | "${BIN}" -l ./lib -i >/dev/null 2>&1

# SETUP TURN: FIND SELL mints the tradegood + its PRODUCE record in SRC_CITY
mkdir -p lib/orders
printf '%s:use 732\n' "${NOB}" > lib/orders/400
"${BIN}" -r -l ./lib -S test-use-const-report-date </dev/null >/dev/null 2>&1

# the bare map has no other sub_tradegood, so this is our minted good
TG="$(grep -oE '^[0-9]+ item tradegood' lib/item | head -1 | awk '{print $1}')"
[ -n "${TG}" ] || { echo "error: FIND SELL did not mint a tradegood"; exit 2; }

# move to the far buyer city, hand over the tradegood, queue FIND BUY
printf 'be %s\npoof %s\nadditem %s 5\nsave\n' \
	"${NOB}" "${BUY_CITY}" "${TG}" | "${BIN}" -l ./lib -i >/dev/null 2>&1
printf '%s:use 733 %s\n' "${NOB}" "${TG}" > lib/orders/400

# freeze the pre-(measured-)turn world
tar czf "${HERE}/scenario.tgz" lib
echo "wrote ${HERE}/scenario.tgz  (noble=${NOB} tradegood=${TG} source=${SRC_CITY} buyer=${BUY_CITY})"

# self-check: the default secret must make BUY_CITY a buyer
CHK="$(mktemp -d)"; tar zxf "${HERE}/scenario.tgz" -C "${CHK}"
( cd "${CHK}" && "${BIN}" -r -l ./lib -S test-use-const-report-date </dev/null >/dev/null 2>&1 )
TURN="$(ls "${CHK}/lib/save" | sort -n | tail -1)"
if grep -q "buys myrrh" "${CHK}/lib/save/${TURN}/400"; then
	echo "self-check: default secret -> buyer found (ok)"
else
	echo "self-check FAILED: default secret did not yield a buyer"; rm -rf "${CHK}"; exit 2
fi
rm -rf "${CHK}"
