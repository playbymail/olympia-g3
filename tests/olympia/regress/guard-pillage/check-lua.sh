#!/bin/bash
###########################################################################
# Regression: guard-pillage built by the Lua scripting host (issue #31).
#
# Proves the olyscript-g3 prototype (doc/scripting-tool.md §9): guard-pillage.lua
# authors the SAME scenario build-scenario.sh hand-assembles from six tools, and
# the resulting pre-turn `lib`, once a turn is run, hashes BYTE-IDENTICALLY to
# the committed EXPECT.sha256 -- the same baseline check.sh pins. If this prints
# YES, the binding layer is byte-preserving and the authoring story is one file
# instead of six tools.
#
# Flow (vs check.sh, which extracts the frozen scenario.tgz instead):
#   1. extract the bare-map fixture (tests/olympia/fixtures/lib.tgz), drop master
#      -- exactly build-scenario.sh's starting point;
#   2. olyscript-g3 guard-pillage.lua  -> builds + saves the pre-turn lib;
#   3. olympia-g3 -r -S                 -> run the turn (as check.sh does);
#   4. hash save/1/{300,301} + fact/{300,301} and diff EXPECT.sha256.
#
# Date-independent via `test-use-const-report-date`.
# Pass: prints YES and exits 0.   (Re-baseline lives in check.sh --update.)
###########################################################################
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../../../.." && pwd)"
PRESET="${OLYMPIA_PRESET:-debug}"
BIN="${ROOT}/build/${PRESET}/olympia-g3"
SCRIPT_BIN="${ROOT}/build/${PRESET}/olyscript-g3"
SEED_LIB="${ROOT}/tests/olympia/fixtures/lib.tgz"

[ -x "${BIN}" ]        || { echo "error: missing ${BIN} (build the ${PRESET} preset first)"; exit 2; }
[ -x "${SCRIPT_BIN}" ] || { echo "error: missing ${SCRIPT_BIN} (build the ${PRESET} preset first)"; exit 2; }
[ -f "${SEED_LIB}" ]   || { echo "error: missing ${SEED_LIB}"; exit 2; }
[ -f "${HERE}/EXPECT.sha256" ] || { echo "error: missing EXPECT.sha256"; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
cd "${WORK}" || exit 2

# 1. bare map (build-scenario.sh's starting point)
tar zxf "${SEED_LIB}" || exit 2
rm -f lib/master

# 2. author the scenario in one Lua script
if ! "${SCRIPT_BIN}" "${HERE}/guard-pillage.lua" >/dev/null 2>&1; then
	echo "NO  (olyscript-g3 build failed)"
	"${SCRIPT_BIN}" "${HERE}/guard-pillage.lua"
	exit 1
fi

# 3. run a turn against the scripted lib (identical to check.sh)
"${BIN}" -r -l ./lib -S test-use-const-report-date </dev/null >/dev/null 2>&1
ec=$?
if [ "${ec}" -ne 0 ]; then
	echo "NO  (olympia-g3 turn failed: exit ${ec})"
	exit 1
fi

# 4. same manifest check.sh hashes, diffed against the SAME committed baseline
manifest() { ( cd "${WORK}/lib" && shasum -a 256 \
	save/1/300 save/1/301 fact/300 fact/301 ); }

if diff -u "${HERE}/EXPECT.sha256" <(manifest) >/dev/null; then
	echo "YES"
	exit 0
else
	echo "NO  (Lua-built output differs from EXPECT.sha256)"
	diff -u "${HERE}/EXPECT.sha256" <(manifest)
	exit 1
fi
