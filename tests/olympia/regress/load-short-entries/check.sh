#!/bin/bash
###########################################################################
# Regression: short and empty list entries in a box file (#311, #312).
#
# #311: skill_list_scan and req_list_scan (olympia/io.c) sscanf()'d into
# locals that were never set, so on a line with too few numbers the
# entry's know, experience or consume was stack garbage. Now each entry
# starts them at 0.
#
# #312: a bare `sl`, `il`, `tl` or `rq` tag hands its scanner "", and the
# continuation test read s[-1]. The `*s` guard from #318 (PR #319) covers
# it: the empty entry is reported as bad and dropped.
#
# Each case extracts the shared base world, puts a field before the blank
# line that ends one box file, then loads and saves the DB (-S, no -r).
#
# Three checks per case, all required:
#   1. the run exits 0 with no AddressSanitizer or UBSan report;
#   2. stderr has the case's report exactly once (or none, if "-");
#   3. the saved file has the case's line exactly once (or skip, if "-").
#
# Pass:  prints YES and exits 0.   No EXPECT files.
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

# name|file under lib|field put before the final blank line|stderr report|saved line
CASES=(
	'skill-short|fact/207|CH\n sl 920|-| sl\t920 0 0 0 0'
	'skill-two|fact/207|CH\n sl 920 2 \\\n\t921|-| sl\t920 2 0 0 0 \\\n\t921 0 0 0 0'
	'req-short|skill|SK\n rq 77 2|-| rq\t77 2 0'
	'req-two|skill|SK\n rq 77 2 1 \\\n\t78 3|-| rq\t77 2 1 \\\n\t78 3 0'
	'skill-bare|fact/207|CH\n sl|skill_list_scan(9999): bad skill 0|-'
	'item-bare|item|il|item_list_scan(403): bad item 0|-'
	'trade-bare|loc|tl|trade_list_scan(78999): bad item 0|-'
	'req-bare|skill|SK\n rq|req_list_scan(922): bad item 0|-'
)

fail=0
for c in "${CASES[@]}"; do
	IFS='|' read -r name file text report saved <<<"${c}"
	dir="${WORK}/${name}"
	mkdir "${dir}" && tar zxf "${WORLD}" -C "${dir}" || exit 2
	lib="${dir}/lib/${file}"
	if [ -n "$(tail -n 1 "${lib}")" ]; then
		echo "error: lib/${file} does not end with a blank line"
		exit 2
	fi
	sed -i.bak '$d' "${lib}" && rm -f "${lib}.bak" || exit 2
	printf '%b\n\n' "${text}" >>"${lib}" || exit 2

	( cd "${dir}" && "${BIN}" -l ./lib -S </dev/null >"${dir}/out" 2>"${dir}/err" )
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
	got="$(grep -c 'list_scan(' "${dir}/err")"
	if [ "${report}" = "-" ]; then
		want=0
	else
		want=1
		if [ "$(grep -cxF -- "${report}" "${dir}/err")" -ne 1 ]; then
			echo "NO  (${name}: stderr lacks \"${report}\")"
			fail=1
		fi
	fi
	if [ "${got}" -ne "${want}" ]; then
		echo "NO  (${name}: ${got} list_scan reports on stderr, want ${want})"
		fail=1
	fi
	if [ "${saved}" != "-" ]; then
		# the saved lines, as one string with real tabs and newlines
		n="$(W="$(printf '%b' "${saved}")" awk '
			{ buf = buf $0 "\n" }
			END { c = 0; s = buf; w = ENVIRON["W"]
				while ((i = index(s, w "\n")) > 0) { c++; s = substr(s, i + 1) }
				print c }' "${lib}")"
		if [ "${n}" -ne 1 ]; then
			echo "NO  (${name}: saved lib/${file} has the expected entry ${n} times, want 1)"
			fail=1
		fi
	fi
done
if [ "${fail}" -eq 0 ]; then
	echo "YES"
	exit 0
fi
exit 1
