#!/bin/bash
###########################################################################
# Regenerate scenario.tgz for the stop-running fixture (issue #361).
#
# This is a ONE-TIME authoring tool, NOT run by check.sh. A STOP interrupts
# only an order an earlier turn left running, so the scenario has a real
# turn behind it. Starting from the bare-map fixture (tests/olympia/fixtures)
# it:
#   1. runs stop-running.lua with olyscript-g3, which sets up units whose
#      orders outlast the month and writes their ids to ids.lua;
#   2. runs turn 1 with olympia-g3;
#   3. runs stop-running-stop.lua, which queues the STOP orders;
#   4. freezes that lib as scenario.tgz.
#
# A month of play changes most of lib/loc, so a scenario.patch over the
# shared base world would be about 3 MB of text; the lib is frozen whole, as
# trade-routes' is. Turn 1's reports (lib/save) and logs (lib/log) are not
# turn input, so they are left out.
#
# Usage:  ./build-scenario.sh      (writes ./scenario.tgz)
###########################################################################
set -eu
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../../../.." && pwd)"
PRESET="${OLYMPIA_PRESET:-debug}"
SCRIPT_BIN="${ROOT}/build/${PRESET}/olyscript-g3"
BIN="${ROOT}/build/${PRESET}/olympia-g3"
SEED_LIB="${ROOT}/tests/olympia/fixtures/lib.tgz"

[ -x "${SCRIPT_BIN}" ] || { echo "error: missing ${SCRIPT_BIN} (build the ${PRESET} preset first)"; exit 2; }
[ -x "${BIN}" ] || { echo "error: missing ${BIN} (build the ${PRESET} preset first)"; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
cd "${WORK}"

tar zxf "${SEED_LIB}"
rm -f lib/master
"${SCRIPT_BIN}" "${HERE}/stop-running.lua" > script.log 2>&1 || { cat script.log; exit 2; }

"${BIN}" -r -l ./lib -S test-use-const-report-date </dev/null >turn.log 2>&1 || { tail turn.log; exit 2; }

"${SCRIPT_BIN}" "${HERE}/stop-running-stop.lua" > script.log 2>&1 || { cat script.log; exit 2; }

rm -rf lib/save lib/log

tar czf "${HERE}/scenario.tgz" lib
echo "wrote ${HERE}/scenario.tgz  ($(tail -1 script.log))"
