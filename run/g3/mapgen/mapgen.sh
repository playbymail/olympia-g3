#!/bin/bash
############################################################################
#
# Resolve the repo root from this script's location so the repo is relocatable.
OLYMPIA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# CMakePresets emits binaries to build/<presetName> (default preset: debug).
OLYMPIA_PRESET="${OLYMPIA_PRESET:-debug}"
OLYMPIA_BIN="${OLYMPIA_ROOT}/build/${OLYMPIA_PRESET}"
OLYMPIA_FIXTURES="${OLYMPIA_ROOT}/tests"
OLYMPIA_RUN="${OLYMPIA_ROOT}/run"
OLYMPIA_ENGINE=g3
OLYMPIA_COMMAND=mapgen
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
[ -d "${OLYMPIA_FIXTURES}" ] || {
  echo "OLYMPIA_ROOT       == '${OLYMPIA_ROOT}'"
  echo "OLYMPIA_FIXTURES   == '${OLYMPIA_OLYMPIA_FIXTURES}'"
  echo "error: invalid OLYMPIA_FIXTURES"
  exit 2
}
OLYMPIA_INPUTS="${OLYMPIA_FIXTURES}/${OLYMPIA_ENGINE}/${OLYMPIA_COMMAND}/fixtures"
[ -d "${OLYMPIA_INPUTS}" ] || {
  echo "OLYMPIA_FIXTURES   == '${OLYMPIA_OLYMPIA_FIXTURES}'"
  echo "OLYMPIA_ENGINE     == '${OLYMPIA_ENGINE}'"
  echo "OLYMPIA_COMMAND    == '${OLYMPIA_COMMAND}'"
  echo "error: invalid fixtures path"
  exit 2
}
[ -d "${OLYMPIA_RUN}" ] || {
  echo "OLYMPIA_ROOT       == '${OLYMPIA_ROOT}'"
  echo "OLYMPIA_RUN        == '${OLYMPIA_RUN}'"
  echo "error: invalid OLYMPIA_RUN"
  exit 2
}
OLYMPIA_OUTPUTS="${OLYMPIA_RUN}/${OLYMPIA_ENGINE}/${OLYMPIA_COMMAND}"
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
# copy the test fixtures to the run folder
echo " info: copying inputs to $( pwd )"
cp -p "${OLYMPIA_INPUTS}/"{Cities,Land,Map,Regions,randseed} . || {
  echo "error: unable to copy fixtures"
  exit 2
}
ls -l Cities Land Map Regions randseed

############################################################################
#
echo " info: running ${OLYMPIA_ENGINE}-${OLYMPIA_COMMAND} in $( pwd )"

# run the program
#   inputs: Cities, Land, Map, Regions, randseed
#  outputs: gate, loc, road
"${OLYMPIA_BIN}/${OLYMPIA_ENGINE}-${OLYMPIA_COMMAND}" || {
  echo "error: ${OLYMPIA_ENGINE}-${OLYMPIA_COMMAND} failed"
  exit 2
}

ls -l gate loc road randseed

exit 0
