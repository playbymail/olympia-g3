#!/bin/bash
###########################################################################
# Regression: numbers in a box file are read whole (issue #342).
#
# The list scanners in olympia/io.c (skill, item, trade and req lists),
# olytime_scan (a char's dt and the sysclock line) and a command's ar
# line read their numbers with sscanf("%d ..."). How long a number that
# reads is up to the C library: for 512 zeros then 1, macOS read 0 and
# left the 1 for the next field, while glibc read 1. Now scan_ints()
# reads each number as strtoll(s, &end, 10) does, on every platform:
# leading whitespace, an optional sign, then decimal digits; past the
# long long range it is LLONG_MAX or LLONG_MIN, and the int keeps the low
# 32 bits (the shorts in an olytime keep the low 16). Below 512 characters
# this is what both C libraries read.
#
# Each case extracts the shared base world, edits one lib file with a perl
# program, then loads and saves the DB (-S, no -r). In the program, $z is
# 512 zeros, $n is 600 nines, and pad() puts $z in front of every number
# in a string.
#
# Checks per case, all required:
#   1. the run exits 0 with no AddressSanitizer or UBSan report;
#   2. stderr has the case's report exactly once (or no list_scan report,
#      if "-");
#   3. "same": the saved file is byte for byte the file a load and save of
#      the unedited world writes (the padded numbers read as they were);
#      otherwise the saved file has the case's line exactly once, or the
#      check is skipped for "-".
#
# Pass:  prints YES and exits 0.   No EXPECT files: the checks are inline.
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

# The unedited world, loaded and saved: what the "same" cases compare with.
REF="${WORK}/ref"
mkdir "${REF}" && tar zxf "${WORLD}" -C "${REF}" || exit 2
( cd "${REF}" && "${BIN}" -l ./lib -S </dev/null >/dev/null 2>&1 )
ec=$?
if [ "${ec}" -ne 0 ]; then
	echo "NO  (load and save of the unedited world exited ${ec}, want 0)"
	exit 1
fi

# Pads the first entry (a line and its continuation line) with the tag.
# readlin() cuts a line at LEN - 1 (2047) characters on every platform,
# so a padded line keeps to three padded numbers.
PAD='s/^(TAG.*\n.*)$/pad($1)/me'
# Appends text before the blank line that ends a box file.
END='s/\n\n\z/\n'

# name|file under lib|perl -0p program|stderr report|saved line, "same" or "-"
CASES=(
	"item-pad|loc|${PAD/TAG/il\\t}|-|same"
	"trade-pad|loc|s/^(tl\\t\\d+ \\d+ \\d+)/pad(\$1)/me|-|same"
	"req-pad|skill|${PAD/TAG/ rq\\t}|-|same"
	"args-pad|fact/200|s/^ ar 0 0 0 0 0 0 0 0\$/ ar \${z}1 \${z}2 \${z}3 4 5 6 7 8/m|-| ar 1 2 3 4 5 6 7 8"
	"item-plus|item|${END}il +\${z}1 5\n\n/|-|il\t1 5"
	"item-minus|item|${END}il -\${z}1 5\n\n/|item_list_scan(403): bad item -1|-"
	"item-wrap|item|${END}il 4294967297 5\n\n/|-|il\t1 5"
	"item-overflow|item|${END}il \${n} 5\n\n/|item_list_scan(403): bad item -1|-"
	"item-underflow|item|${END}il -\${n} 5\n\n/|item_list_scan(403): bad item 0|-"
	"skill-pad|fact/207|${END}CH\n sl \${z}920 \${z}2 \${z}3\n\n/|-| sl\t920 2 3 0 0"
	"death-pad|fact/207|${END}CH\n dt \${z}2 \${z}3 \${z}4\n\n/|-| dt 2 3 4"
	"death-wrap|fact/207|${END}CH\n dt 65538 -65533 4\n\n/|-| dt 2 3 4"
	"sysclock-pad|system|\$_ .= \"sysclock: \${z}2 \${z}3 \${z}4\n\"|-|sysclock: 2 3 4"
)

fail=0
for c in "${CASES[@]}"; do
	IFS='|' read -r name file prog report saved <<<"${c}"
	dir="${WORK}/${name}"
	mkdir "${dir}" && tar zxf "${WORLD}" -C "${dir}" || exit 2
	lib="${dir}/lib/${file}"
	cp -p "${lib}" "${WORK}/${name}.orig" || exit 2
	perl -0pi -e '
		my $z = "0" x 512;
		my $n = "9" x 600;
		sub pad { my $s = shift; $s =~ s/(\d+)/$z$1/g; return $s }
	'"${prog}" "${lib}" || exit 2
	if cmp -s "${WORK}/${name}.orig" "${lib}"; then
		echo "error: ${name}: the perl program did not change lib/${file}"
		exit 2
	fi

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
		grep 'list_scan(' "${dir}/err" | cut -c 1-80
		fail=1
	fi
	if [ "${saved}" = "same" ]; then
		if ! cmp -s "${REF}/lib/${file}" "${lib}"; then
			echo "NO  (${name}: saved lib/${file} differs from the unedited world's)"
			diff "${REF}/lib/${file}" "${lib}" | cut -c 1-80 | head -6
			fail=1
		fi
	elif [ "${saved}" != "-" ]; then
		line="$(printf '%b' "${saved}")"
		n="$(grep -cxF -- "${line}" "${lib}")"
		if [ "${n}" -ne 1 ]; then
			echo "NO  (${name}: saved lib/${file} has \"${saved}\" ${n} times, want 1)"
			fail=1
		fi
	fi
done
if [ "${fail}" -eq 0 ]; then
	echo "YES"
	exit 0
fi
exit 1
