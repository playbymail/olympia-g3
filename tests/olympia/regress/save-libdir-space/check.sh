#!/bin/bash
###########################################################################
# Regression: a libdir holding a space (issue #320).
#
# open_logfile(), write_all_boxes(), save_orders() and save_logdir()
# cleared log/, fact/, orders/ and save/<turn>/ with
# system("rm -rf %s/...", libdir), libdir unquoted. With -l "./my lib" the shell ran `rm -rf ./my lib/fact`:
# it removed ./my and ./lib/fact, and left "./my lib/fact" alone. Now
# remove_dir() (olympia/io.c) removes the directory without the shell.
#
# The base world is extracted into "my lib", next to decoys at every
# path the old command removed, and a stale file is planted in each
# directory the engine should clear. One turn runs with -r -S, which
# reaches all four call sites. The same turn on a plain ./lib is the
# reference.
#
# Checks, all required:
#   1. the turn exits 0;
#   2. every decoy is still there;
#   3. every stale file is gone;
#   4. the saved "my lib" matches the reference lib, file for file.
#
# Pass:  prints YES and exits 0.   No EXPECT files: the base world is the spec.
###########################################################################
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../../../.." && pwd)"
. "${ROOT}/tests/olympia/engine.sh"
engine_no_update "$@"
WORLD="${ROOT}/tests/olympia/fixtures/world.tgz"
TURN=1			# the turn the base world runs, so save/1

[ -f "${WORLD}" ] || { echo "error: missing ${WORLD} (run tests/olympia/fixtures/build-world.sh)"; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

run() {		# args: dir libdir; run one turn and save
	( cd "$1" && "${BIN}" -r -l "$2" -S </dev/null >"$1/out" 2>"$1/err" )
}

mkdir "${WORK}/ref" && tar zxf "${WORLD}" -C "${WORK}/ref" || exit 2
run "${WORK}/ref" ./lib || { echo "error: reference turn exited $?"; exit 2; }

dir="${WORK}/space"
mkdir "${dir}" && tar zxf "${WORLD}" -C "${dir}" && mv "${dir}/lib" "${dir}/my lib" || exit 2

DECOYS=(my/keep lib/log/keep lib/fact/keep lib/orders/keep "lib/save/${TURN}/keep")
STALE=("my lib/log/stale" "my lib/fact/stale" "my lib/orders/stale" "my lib/save/${TURN}/stale")
for f in "${DECOYS[@]}" "${STALE[@]}"; do
	mkdir -p "$(dirname "${dir}/${f}")" && : >"${dir}/${f}" || exit 2
done

run "${dir}" "./my lib"
ec=$?
if [ "${ec}" -ne 0 ]; then
	echo "NO  (turn exited ${ec}, want 0)"
	exit 1
fi

fail=0
for f in "${DECOYS[@]}"; do
	if [ ! -e "${dir}/${f}" ]; then
		echo "NO  (decoy ${f} was removed)"
		fail=1
	fi
done
for f in "${STALE[@]}"; do
	if [ -e "${dir}/${f}" ]; then
		echo "NO  (stale ${f} was not removed)"
		fail=1
	fi
done
if ! diff -r "${WORK}/ref/lib" "${dir}/my lib" >/dev/null; then
	echo "NO  (saved \"my lib\" differs from the reference lib)"
	diff -r "${WORK}/ref/lib" "${dir}/my lib" | head -5
	fail=1
fi
if [ "${fail}" -eq 0 ]; then
	echo "YES"
	exit 0
fi
exit 1
