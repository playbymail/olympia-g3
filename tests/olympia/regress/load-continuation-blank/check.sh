#!/bin/bash
###########################################################################
# Regression: a blank line after a continued field (issue #318).
#
# skill_list_scan, item_list_scan, trade_list_scan and req_list_scan in
# olympia/io.c test `s[strlen(s)-1] == '\\'` to see whether another
# entry follows. When the line after a trailing `\` was empty, that read
# s[-1], one byte before readlin()'s buffer. Now they test `*s` first, so
# an empty line ends the list, as it does in the boxlist scanners.
#
# One case per affected scanner. Each case extracts the shared base
# world, puts a field whose last line ends in `\` before the blank line
# that ends one box file, and loads the DB: no -r, no -S, so only
# load_db() and check_db() run.
#
# Two checks per case, both required:
#   1. the load exits 0 (before the fix under asan-ubsan: a UBSan abort,
#      exit 134; the debug build reads a stray byte and usually passes,
#      so the asan-ubsan gate is the one that pins this);
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

# name|file under lib|field put before the final blank line; a `\` follows
CASES=(
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
	printf '%b \\\n\n' "${text}" >>"${lib}" || exit 2
	if ! tail -n 2 "${lib}" | head -n 1 | grep -q '\\$' \
		|| [ -n "$(tail -n 1 "${lib}")" ]; then
		echo "error: lib/${file} does not end with a continuation and a blank line"
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
