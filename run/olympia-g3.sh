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
#     --coverage path  Write the command coverage dump to path
#     --use-coverage path  Write the use coverage dump to path
#     --phase-coverage path  Write the phase coverage dump to path
#
#   Set OLYMPIA_COVERAGE=<path> to pass --coverage to the turn run below, and
#   OLYMPIA_USE_COVERAGE=<path> to pass --use-coverage, and
#   OLYMPIA_PHASE_COVERAGE=<path> to pass --phase-coverage.
#
#   Set OLYMPIA_ENGINE_BIN=<path> to run that engine (e.g. a port's) instead
#   of build/<preset>/olympia-g3; see tests/olympia/engine.sh. Set
#   OLYMPIA_RUN_DIR=<dir> to run the turn in <dir> instead of run/olympia;
#   it is created if missing, and its lib/, lib-before/ and lib-after/ are
#   replaced. tests/olympia/golden_check.sh reads the same OLYMPIA_RUN_DIR.
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
# Sets BIN: build/<preset>/olympia-g3, or OLYMPIA_ENGINE_BIN (exits 2 if bad).
. "${OLYMPIA_ROOT}/tests/olympia/engine.sh"
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
if [ -n "${OLYMPIA_RUN_DIR:-}" ]; then
  # refuse a run directory under tests/, before creating it and again once
  # symlinks are resolved
  under_tests() {
    case "$1/" in
    "${OLYMPIA_FIXTURES}/"*|"$(cd "${OLYMPIA_FIXTURES}" && pwd -P)/"*)
      echo "OLYMPIA_RUN_DIR    == '${OLYMPIA_RUN_DIR}'"
      echo "error: refusing a run directory under tests/"
      exit 2
      ;;
    esac
  }
  case "${OLYMPIA_RUN_DIR}" in
  /*) under_tests "${OLYMPIA_RUN_DIR}" ;;
  *)  under_tests "${PWD}/${OLYMPIA_RUN_DIR}" ;;
  esac
  mkdir -p "${OLYMPIA_RUN_DIR}" || {
    echo "OLYMPIA_RUN_DIR    == '${OLYMPIA_RUN_DIR}'"
    echo "error: unable to create OLYMPIA_RUN_DIR"
    exit 2
  }
  OLYMPIA_OUTPUTS="$(cd "${OLYMPIA_RUN_DIR}" && pwd -P)"
  under_tests "${OLYMPIA_OUTPUTS}"
fi
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
echo " info: engine ${BIN}"
# Record which engine writes this run; golden_check.sh --update accepts only
# a run of the default C engine.
if [ -n "${OLYMPIA_ENGINE_BIN:-}" ]; then
  echo "OLYMPIA_ENGINE_BIN ${BIN}" > .olympia.engine
else
  echo "default ${BIN}" > .olympia.engine
fi
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
"${BIN}" -l ./lib -i </dev/null || {
  echo "error: ${BIN} failed"
  exit 2
}
echo " info: command thinks that it ran successfully"

############################################################################
# run a turn and update the data store (the flat files in ./lib)
touch .olympia.before
rm -rf lib-before lib-after
cp -a lib lib-before
# test-use-const-report-date: fix the Olympia Times masthead date so the golden
# manifest is deterministic across days (otherwise times_0 embeds today's date).
"${BIN}" -r -l ./lib -S test-use-const-report-date ${OLYMPIA_COVERAGE:+--coverage "${OLYMPIA_COVERAGE}"} ${OLYMPIA_USE_COVERAGE:+--use-coverage "${OLYMPIA_USE_COVERAGE}"} ${OLYMPIA_PHASE_COVERAGE:+--phase-coverage "${OLYMPIA_PHASE_COVERAGE}"} </dev/null || {
  echo "error: ${BIN} failed"
  exit 2
}
echo " info: command thinks that it ran successfully"
echo "       find lib -type f -newer .olympia.before | sort"
echo "       diff -ru lib-before lib"

exit 0
