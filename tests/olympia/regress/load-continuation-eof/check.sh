#!/bin/bash
###########################################################################
# Regression: a continued field on a box file's last line (issue #313).
#
# The list scanners in olympia/io.c follow a trailing `\` with
# readlin_ew() and used the result without checking it. When the `\` was
# on the file's last line, readlin_ew() returned NULL and load_db()
# crashed (SIGSEGV). Now the scanner keeps the entries read so far and
# stops, as if the line had no `\`.
#
# One case per reachable scanner (ilist_scan has no caller). Each case
# extracts the shared base world, drops the blank line that ends one box
# file, appends a field whose last line ends in `\`, and loads the DB:
# no -r, no -S, so only load_db() and check_db() run.
#
# Two checks per case, both required:
#   1. the load exits 0 (before the fix: 139, or a SEGV under asan-ubsan);
#   2. no AddressSanitizer or UBSan report on stderr.
#
# Pass:  prints YES and exits 0.   No EXPECT files: nothing is saved.
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

# name|file under lib|field appended in place of the final blank line; a `\` follows
CASES=(
	'boxlist|fact/205|an 206'
	'boxlist0|loc|LO\n pd 0 10001'
	'admit|fact/205|PL\n am 206 1'
	'known|fact/205|PL\n kn 26000'
	'skill_list|fact/207|CH\n sl 920 2 0 0 0'
	'item_list|item|il\t10 1'
	'trade_list|loc|tl\t1 10 1 0 0 0 0 0'
	'req_list|skill|SK\n rq 77 1 1'
)

fail=0
for c in "${CASES[@]}"; do
	IFS='|' read -r name file text <<<"${c}"
	dir="${WORK}/${name}"
	mkdir "${dir}" && tar zxf "${WORLD}" -C "${dir}" || exit 2
	lib="${dir}/lib/${file}"
	if [ "$(tail -n 1 "${lib}")" != "" ]; then
		echo "error: lib/${file} does not end with a blank line"
		exit 2
	fi
	sed -i.bak '$d' "${lib}" && rm -f "${lib}.bak" || exit 2
	printf '%b \\\n' "${text}" >>"${lib}" || exit 2
	if [ "$(tail -c 2 "${lib}")" != "$(printf '\\\n')" ]; then
		echo "error: lib/${file} does not end with a continuation"
		exit 2
	fi

	( cd "${dir}" && "${BIN}" -l ./lib </dev/null >"${dir}/out" 2>"${dir}/err" )
	ec=$?
	if [ "${ec}" -ne 0 ]; then
		echo "NO  (${name}: load exited ${ec}, want 0)"
		fail=1
	elif grep -q "AddressSanitizer\|runtime error" "${dir}/err"; then
		echo "NO  (${name}: sanitizer report on stderr)"
		grep -m 3 "AddressSanitizer\|runtime error" "${dir}/err"
		fail=1
	fi
done
if [ "${fail}" -eq 0 ]; then
	echo "YES"
	exit 0
fi
exit 1
