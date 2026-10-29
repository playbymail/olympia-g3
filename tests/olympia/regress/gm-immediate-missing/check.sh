#!/bin/bash
###########################################################################
# Regression: GM console commands missing an argument no longer read a
# stale parse slot (issue #366).
#
# Runs olympia-g3 -i (immediate mode, the GM console) on a copy of the
# shared base world and feeds it COMMANDS on stdin. The console's one
# struct command keeps its parse vector's slots between commands, so a
# slot past a command's last word is NULL (no command filled it) or points
# into an earlier command's freed line. be, additem, poof, know and makeloc
# printed or looked up slot 1 with no argument given; under ASan each was a
# heap-use-after-free after a longer command. Now each refuses a missing
# argument first ("Must specify ...").
#
# Each bare command runs after a longer one, and the first `be` runs
# before any command has filled a slot.
#
# EXPECT.txt is the console's replies, one per command: the lines after
# each "200> " prompt. The startup banner is left out; it prints
# sizeof(struct box), which differs between builds.
# Pass:  prints YES and exits 0.   Re-baseline: ./check.sh --update
###########################################################################
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../../../.." && pwd)"
. "${ROOT}/tests/olympia/engine.sh"
engine_no_update "$@"
WORLD="${ROOT}/tests/olympia/fixtures/world.tgz"

COMMANDS=(
	"be"
	"be 0 aaaa bbbb cccc"	"be"
	"additem 1 2 3 4"		"additem"
	"poof 1 2 3 4"			"poof"
	"know 1 2 3 4"			"know"
	"makeloc 1 2 3 4"		"makeloc"
)

[ -f "${WORLD}" ] || { echo "error: missing ${WORLD} (run tests/olympia/fixtures/build-world.sh)"; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
tar zxf "${WORLD}" -C "${WORK}" || exit 2

( cd "${WORK}" && printf '%s\n' "${COMMANDS[@]}" |
	"${BIN}" -l ./lib -i >"${WORK}/console.out" 2>"${WORK}/console.err" )
ec=$?
if [ "${ec}" -ne 0 ]; then
	echo "NO  (olympia-g3 -i failed: exit ${ec})"
	grep -m 3 -i "assert\|AddressSanitizer\|runtime error" "${WORK}/console.err"
	exit 1
fi

replies() { sed -n 's/^200> //p' "${WORK}/console.out" | grep -v '^$'; }

if [ "${1:-}" = "--update" ]; then
	replies > "${HERE}/EXPECT.txt"
	echo "updated ${HERE}/EXPECT.txt"
	exit 0
fi

if ! diff -u "${HERE}/EXPECT.txt" <(replies); then
	echo "NO  (console replies changed vs EXPECT.txt)"
	exit 1
fi
echo "YES"
