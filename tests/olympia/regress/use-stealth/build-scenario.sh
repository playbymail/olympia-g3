#!/bin/bash
###########################################################################
# Regenerate scenario.patch for the use-stealth fixture (issue #192).
#
# This is a ONE-TIME authoring tool, NOT run by check.sh. Starting from the
# bare-map fixture (tests/olympia/fixtures) it runs use-stealth.lua with
# olyscript-g3, which builds the scenario and saves the pre-turn lib, then
# freezes that lib as scenario.patch over the shared base world.
#
# Usage:  ./build-scenario.sh      (writes ./scenario.patch)
###########################################################################
set -eu
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../../../.." && pwd)"
PRESET="${OLYMPIA_PRESET:-debug}"
SCRIPT_BIN="${ROOT}/build/${PRESET}/olyscript-g3"
SEED_LIB="${ROOT}/tests/olympia/fixtures/lib.tgz"
SCRIPT="${HERE}/use-stealth.lua"
. "${ROOT}/tests/olympia/fixtures/scenario.sh"

[ -x "${SCRIPT_BIN}" ] || { echo "error: missing ${SCRIPT_BIN} (build the ${PRESET} preset first)"; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
cd "${WORK}"

tar zxf "${SEED_LIB}"
rm -f lib/master
"${SCRIPT_BIN}" "${SCRIPT}" > script.log 2>&1 || { cat script.log; exit 2; }

# The script never runs the -a pass, so lib/log still holds lib.tgz's logs.
# A turn deletes lib/log before it writes anything (open_logfile), so they are
# not turn input; take world.tgz's to keep them out of the patch.
rm -rf lib/log
tar zxf "${SCENARIO_WORLD}" lib/log

scenario_write "${WORK}" "${HERE}"
echo "wrote ${HERE}/scenario.patch  ($(tail -1 script.log))"
