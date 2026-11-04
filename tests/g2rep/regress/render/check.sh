#!/bin/bash
###########################################################################
# Regression: g2rep renders report markup exactly as the original (#368).
#
# Each file in input/ is a raw report as the engine writes it
# (who:html:unit:indent[/second-indent]:day:text lines):
#
#   golden-205           a full player report from the golden run
#   combat-attack-300    a battle report (regress/combat-attack)
#   governance-rule-301  day prefixes, unit prefixes, second indents and
#                        {html|text} spans (regress/governance-rule)
#   confirmation-203     an order confirmation from `-E` (lib/log/203):
#                        mail headers, errors, queued orders, the original
#                        message
#   edge-cases           hand-written: hanging indent, unit + day prefix,
#                        sentence spacing, quotes, '~', an unbreakable word,
#                        an empty include, html-only and text-only lines
#
# Each is rendered in text mode (EXPECT/<name>.txt) and with -h
# (EXPECT/<name>.html), and the run must write nothing to stderr and exit 0.
# The usage cases pin the exit status and the stderr of a missing operand,
# an extra operand and an unreadable file (EXPECT/usage.log).
#
# The expected files are written by the ORIGINAL rep.c (tests/g2rep/oracle),
# not by the port, so the port is held to the original's output.
#
# Pass:  prints YES and exits 0.   Re-baseline: ./check.sh --update
###########################################################################
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${HERE}/../../g2rep.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

RENDER="${BIN}"
if [ "${1:-}" = "--update" ]; then
	RENDER="$(g2rep_oracle "${WORK}")" || exit 2
	mkdir -p "${HERE}/EXPECT"
	OUT="${HERE}/EXPECT"
else
	OUT="${WORK}/got"
	mkdir -p "${OUT}"
fi

fail=0
for f in "${HERE}"/input/*; do
	name="$(basename "${f}")"
	for mode in txt html; do
		flag=""
		[ "${mode}" = "html" ] && flag="-h"
		# Run from the input directory with a bare file name, so the
		# program name and path never reach the output.
		( cd "${HERE}/input" && "${RENDER}" ${flag} "${name}" ) \
			>"${OUT}/${name}.${mode}" 2>"${WORK}/err"
		ec=$?
		if [ "${ec}" -ne 0 ] || [ -s "${WORK}/err" ]; then
			echo "NO  (${name} ${mode}: exit ${ec}, stderr:)"
			cat "${WORK}/err"
			fail=1
		fi
	done
done

# Usage errors. The usage line prints argv[0], so run the formatter through
# a fixed name to keep the log independent of where the binary lives.
ln -s "${RENDER}" "${WORK}/g2rep"
{
	for args in "" "a b" "no-such-file"; do
		echo "== g2rep ${args}"
		# shellcheck disable=SC2086 # split the case's arguments
		( cd "${WORK}" && PATH="${WORK}:${PATH}" g2rep ${args} ) 2>&1 >/dev/null
		echo "exit $?"
	done
} >"${OUT}/usage.log"

if [ "${1:-}" = "--update" ]; then
	echo "updated ${HERE}/EXPECT from the original rep.c"
	exit 0
fi

if ! diff -r "${HERE}/EXPECT" "${OUT}" >/dev/null; then
	echo "NO  (output differs from EXPECT)"
	diff -ru "${HERE}/EXPECT" "${OUT}" | head -60
	fail=1
fi

if [ "${fail}" -eq 0 ]; then
	echo "YES"
	exit 0
fi
exit 1
