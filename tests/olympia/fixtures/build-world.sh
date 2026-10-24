#!/bin/bash
###########################################################################
# Regenerate world.tgz, the shared base world for regress fixtures (#121).
#
# This is a ONE-TIME authoring tool, NOT run by any check. Starting from the
# bare map (lib.tgz) it runs world init only -- `-s` (start locations, which
# also bakes the one-time world init) and `-a` with no players -- and freezes
# the result. Each one-turn fixture under tests/olympia/regress/ commits only
# its scenario.patch against this world (see scenario.sh).
#
# Re-baselining this file (after a world-init change, like the #25
# worldgen/mint re-baselines) invalidates every scenario.patch at once: re-run
# each fixture's build-scenario.sh afterwards. Their check.sh fails with
# "does not apply to world.tgz" until then.
#
# Usage:  ./build-world.sh      (writes ./world.tgz)
###########################################################################
set -eu
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../../.." && pwd)"
PRESET="${OLYMPIA_PRESET:-debug}"
BIN="${ROOT}/build/${PRESET}/olympia-g3"

[ -x "${BIN}" ] || { echo "error: missing ${BIN} (build the ${PRESET} preset first)"; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
cd "${WORK}"

tar zxf "${HERE}/lib.tgz"
rm -f lib/master
"${BIN}" -l ./lib -s </dev/null >/dev/null 2>&1
"${BIN}" -l ./lib -a -S </dev/null >/dev/null 2>&1

tar czf "${HERE}/world.tgz" lib
echo "wrote ${HERE}/world.tgz"
