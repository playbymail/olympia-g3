#!/bin/bash
###########################################################################
# Regenerate scenario.tgz for the move-go fixture (issue #117).
#
# This is a ONE-TIME authoring tool, NOT run by check.sh. Starting from the
# bare-map fixture (tests/olympia/fixtures) it builds one regular faction,
# 300 "Go Walkers", whose noble Walker One (peasants removed) stands in the
# Forest province 13451 [bs51]. The measured turn exercises both forms of GO:
#   go south	by direction     -> Plain 13551 [bt51]  (7 days)
#   go 13451	by destination   -> Forest [bs51]       (8 days)
#   go 57081	into a sublocation by id -> Greyfell    (1 day)
#
# GO shares v_move with MOVE, whose `ok` the main golden turn already covers
# through NPC movement; this fixture pins GO itself through a player's order
# file. check.sh asserts it reaches `ok`.
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
GREYFELL=57081		# port city inside the Forest
PEASANT=10		# item: peasants (every new noble starts with 25)

[ -x "${BIN}" ] || { echo "error: missing ${BIN} (build the ${PRESET} preset first)"; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
cd "${WORK}"

tar zxf "${SEED_LIB}"
rm -f lib/master
"${BIN}" -l ./lib -s </dev/null >/dev/null 2>&1

# Join-g3: faction name, noble name, start-city index, full name, email
mkdir -p act/300
printf 'Go Walkers\nWalker One\n0\nP Word Here\nplayer300@example.com\n' > act/300/Join-g3
"${BIN}" -l ./lib -a -S </dev/null >/dev/null 2>&1

NOB="$(awk '/^ un /{print $2; exit}' lib/fact/300)"
[ -n "${NOB}" ] || { echo "error: could not find minted noble"; exit 2; }

printf 'be %s\npoof %s\nsubitem %s 25\nsave\n' "${NOB}" "${FOREST}" "${PEASANT}" \
	| "${BIN}" -l ./lib -i >/dev/null 2>&1

mkdir -p lib/orders
printf '%s:%s\n' "${NOB}" "go south" "${NOB}" "go ${FOREST}" "${NOB}" "go ${GREYFELL}" > lib/orders/300

tar czf "${HERE}/scenario.tgz" lib
echo "wrote ${HERE}/scenario.tgz  (noble=${NOB} forest=${FOREST} city=${GREYFELL})"
