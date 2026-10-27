#!/bin/bash
###########################################################################
# Regression: an out-of-range entry in lib/master (issue #321).
#
# fast_scan() (olympia/io.c) read each master line as `num kind.subkind`
# and passed the numbers straight to alloc_box(). A kind or subkind out of
# range indexed outside box_head[] or sub_head[] (AddressSanitizer
# global-buffer-overflow, or silently wrong boxes), and a number out of
# range failed alloc_box()'s assert (exit 134). Now fast_scan() checks the
# whole file first. On a bad entry it reports it and allocates nothing, so
# load_db() falls back to scan_all_boxes(), which reads the box files.
#
# Each case extracts the shared base world, rewrites master's entry for
# box 1 (`1<tab>4.0<tab>item`), then loads and saves the DB (-S, no -r).
# The same load and save of the unedited world is the reference: master is
# only an index, so the fallback must give the same DB.
#
# Four checks per case, all required:
#   1. the run exits 0 (before the fix: 134 for a number out of range);
#   2. no AddressSanitizer or UBSan report on stderr;
#   3. stderr reports the bad entry once and the scan_all_boxes() fallback;
#   4. the saved lib matches the reference, file for file.
#
# Pass:  prints YES and exits 0.   No EXPECT files: the base world is the spec.
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

run() {		# args: dir; load and save its lib
	( cd "$1" && "${BIN}" -l ./lib -S </dev/null >"$1/out" 2>"$1/err" )
}

mkdir "${WORK}/ref" && tar zxf "${WORLD}" -C "${WORK}/ref" || exit 2
run "${WORK}/ref" || { echo "error: reference load exited $?"; exit 2; }

# name|replacement for master's `1<tab>4.0<tab>` prefix|reported entry
CASES=(
	'kind-high|1\t99.0\t|1 99.0'
	'kind-negative|1\t-3.0\t|1 -3.0'
	'kind-deleted|1\t0.0\t|1 0.0'
	'subkind-high|1\t4.99\t|1 4.99'
	'number-high|150000\t4.0\t|150000 4.0'
)

fail=0
for c in "${CASES[@]}"; do
	IFS='|' read -r name repl entry <<<"${c}"
	dir="${WORK}/${name}"
	mkdir "${dir}" && tar zxf "${WORLD}" -C "${dir}" || exit 2
	REPL="${repl}" perl -pi -e \
		'BEGIN { ($r = $ENV{REPL}) =~ s/\\t/\t/g } $n += s/^1\t4\.0\t/$r/; END { exit($n != 1) }' \
		"${dir}/lib/master" || { echo "error: lib/master has no single entry for box 1"; exit 2; }

	run "${dir}"
	ec=$?
	if [ "${ec}" -ne 0 ]; then
		echo "NO  (${name}: load exited ${ec}, want 0)"
		fail=1
		continue
	fi
	if grep -q "AddressSanitizer\|runtime error" "${dir}/err"; then
		echo "NO  (${name}: sanitizer report on stderr)"
		grep -m 3 "AddressSanitizer\|runtime error" "${dir}/err"
		fail=1
	fi
	got="$(grep -c "^fast_scan: bad master entry: ${entry}\$" "${dir}/err")"
	if [ "${got}" -ne 1 ]; then
		echo "NO  (${name}: ${got} reports of bad master entry '${entry}', want 1)"
		fail=1
	fi
	if ! grep -q '^fast_scan failed, scan_all_boxes()$' "${dir}/err"; then
		echo "NO  (${name}: no scan_all_boxes() fallback reported)"
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
