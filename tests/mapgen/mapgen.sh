#!/bin/bash
###########################################################################
# Shared map generator selection for the mapgen gates (issue #276). Source
# this file; do not run it. It sets BIN to the map generator the gate runs:
#
#   MAPGEN_BIN unset   build/${OLYMPIA_PRESET:-debug}/mapgen-g3, the C
#                      reference map generator (the default).
#   MAPGEN_BIN=<path>  that executable instead, e.g. a port's map generator.
#                      A relative path is taken from the current directory.
#                      A missing or non-executable path is an error (exit 2);
#                      it never falls back to C.
#
# The selected generator gets the same inputs and checks either way.
#
#   mapgen_no_update "$@"
#       exit 2 if the gate was asked to --update while MAPGEN_BIN is set:
#       only the default C map generator may write expected output.
#
# Also sets PRESET (for the default generator's messages) and exports
# MAPGEN_BIN as the absolute path when it was set, so gates run from a
# different directory see the same generator.
###########################################################################

MAPGEN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PRESET="${OLYMPIA_PRESET:-debug}"

if [ -n "${MAPGEN_BIN:-}" ]; then
	case "${MAPGEN_BIN}" in
	/*) BIN="${MAPGEN_BIN}" ;;
	*)  BIN="${PWD}/${MAPGEN_BIN}" ;;
	esac
	if [ ! -f "${BIN}" ] || [ ! -x "${BIN}" ]; then
		echo "error: MAPGEN_BIN=${MAPGEN_BIN} is not an executable file"
		exit 2
	fi
	export MAPGEN_BIN="${BIN}"
else
	BIN="${MAPGEN_ROOT}/build/${PRESET}/mapgen-g3"
	[ -x "${BIN}" ] || { echo "error: missing ${BIN} (build the ${PRESET} preset first)"; exit 2; }
fi

mapgen_no_update() {	# args: the gate's arguments
	local a
	[ -n "${MAPGEN_BIN:-}" ] || return 0
	for a in "$@"; do
		if [ "${a}" = "--update" ]; then
			echo "error: --update with MAPGEN_BIN set; only the default C map generator writes expected output"
			exit 2
		fi
	done
}
