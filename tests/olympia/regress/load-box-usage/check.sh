#!/bin/bash
###########################################################################
# Regression: the entity space usage report (issue #310).
#
# print_box_usage() (olympia/code.c) prints, at the end of every load_db(),
# how many boxes are used in each id range. Two ranges disagreed with the
# entity coding table at the top of the same file: `locs` was 20000-59999
# (missing the provinces at 10000-19999 and overlapping play, lloc, the
# regions and subl) and `rest` started at 79900, not 79000. Each total and
# percentage was also taken over high - low slots, one fewer than the
# range holds. Now `locs` is 10000-49999, `rest` 79000-149999, and each
# range counts high - low + 1 slots.
#
# Extracts the shared base world and loads it (-l, no -r, no -S), then
# compares the report on stderr, from its "entity space usage:" heading
# to the last range, with EXPECT.usage.
#
# Pass:  prints YES and exits 0.   Update: ./check.sh --update
###########################################################################
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../../../.." && pwd)"
. "${ROOT}/tests/olympia/engine.sh"
engine_no_update "$@"
WORLD="${ROOT}/tests/olympia/fixtures/world.tgz"

[ -f "${WORLD}" ] || { echo "error: missing ${WORLD} (run tests/olympia/fixtures/build-world.sh)"; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

tar zxf "${WORLD}" -C "${WORK}" || exit 2
( cd "${WORK}" && "${BIN}" -l ./lib </dev/null >"${WORK}/out" 2>"${WORK}/err" )
ec=$?
if [ "${ec}" -ne 0 ]; then
	echo "NO  (load exited ${ec}, want 0)"
	exit 1
fi
awk '/^entity space usage:$/ { f = 1 } f && /^(entity|\t)/ { print; next } f { exit }' \
	"${WORK}/err" >"${WORK}/usage"

if [ "${1:-}" = "--update" ]; then
	cp "${WORK}/usage" "${HERE}/EXPECT.usage"
	echo "updated ${HERE}/EXPECT.usage"
	exit 0
fi

if diff -u "${HERE}/EXPECT.usage" "${WORK}/usage" >/dev/null; then
	echo "YES"
	exit 0
else
	echo "NO  (usage report changed vs EXPECT.usage)"
	diff -u "${HERE}/EXPECT.usage" "${WORK}/usage"
	exit 1
fi
