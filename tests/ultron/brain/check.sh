#!/bin/bash
###########################################################################
# Smoke check for the Chaos Goblin brain (chaos_goblin.py, issue #105).
#
# On a fresh extraction of the trade-routes scenario:
#   1. export the pre-turn state (--state-export);
#   2. run the goblin twice with the same seed: the order files must be
#      byte-identical, and a different seed must change them;
#   3. run one normal -r -S turn on the goblin's orders with --coverage:
#      the engine must exit 0, and more verbs must fire than the four-verb
#      baseline (move, wait, use, pillage).
#
# Pass: prints YES and exits 0. Uses OLYMPIA_PRESET (default debug).
###########################################################################
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../../.." && pwd)"
PRESET="${OLYMPIA_PRESET:-debug}"
BIN="${ROOT}/build/${PRESET}/olympia-g3"
SCENARIO="${ROOT}/tests/olympia/regress/trade-routes/scenario.tgz"
GOBLIN="${HERE}/chaos_goblin.py"
SEED="${SEED:-1}"

[ -x "${BIN}" ] || { echo "error: missing ${BIN} (build the ${PRESET} preset first)"; exit 2; }

W="$(mktemp -d)"
trap 'rm -rf "${W}"' EXIT
tar zxf "${SCENARIO}" -C "${W}" || exit 2
cd "${W}" || exit 2

"${BIN}" -l ./lib test-use-const-report-date --state-export state.json </dev/null >/dev/null 2>&1 ||
	{ echo "NO  (state export failed)"; exit 1; }

python3 "${GOBLIN}" --state state.json --out a --seed "${SEED}" >/dev/null || exit 1
python3 "${GOBLIN}" --state state.json --out b --seed "${SEED}" >/dev/null || exit 1
python3 "${GOBLIN}" --state state.json --out c --seed "$((SEED + 1))" >/dev/null || exit 1

fail=0
diff -r a b >/dev/null || { echo "NO  (same seed gave different order files)"; fail=1; }
diff -r a c >/dev/null && { echo "NO  (a different seed gave the same order files)"; fail=1; }

cp a/* lib/orders/
"${BIN}" -r -l ./lib -S test-use-const-report-date --coverage coverage.tsv </dev/null >turn.log 2>&1 ||
	{ echo "NO  (turn on the goblin's orders exited $?; see turn.log)"; exit 1; }

fired="$(awk -F'\t' 'NR > 1 && $2 + $3 + $4 + $5 > 0' coverage.tsv | wc -l | tr -d ' ')"
[ "${fired}" -gt 4 ] || { echo "NO  (only ${fired} verbs fired)"; fail=1; }

[ "${fail}" -eq 0 ] && echo "YES"
exit "${fail}"
