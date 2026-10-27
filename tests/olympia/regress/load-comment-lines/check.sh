#!/bin/bash
###########################################################################
# Regression: a comment or stray line between boxes (issue #316).
#
# read_boxes() (olympia/io.c) skipped a `#` line, or reported a line that
# isn't a box header, without reading the next line, so it looped
# forever: silently on a comment, printing "read_boxes: unexpected line"
# without end otherwise. Now both branches advance.
#
# Each case extracts the shared base world, inserts lines before a box
# header in the middle of lib/item, then loads and saves the DB (-S, no
# -r). The same load and save of the unedited world is the reference.
#
# Three checks per case, all required:
#   1. the run exits 0 within TIMEOUT seconds (before the fix it hangs);
#   2. stderr has exactly WANT "read_boxes: unexpected line" reports;
#   3. the saved lib matches the reference, file for file: the inserted
#      lines are dropped and every box after them still loads.
#
# Pass:  prints YES and exits 0.   No EXPECT files: the base world is the spec.
###########################################################################
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../../../.." && pwd)"
. "${ROOT}/tests/olympia/engine.sh"
engine_no_update "$@"
WORLD="${ROOT}/tests/olympia/fixtures/world.tgz"
TIMEOUT=20
HEADER='^99 item '		# a box in the middle of lib/item

[ -f "${WORLD}" ] || { echo "error: missing ${WORLD} (run tests/olympia/fixtures/build-world.sh)"; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

run() {		# args: dir; load and save its lib, killed after TIMEOUT
	( cd "$1" && perl -e 'alarm shift; exec @ARGV' "${TIMEOUT}" \
		"${BIN}" -l ./lib -S </dev/null >"$1/out" 2>"$1/err" )
}

mkdir "${WORK}/ref" && tar zxf "${WORLD}" -C "${WORK}/ref" || exit 2
run "${WORK}/ref" || { echo "error: reference load exited $?"; exit 2; }

# name|unexpected-line reports wanted|lines inserted before HEADER
CASES=(
	'comment|0|# a comment between boxes'
	'blank|1|'
	'stray|1|not a box header'
	'mixed|2|# one\n\n# two\nstray'
)

fail=0
for c in "${CASES[@]}"; do
	IFS='|' read -r name want text <<<"${c}"
	dir="${WORK}/${name}"
	mkdir "${dir}" && tar zxf "${WORLD}" -C "${dir}" || exit 2
	lib="${dir}/lib/item"
	n="$(grep -n "${HEADER}" "${lib}" | cut -d: -f1)"
	if [ -z "${n}" ] || [ -n "$(sed -n "$((n - 1))p" "${lib}")" ]; then
		echo "error: no box header after a blank line matches ${HEADER} in lib/item"
		exit 2
	fi
	{ head -n $((n - 1)) "${lib}"; printf '%b\n' "${text}"; tail -n +"${n}" "${lib}"; } \
		>"${lib}.new" && mv "${lib}.new" "${lib}" || exit 2

	run "${dir}"
	ec=$?
	if [ "${ec}" -ne 0 ]; then
		echo "NO  (${name}: load exited ${ec}, want 0; 142 is the ${TIMEOUT}s timeout)"
		fail=1
		continue
	fi
	got="$(grep -c '^read_boxes: unexpected line' "${dir}/err")"
	if [ "${got}" -ne "${want}" ]; then
		echo "NO  (${name}: ${got} unexpected-line reports, want ${want})"
		fail=1
	fi
	if ! diff -r "${WORK}/ref/lib" "${dir}/lib" >/dev/null; then
		echo "NO  (${name}: saved lib differs from the unedited world's)"
		diff -r "${WORK}/ref/lib" "${dir}/lib" | head -5
		fail=1
	fi
done
if [ "${fail}" -eq 0 ]; then
	echo "YES"
	exit 0
fi
exit 1
