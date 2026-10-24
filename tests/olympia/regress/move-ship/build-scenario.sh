#!/bin/bash
###########################################################################
# Regenerate scenario.tgz for the move-ship fixture (issue #117).
#
# This is a ONE-TIME authoring tool, NOT run by check.sh. Starting from the
# bare-map fixture (tests/olympia/fixtures) it builds two regular factions in
# the port city Greyfell (57081), peasants removed:
#   300 "Ferry Line"  Captain One: knows Shipcraft (600) + Sailing (601),
#                     carries 8 sailors (a roundship's full crew), and is the
#                     captain of a new roundship made in Greyfell;
#   301 "Travellers"  Passenger One, on the dock.
#
# The measured turn runs a one-passenger ferry trip:
#   captain:   fee 1, ferry, wait time 1, sail east, sail west, unload
#   passenger: wait ferry <ship>, board <ship>
# i.e. set a boarding fee, sound the horn, let the passenger board, sail to
# Ocean [bs52] and back to Greyfell, and put the passenger ashore. check.sh
# asserts that board, unload, ferry, sail (and fee) each reach `ok`.
#
# Usage:  ./build-scenario.sh      (writes ./scenario.tgz)
###########################################################################
set -eu
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../../../.." && pwd)"
PRESET="${OLYMPIA_PRESET:-debug}"
BIN="${ROOT}/build/${PRESET}/olympia-g3"
SEED_LIB="${ROOT}/tests/olympia/fixtures/lib.tgz"

PEASANT=10		# item: peasants (every new noble starts with 25)
SAILOR=19		# item: sailors
SHIPCRAFT=600		# skill: Shipcraft (category)
SAILING=601		# skill: Sailing (sk_pilot_ship, required to sail)

[ -x "${BIN}" ] || { echo "error: missing ${BIN} (build the ${PRESET} preset first)"; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
cd "${WORK}"

tar zxf "${SEED_LIB}"
rm -f lib/master
"${BIN}" -l ./lib -s </dev/null >/dev/null 2>&1

# Join-g3: faction name, noble name, start-city index (0 = Greyfell), full name, email
join_faction() {	# args: id faction noble
	mkdir -p "act/$1"
	printf '%s\n%s\n0\nP Word Here\nplayer%s@example.com\n' "$2" "$3" "$1" > "act/$1/Join-g3"
}
join_faction 300 "Ferry Line" "Captain One"
join_faction 301 "Travellers" "Passenger One"
"${BIN}" -l ./lib -a -S </dev/null >/dev/null 2>&1

noble_of() { awk '/^ un /{print $2; exit}' "lib/fact/$1"; }
CAP="$(noble_of 300)"; PAS="$(noble_of 301)"
[ -n "${CAP}" ] && [ -n "${PAS}" ] || { echo "error: could not find minted nobles"; exit 2; }

# crew the captain and build the roundship where the captain stands (Greyfell)
printf 'be %s\nknow %s\nknow %s\nsubitem %s 25\nadditem %s 8\nmakeloc roundship\nbe %s\nsubitem %s 25\nsave\n' \
	"${CAP}" "${SHIPCRAFT}" "${SAILING}" "${PEASANT}" "${SAILOR}" \
	"${PAS}" "${PEASANT}" \
	| "${BIN}" -l ./lib -i >/dev/null 2>&1

# the bare map has no ships, so this is ours
SHIP="$(awk '$2 == "ship" && $3 == "roundship" {print $1; exit}' lib/ship)"
[ -n "${SHIP}" ] || { echo "error: makeloc did not create a roundship"; exit 2; }

# the first character inside a ship is its captain
printf 'be %s\npoof %s\nsave\n' "${CAP}" "${SHIP}" | "${BIN}" -l ./lib -i >/dev/null 2>&1

mkdir -p lib/orders
printf '%s:%s\n' "${CAP}" "fee 1" "${CAP}" ferry "${CAP}" "wait time 1" \
	"${CAP}" "sail east" "${CAP}" "sail west" "${CAP}" unload > lib/orders/300
printf '%s:%s\n' "${PAS}" "wait ferry ${SHIP}" "${PAS}" "board ${SHIP}" > lib/orders/301

tar czf "${HERE}/scenario.tgz" lib
echo "wrote ${HERE}/scenario.tgz  (captain=${CAP} passenger=${PAS} ship=${SHIP})"
