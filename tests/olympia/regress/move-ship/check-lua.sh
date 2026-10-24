#!/bin/bash
###########################################################################
# Regression: move-ship built by the Lua scripting host (issue #120).
#
# move-ship.lua authors the SAME scenario build-scenario.sh assembles from
# piped immediate-mode commands and awk'd save files. Once a turn is run, its
# output must match the committed EXPECT.sha256 and EXPECT.json -- the same
# baselines check.sh pins -- byte for byte.
#
# Flow (vs check.sh, which unpacks the frozen scenario.patch instead):
#   1. extract the bare-map fixture (tests/olympia/fixtures/lib.tgz), drop master
#      -- exactly build-scenario.sh's starting point;
#   2. olyscript-g3 move-ship.lua  -> builds + saves the pre-turn lib;
#   3. olympia-g3 -r -S            -> run the turn (as check.sh does);
#   4. check the coverage cells, hash FILES and diff EXPECT.sha256, and diff
#      the --state-export snapshot against EXPECT.json.
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

FILES=(save/1/300 save/1/301 fact/300 fact/301 ship)
VERBS=(board unload ferry sail fee)

[ -x "${BIN}" ]        || { echo "error: missing ${BIN} (build the ${PRESET} preset first)"; exit 2; }
[ -x "${SCRIPT_BIN}" ] || { echo "error: missing ${SCRIPT_BIN} (build the ${PRESET} preset first)"; exit 2; }
[ -f "${SEED_LIB}" ]   || { echo "error: missing ${SEED_LIB}"; exit 2; }
[ -f "${HERE}/EXPECT.sha256" ] || { echo "error: missing EXPECT.sha256"; exit 2; }
[ -f "${HERE}/EXPECT.json" ]   || { echo "error: missing EXPECT.json"; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
cd "${WORK}" || exit 2

# 1. bare map (build-scenario.sh's starting point)
tar zxf "${SEED_LIB}" || exit 2
rm -f lib/master

# 2. author the scenario in one Lua script
if ! "${SCRIPT_BIN}" "${HERE}/move-ship.lua" >/dev/null 2>&1; then
	echo "NO  (olyscript-g3 build failed)"
	"${SCRIPT_BIN}" "${HERE}/move-ship.lua"
	exit 1
fi

# 3. run a turn against the scripted lib (identical to check.sh)
"${BIN}" -r -l ./lib -S test-use-const-report-date \
	--coverage "${WORK}/coverage.tsv" \
	--state-export "${WORK}/state.json" </dev/null >/dev/null 2>&1
ec=$?
if [ "${ec}" -ne 0 ]; then
	echo "NO  (olympia-g3 turn failed: exit ${ec})"
	exit 1
fi

# 4. same checks as check.sh, against the SAME committed baselines
fail=0
for v in "${VERBS[@]}"; do
	n="$(awk -F'\t' -v v="${v}" '
		NR == 1 { for (i = 1; i <= NF; i++) if ($i == "ok") col = i; next }
		$1 == v { print $col }' "${WORK}/coverage.tsv")"
	[ "${n:-0}" -gt 0 ] || { echo "NO  (verb '${v}' did not reach ok: ok=${n:-0})"; fail=1; }
done
[ "${fail}" -eq 0 ] || exit 1

manifest() { ( cd "${WORK}/lib" && shasum -a 256 "${FILES[@]}" ); }

if ! diff -u "${HERE}/EXPECT.sha256" <(manifest) >/dev/null; then
	echo "NO  (Lua-built output differs from EXPECT.sha256)"
	diff -u "${HERE}/EXPECT.sha256" <(manifest)
	fail=1
fi
if ! diff -u "${HERE}/EXPECT.json" "${WORK}/state.json" >/dev/null; then
	echo "NO  (Lua-built state export differs from EXPECT.json)"
	diff -u "${HERE}/EXPECT.json" "${WORK}/state.json"
	fail=1
fi
if [ "${fail}" -eq 0 ]; then
	echo "YES"
	exit 0
fi
exit 1
