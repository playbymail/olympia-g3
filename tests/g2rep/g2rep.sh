#!/bin/bash
###########################################################################
# Shared report formatter selection for the g2rep gates (issue #368).
# Source this file; do not run it. It sets BIN to the formatter the gate
# runs:
#
#   G2REP_BIN unset   build/${OLYMPIA_PRESET:-debug}/g2rep, the C port in
#                     tools/g2rep (the default).
#   G2REP_BIN=<path>  that executable instead, e.g. a port's formatter.
#                     A relative path is taken from the current directory.
#                     A missing or non-executable path is an error (exit
#                     2); it never falls back to C.
#
#   g2rep_oracle <dir>
#       build the original rep.c (tests/g2rep/oracle) into <dir>/rep-orig
#       with permissive legacy flags and print its path. Expected output is
#       written only by the oracle, never by the port under test, so
#       --update pins the original program's behavior.
#
# Also sets PRESET and G2REP_ROOT, and exports G2REP_BIN as the absolute
# path when it was set.
###########################################################################

G2REP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PRESET="${OLYMPIA_PRESET:-debug}"

if [ -n "${G2REP_BIN:-}" ]; then
	case "${G2REP_BIN}" in
	/*) BIN="${G2REP_BIN}" ;;
	*)  BIN="${PWD}/${G2REP_BIN}" ;;
	esac
	if [ ! -f "${BIN}" ] || [ ! -x "${BIN}" ]; then
		echo "error: G2REP_BIN=${G2REP_BIN} is not an executable file"
		exit 2
	fi
	export G2REP_BIN="${BIN}"
else
	BIN="${G2REP_ROOT}/build/${PRESET}/g2rep"
	[ -x "${BIN}" ] || { echo "error: missing ${BIN} (build the ${PRESET} preset first)"; exit 2; }
fi

g2rep_oracle() {	# args: build directory
	local out="$1/rep-orig"
	# The original is K&R C (implicit int, implicit declarations); build it
	# as gnu89 with every warning off. It is a test oracle, not shipped.
	"${CC:-cc}" -std=gnu89 -w -o "${out}" "${G2REP_ROOT}/tests/g2rep/oracle/rep.c" \
		|| { echo "error: could not build the g2rep oracle" >&2; return 1; }
	echo "${out}"
}
