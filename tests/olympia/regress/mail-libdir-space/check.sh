#!/bin/bash
###########################################################################
# Regression: mailing and HTML reports with a libdir holding a space
# (issues #325, #326).
#
# send_rep(), eat(), setup_html_dir(), set_html_pass(), output_html_rep()
# and copy_public_turns() built shell commands from paths under the libdir
# without quoting them, so with -l "./my lib" every command saw "./my" and
# "lib/..." as two words. sendmail -f got all of from_host, comment
# included, and set_html_pass() put the player's password on the command
# line inside "...". Now each path is quoted with sh_quote(), sendmail -f
# gets sender_addr(from_host), htpasswd reads the password on stdin (-i),
# and the -w mkdir and the public-turn copy run without the shell.
#
# Stub g2rep, zcat, sendmail, htpasswd and unexpand go first on PATH. Each
# logs one line: its arguments, one [word] each, then for sendmail and
# htpasswd "<" and the first bytes of its stdin. The player-settings scenario (its player 300
# has an email and a public turn) is extracted into "my lib", with
# htpasswd_loc moved under "my lib" and player 300's password set to text
# the shell would run. Three runs:
#   A. -r -S -M -h       a turn, then mail_reports() and setup_html_all();
#   B. -M                after gzipping save/1/300: send_rep()'s zcat path;
#   C. -E -M             one spooled order message: eat()'s ack.
#
# Checks, all required:
#   1. every run exits 0;
#   2. the stubs' log matches EXPECT.calls (the work dir is written @WORK@);
#   3. the shell ran nothing from the password (no PWNED files);
#   4. html/300/index.html holds g2rep -h's output, and public/1.300 holds
#      it up to the order-template line.
#
# Pass:  prints YES and exits 0.   Re-baseline: ./check.sh --update
###########################################################################
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../../../.." && pwd)"
. "${ROOT}/tests/olympia/engine.sh"
engine_no_update "$@"
. "${ROOT}/tests/olympia/fixtures/scenario.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
scenario_unpack "${ROOT}/tests/olympia/regress/player-settings" "${WORK}" || exit 2

LIB="${WORK}/my lib"
mv "${WORK}/lib" "${LIB}" && mkdir "${WORK}/bin" "${WORK}/public" \
	"${LIB}/html" "${LIB}/spool" || exit 2

for t in g2rep zcat sendmail htpasswd unexpand; do
	cat >"${WORK}/bin/${t}" <<'EOF'
#!/bin/sh
n=$(basename "$0")
line="$n"
for a in "$@"; do line="$line [$a]"; f="$a"; done
case "$n" in
sendmail|htpasswd)
	line="$line < $(head -c 60 | tr '\n' '|')" ;;
esac
printf '%s\n' "$line" >>"$CALLS"
case "$n" in
g2rep)	if [ "$1" = "-h" ]; then
		printf 'report %s\n<name="Order template">\norders\n' "$f"
	else
		cat "$f"
	fi ;;
zcat)	gzip -dc "$f" ;;
sendmail|htpasswd) ;;
*)	cat ;;
esac
EOF
	chmod +x "${WORK}/bin/${t}" || exit 2
done

PW='x"$(touch PWNED)`touch PWNED2`'"'"'y'
awk -v pw="${PW}" '/^ pw / { print " pw " pw; next } { print }' \
	"${LIB}/fact/300" >"${WORK}/fact.new" && mv "${WORK}/fact.new" "${LIB}/fact/300" || exit 2
awk -v loc="${LIB}/ht passwords" '/^htpasswd_loc=/ { print "htpasswd_loc=" loc; next } { print }' \
	"${LIB}/system" >"${WORK}/system.new" && mv "${WORK}/system.new" "${LIB}/system" || exit 2
grep -qF " pw ${PW}" "${LIB}/fact/300" || { echo "error: could not set player 300's password"; exit 2; }

run() {		# args: name, engine flags...
	local name="$1"; shift
	: >"${WORK}/calls.${name}"
	( cd "${WORK}" && export CALLS="${WORK}/calls.${name}" &&
		PATH="${WORK}/bin:${PATH}" "${BIN}" -l "./my lib" "$@" \
		</dev/null >"${WORK}/${name}.out" 2>&1 )
	ec=$?
	if [ "${ec}" -ne 0 ]; then
		echo "NO  (run ${name} exited ${ec}, want 0)"
		exit 1
	fi
}

run A -r -S -M -h test-use-const-report-date
gzip "${LIB}/save/1/300" || exit 2
run B -M
printf '%s\n' 'From p@example.com Mon Oct 26 00:00:00 2026' 'From: p@example.com' \
	'Subject: orders' '' 'begin 300 "nope"' 'end' >"${LIB}/spool/m1"
run C -E -M

calls() {	# C's ack is a pipeline, so its stubs log in either order
	local n
	for n in A B C; do
		echo "== ${n}"
		if [ "${n}" = C ]; then sort "${WORK}/calls.${n}"; else cat "${WORK}/calls.${n}"; fi
	done | sed "s|${WORK}|@WORK@|g"
}

if [ "${1:-}" = "--update" ]; then
	calls >"${HERE}/EXPECT.calls"
	echo "updated ${HERE}/EXPECT.calls"
	exit 0
fi

fail=0
if ! diff -u "${HERE}/EXPECT.calls" <(calls) >/dev/null; then
	echo "NO  (stub calls changed vs EXPECT.calls)"
	diff -u "${HERE}/EXPECT.calls" <(calls)
	fail=1
fi
for f in PWNED PWNED2; do
	if [ -e "${WORK}/${f}" ]; then
		echo "NO  (the shell ran the password: ${f} exists)"
		fail=1
	fi
done
want='report ./my lib/save/1/300'
if [ "$(head -1 "${LIB}/html/300/index.html" 2>/dev/null)" != "${want}" ]; then
	echo "NO  (html/300/index.html does not start with: ${want})"
	fail=1
fi
if [ "$(cat "${WORK}/public/1.300" 2>/dev/null)" != "${want}" ]; then
	echo "NO  (public/1.300 is not just: ${want})"
	fail=1
fi
if [ "${fail}" -eq 0 ]; then
	echo "YES"
	exit 0
fi
exit 1
