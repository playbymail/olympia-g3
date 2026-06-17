#!/bin/bash
############################################################################
#
# Drive genesis-g3: generate a fresh mapgen input set (Map, Regions, Land,
# Cities, randseed) into this run folder.  Unlike run/mapgen/mapgen.sh, genesis
# takes no fixtures -- it CREATES the inputs -- so any extra arguments are passed
# straight through to genesis-g3:
#
#   ./run/genesis/genesis.sh                                  # defaults (99/9/10)
#   ./run/genesis/genesis.sh --seed 12345 --size 50          # custom world
#
# The output is upstream of mapgen: feed it forward with, e.g.
#   cp -p run/genesis/{Cities,Land,Map,Regions,randseed} run/mapgen/ && \
#     (cd run/mapgen && "${OLYMPIA_BIN}/mapgen-g3")
#
# Resolve the repo root from this script's location so the repo is relocatable.
OLYMPIA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# CMakePresets emits binaries to build/<presetName> (default preset: debug).
OLYMPIA_PRESET="${OLYMPIA_PRESET:-debug}"
OLYMPIA_BIN="${OLYMPIA_ROOT}/build/${OLYMPIA_PRESET}"
OLYMPIA_RUN="${OLYMPIA_ROOT}/run"
OLYMPIA_ENGINE=g3
OLYMPIA_COMMAND=genesis
############################################################################
# verify some paths
[ -d "${OLYMPIA_ROOT}" ] || {
  echo "OLYMPIA_ROOT       == '${OLYMPIA_ROOT}'"
  echo "error: invalid OLYMPIA_ROOT"
  exit 2
}
[ -d "${OLYMPIA_BIN}" ] || {
  echo "OLYMPIA_ROOT       == '${OLYMPIA_ROOT}'"
  echo "OLYMPIA_BIN        == '${OLYMPIA_BIN}'"
  echo "error: invalid OLYMPIA_BIN"
  exit 2
}
[ -d "${OLYMPIA_RUN}" ] || {
  echo "OLYMPIA_ROOT       == '${OLYMPIA_ROOT}'"
  echo "OLYMPIA_RUN        == '${OLYMPIA_RUN}'"
  echo "error: invalid OLYMPIA_RUN"
  exit 2
}
OLYMPIA_OUTPUTS="${OLYMPIA_RUN}/${OLYMPIA_COMMAND}"
[ -d "${OLYMPIA_OUTPUTS}" ] || {
  echo "OLYMPIA_RUN        == '${OLYMPIA_RUN}'"
  echo "OLYMPIA_ENGINE     == '${OLYMPIA_ENGINE}'"
  echo "OLYMPIA_COMMAND    == '${OLYMPIA_COMMAND}'"
  echo "error: invalid run path"
  exit 2
}
############################################################################
#
cd "${OLYMPIA_OUTPUTS}" || {
  echo "error: unable to set def to run path"
  echo "OLYMPIA_RUN        == '${OLYMPIA_RUN}'"
  echo "OLYMPIA_ENGINE     == '${OLYMPIA_ENGINE}'"
  echo "OLYMPIA_COMMAND    == '${OLYMPIA_COMMAND}'"
  exit 2
}

############################################################################
#
echo " info: running ${OLYMPIA_COMMAND}-${OLYMPIA_ENGINE} in $( pwd )"

# run the program
#   inputs: none (genesis creates the world from --seed)
#  outputs: Map, Regions, Land, Cities, randseed
"${OLYMPIA_BIN}/${OLYMPIA_COMMAND}-${OLYMPIA_ENGINE}" "$@" || {
  echo "error: ${OLYMPIA_COMMAND}-${OLYMPIA_ENGINE} failed"
  exit 2
}

ls -l Cities Land Map Regions randseed

exit 0
