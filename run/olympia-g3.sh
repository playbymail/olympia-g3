#!/bin/bash
############################################################################
# How olympia-g3 Runs
#   usage: olympia-g3 [options]
#     -w      Windows mode
#     -a      Add new players mode
#     -e      Eat orders from libdir/spool
#     -E      Eat orders from libdir/spool and terminate
#     -f      Don't buffer files for debugging
#     -i      Immediate mode
#     -l dir  Specify libdir, default ./lib
#     -p      Don't make data files pretty
#     -r      Run a turn
#     -R      Test the random number generator
#     -s      Extract safe havens as start city list
#     -S      Save the database at completion
#     -t      Test ilist code
#     -T      Print timing info
#     -M      Mail reports and order acks
#     -A      Charge player accounts
############################################################################
# Testing Strategy
#
#  Can we load the database?
#    olympia-g3 -l ./lib
#
#  Can we run in immediate mode (should be simplest)?
#    olympia-g3 -l ./lib -i
#
#  Can we run a turn?
#    olympia-g3 -l ./lib -r -S
#
#  Then
#    1. Try loading the existing database
#    2. Capture the output as golden files
#    3. Start refactoring
#
############################################################################
#
# Resolve the repo root from this script's location so the repo is relocatable.
OLYMPIA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# CMakePresets emits binaries to build/<presetName> (default preset: debug).
OLYMPIA_PRESET="${OLYMPIA_PRESET:-debug}"
OLYMPIA_BIN="${OLYMPIA_ROOT}/build/${OLYMPIA_PRESET}"
OLYMPIA_FIXTURES="${OLYMPIA_ROOT}/tests"
OLYMPIA_RUN="${OLYMPIA_ROOT}/run"
OLYMPIA_ENGINE=g3
OLYMPIA_COMMAND=olympia
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
OLYMPIA_INPUTS="${OLYMPIA_FIXTURES}/${OLYMPIA_COMMAND}/fixtures"
[ -d "${OLYMPIA_INPUTS}" ] || {
  echo "OLYMPIA_FIXTURES   == '${OLYMPIA_FIXTURES}'"
  echo "OLYMPIA_ENGINE     == '${OLYMPIA_ENGINE}'"
  echo "OLYMPIA_COMMAND    == '${OLYMPIA_COMMAND}'"
  echo "OLYMPIA_INPUTS     == '${OLYMPIA_INPUTS}'"
  echo "error: invalid fixtures input path"
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
# copy the test fixtures to the run folder
echo " info: copying inputs to $( pwd )"
[ -f "${OLYMPIA_INPUTS}/lib.tgz" ] || {
  echo "error: missing fixtures tarball"
  exit 2
}
[ -d lib ] && {
  echo " warn: removing existing lib/ from run folder"
  rm -rf lib
}
echo " info: extracting fixtures tarball..."
tar zxf "${OLYMPIA_INPUTS}/lib.tgz" || {
  echo "error: failed to extract fixtures tarball"
  exit 2
}
echo " info: rebuilt lib/ from fixtures tarball"
[ -f lib/master ] && {
  # Remove master index file - it will be regenerated on load
  # The master file can be out of date or have box type mismatches
  rm lib/master || {
    echo "error: failed to remove master index file"
    exit 2
  }
  echo " info: removed master index file (will be regenerated)"
}

############################################################################
# set seed values for random number generator
export G3_MAPGEN_SEED_1=18481
export G3_MAPGEN_SEED_2=28078
export G3_MAPGEN_SEED_3=26982

###########################################################################
# run the program in "immediate" mode
#   inputs: lib/
#   outputs: unknown
"${OLYMPIA_BIN}/${OLYMPIA_COMMAND}-${OLYMPIA_ENGINE}" -l ./lib -i </dev/null || {
  echo "error: ${OLYMPIA_COMMAND}-${OLYMPIA_ENGINE} failed"
  exit 2
}
echo " info: command thinks that it ran successfully"

############################################################################
# run a turn and update the data store (the flat files in ./lib)
touch .olympia.before
rm -rf lib-before lib-after
cp -a lib lib-before
"${OLYMPIA_BIN}/${OLYMPIA_COMMAND}-${OLYMPIA_ENGINE}" -r -l ./lib -S </dev/null || {
  echo "error: ${OLYMPIA_COMMAND}-${OLYMPIA_ENGINE} failed"
  exit 2
}
echo " info: command thinks that it ran successfully"
echo "       find lib -type f -newer .olympia.before | sort"
echo "       diff -ru lib-before lib"

exit 0
