#!/bin/bash
###########################################################################
# Regression: options parse and are reported the same everywhere (#343).
#
# main() (olympia/main.c) parsed its options with the C library's
# getopt(), so its diagnostics were the platform's: macOS printed
# "olympia-g3: illegal option -- x", glibc "olympia-g3: invalid option --
# 'x'". Now oly_getopt() is the BSD getopt() macOS has, on every platform:
#   - parsing stops at the first argument that is not an option, at a
#     lone "-", and after "--";
#   - any other argument starting with "-" is a cluster of option letters,
#     so "--bogus" is the options '-', 'b', 'o', 'g', 'u' and 's';
#   - an option that takes an argument (-l, -G) takes the rest of its
#     cluster, or else the next argument;
#   - an unknown option prints "<argv[0]>: illegal option -- <c>" and a
#     missing argument "<argv[0]>: option requires an argument -- <c>",
#     with argv[0] as given.
#
# Each case runs the engine with a fixed argv[0] (bash's exec -a) in a
# copy of the shared base world, so a case that stops parsing early just
# loads the DB (-l ./lib, no -S). -R ends a case early: it runs the RNG
# self-test (stdout, not checked here) and exits 0.
#
# EXPECT.txt has, per case, its argv, the exit status and the stderr lines
# from option parsing (the diagnostics and the usage line), byte for byte.
#
# Pass:  prints YES and exits 0.   Re-baseline: ./check.sh --update
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

# argv[0]|the other arguments, split on spaces
CASES=(
	'olympia-g3|-x'
	'olympia-g3|-xR'
	'olympia-g3|-xy'
	'olympia-g3|-x -y -R'
	'olympia-g3|-l'
	'olympia-g3|-wl'
	'olympia-g3|-G'
	'olympia-g3|-lfoo -x'
	'olympia-g3|-:'
	'olympia-g3|-?'
	'olympia-g3|-R?'
	'olympia-g3|--bogus'
	'olympia-g3|--bogus -R'
	'olympia-g3|-l ./lib -- -x'
	'olympia-g3|-l ./lib - -x'
	'olympia-g3|-l ./lib junk -x'
	'olympia-g3|-l ./lib -x junk'
	'olympia-g3|-l./lib -G7 -x'
	'./oly-c|-x'
	'/some/path/olympia-g3|-l'
)

for c in "${CASES[@]}"; do
	IFS='|' read -r argv0 args <<<"${c}"
	read -r -a argv <<<"${args}"
	( cd "${WORK}" && exec -a "${argv0}" "${BIN}" "${argv[@]}" ) \
		</dev/null >/dev/null 2>"${WORK}/err"
	ec=$?
	echo "== ${argv0} ${args}"
	echo "exit ${ec}"
	grep -E "^(${argv0//./\\.}: |usage: )" "${WORK}/err"
done >"${WORK}/got.txt"

if [ "${1:-}" = "--update" ]; then
	cp "${WORK}/got.txt" "${HERE}/EXPECT.txt"
	echo "updated ${HERE}/EXPECT.txt"
	exit 0
fi

if diff -u "${HERE}/EXPECT.txt" "${WORK}/got.txt" >/dev/null; then
	echo "YES"
	exit 0
fi
echo "NO  (option parsing changed vs EXPECT.txt)"
diff -u "${HERE}/EXPECT.txt" "${WORK}/got.txt"
exit 1
