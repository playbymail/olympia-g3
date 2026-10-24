#!/bin/bash
###########################################################################
# Regenerate scenario.tgz for the move-land fixture (issue #117).
#
# This is a ONE-TIME authoring tool, NOT run by check.sh. Starting from the
# bare-map fixture (tests/olympia/fixtures) it builds three regular factions,
# each with one noble (peasants removed), all in the Forest province 13451
# [bs51] that holds the port city Greyfell (57081):
#   300 "Long Walkers"  Walker One   enter, exit, s, north, west, east
#   301 "Short Walkers" Walker Two   in, out, south, n, w, e   (the aliases)
#   302 "Sky Riders"    Rider One    fly south, fly north      (1 winged horse)
#
# The walkers loop Greyfell -> Forest -> Plain 13551 [bt51] -> Forest ->
# Plain 13450 [bs50] -> Forest (1+1+7+7+7+7 = 30 days); the rider flies to
# Plain 13551 and back. Every order starts within the month, so every verb
# reaches its `ok` outcome (check.sh asserts it from the coverage dump).
#
# Usage:  ./build-scenario.sh      (writes ./scenario.tgz)
###########################################################################
set -eu
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../../../.." && pwd)"
PRESET="${OLYMPIA_PRESET:-debug}"
BIN="${ROOT}/build/${PRESET}/olympia-g3"
SEED_LIB="${ROOT}/tests/olympia/fixtures/lib.tgz"

FOREST=13451		# Forest [bs51], outer province of Greyfell
PEASANT=10		# item: peasants (every new noble starts with 25)
WINGED_HORSE=54		# item: winged horse (fly capacity 150)

[ -x "${BIN}" ] || { echo "error: missing ${BIN} (build the ${PRESET} preset first)"; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
cd "${WORK}"

tar zxf "${SEED_LIB}"
rm -f lib/master
"${BIN}" -l ./lib -s </dev/null >/dev/null 2>&1

# Join-g3: faction name, noble name, start-city index, full name, email
join_faction() {	# args: id faction noble
	mkdir -p "act/$1"
	printf '%s\n%s\n0\nP Word Here\nplayer%s@example.com\n' "$2" "$3" "$1" > "act/$1/Join-g3"
}
join_faction 300 "Long Walkers" "Walker One"
join_faction 301 "Short Walkers" "Walker Two"
join_faction 302 "Sky Riders" "Rider One"
"${BIN}" -l ./lib -a -S </dev/null >/dev/null 2>&1

noble_of() { awk '/^ un /{print $2; exit}' "lib/fact/$1"; }
W1="$(noble_of 300)"; W2="$(noble_of 301)"; R1="$(noble_of 302)"
[ -n "${W1}" ] && [ -n "${W2}" ] && [ -n "${R1}" ] || { echo "error: could not find minted nobles"; exit 2; }

printf 'be %s\npoof %s\nsubitem %s 25\nbe %s\npoof %s\nsubitem %s 25\nbe %s\npoof %s\nsubitem %s 25\nadditem %s 1\nsave\n' \
	"${W1}" "${FOREST}" "${PEASANT}" \
	"${W2}" "${FOREST}" "${PEASANT}" \
	"${R1}" "${FOREST}" "${PEASANT}" "${WINGED_HORSE}" \
	| "${BIN}" -l ./lib -i >/dev/null 2>&1

mkdir -p lib/orders
printf '%s:%s\n' "${W1}" enter "${W1}" exit "${W1}" s "${W1}" north "${W1}" west "${W1}" east > lib/orders/300
printf '%s:%s\n' "${W2}" in "${W2}" out "${W2}" south "${W2}" n "${W2}" w "${W2}" e > lib/orders/301
printf '%s:%s\n' "${R1}" "fly south" "${R1}" "fly north" > lib/orders/302

tar czf "${HERE}/scenario.tgz" lib
echo "wrote ${HERE}/scenario.tgz  (walkers=${W1},${W2} rider=${R1} forest=${FOREST})"
