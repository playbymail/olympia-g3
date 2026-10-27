#!/bin/bash
###########################################################################
# Regression: options parse and are reported the same everywhere (#344).
#
# genesis (genesis/genesis.c) parsed its options with the C library's
# getopt_long(), so its diagnostics were the platform's: macOS printed
# "genesis-g3: unrecognized option `--bogus'", glibc "genesis-g3:
# unrecognized option '--bogus'". Now gen_getopt_long() is the BSD
# getopt_long() macOS has, on every platform:
#   - options after a non-option argument are still parsed, unless
#     POSIXLY_CORRECT is set; "--" ends them;
#   - "--name" or a '-' inside a cluster ("-D-size") is a long option,
#     with "=value" or the next argument; a unique (or same-meaning)
#     prefix of a long name is that option;
#   - errors print "genesis-g3: ..." (a fixed name, not argv[0]) in the
#     BSD wording and quoting; see the comment above gen_getopt_long().
#
# Each case runs genesis-g3 in its own empty directory with a fixed
# argv[0] (bash's exec -a) and, if given, POSIXLY_CORRECT=1 in the
# environment. A case that parses cleanly generates a small world.
#
# EXPECT.txt has, per case, its environment, argv, exit status, stdout and
# stderr, byte for byte. The files a world-writing case leaves are not
# compared (the other genesis gates cover them).
#
# Pass:  prints YES and exits 0.   Re-baseline: ./check.sh --update
###########################################################################
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${HERE}/../../genesis.sh"
genesis_no_update "$@"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

# POSIXLY_CORRECT ("-" or "posix")|argv[0]|the other arguments, split on spaces
CASES=(
	'-|genesis-g3|-x'
	'-|genesis-g3|-xD'
	'-|genesis-g3|-:'
	'-|genesis-g3|-s'
	'-|genesis-g3|--bogus'
	'-|genesis-g3|--bogus=1'
	'-|genesis-g3|--size'
	'-|genesis-g3|--s 10'
	'-|genesis-g3|--=x'
	'-|genesis-g3|--de=1'
	'-|genesis-g3|--help=x'
	'-|genesis-g3|-D-'
	'-|genesis-g3|-D-bogus'
	'-|genesis-g3|--si 9'
	'-|genesis-g3|--size=9'
	'-|genesis-g3|-s9'
	'-|genesis-g3|-Ds 9'
	'-|genesis-g3|-D-size=9'
	'-|genesis-g3|junk --size 9'
	'-|genesis-g3|- --size 9'
	'-|genesis-g3|--size 9 -- -x'
	'-|genesis-g3|--size 10 -i 2 -n 1 -- -x'
	'posix|genesis-g3|-x'
	'posix|genesis-g3|--bogus'
	'posix|genesis-g3|--size 10 -i 2 -n 1 junk -x'
	'-|/some/path/genesis-g3|-x'
	'-|other-name|--bogus'
)

i=0
for c in "${CASES[@]}"; do
	IFS='|' read -r env argv0 args <<<"${c}"
	read -r -a argv <<<"${args}"
	i=$((i + 1))
	dir="${WORK}/${i}"
	mkdir "${dir}" || exit 2
	if [ "${env}" = "posix" ]; then
		( cd "${dir}" && export POSIXLY_CORRECT=1 && exec -a "${argv0}" "${BIN}" "${argv[@]}" ) \
			</dev/null >"${dir}/out" 2>"${dir}/err"
	else
		( cd "${dir}" && unset POSIXLY_CORRECT && exec -a "${argv0}" "${BIN}" "${argv[@]}" ) \
			</dev/null >"${dir}/out" 2>"${dir}/err"
	fi
	ec=$?
	echo "== ${env} ${argv0} ${args}"
	echo "exit ${ec}"
	echo "-- stdout"
	cat "${dir}/out"
	echo "-- stderr"
	cat "${dir}/err"
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
