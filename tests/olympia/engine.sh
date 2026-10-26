#!/bin/bash
###########################################################################
# Shared engine selection for the olympia gates (issue #269). Source this
# file; do not run it. It sets BIN to the engine the gate runs:
#
#   OLYMPIA_ENGINE_BIN unset   build/${OLYMPIA_PRESET:-debug}/olympia-g3,
#                              the C reference engine (the default).
#   OLYMPIA_ENGINE_BIN=<path>  that executable instead, e.g. a port's engine.
#                              A relative path is taken from the current
#                              directory. A missing or non-executable path is
#                              an error (exit 2); it never falls back to C.
#
# The selected engine gets the same arguments, inputs and checks either way.
#
#   engine_no_update "$@"
#       exit 2 if the gate was asked to --update while OLYMPIA_ENGINE_BIN is
#       set: only the default C engine may write expected output.
#
# Also sets PRESET (for the default engine's messages) and exports
# OLYMPIA_ENGINE_BIN as the absolute path when it was set, so gates run
# from a different directory see the same engine.
###########################################################################

ENGINE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PRESET="${OLYMPIA_PRESET:-debug}"

if [ -n "${OLYMPIA_ENGINE_BIN:-}" ]; then
	case "${OLYMPIA_ENGINE_BIN}" in
	/*) BIN="${OLYMPIA_ENGINE_BIN}" ;;
	*)  BIN="${PWD}/${OLYMPIA_ENGINE_BIN}" ;;
	esac
	if [ ! -f "${BIN}" ] || [ ! -x "${BIN}" ]; then
		echo "error: OLYMPIA_ENGINE_BIN=${OLYMPIA_ENGINE_BIN} is not an executable file"
		exit 2
	fi
	export OLYMPIA_ENGINE_BIN="${BIN}"
else
	BIN="${ENGINE_ROOT}/build/${PRESET}/olympia-g3"
	[ -x "${BIN}" ] || { echo "error: missing ${BIN} (build the ${PRESET} preset first)"; exit 2; }
fi

engine_no_update() {	# args: the gate's arguments
	local a
	[ -n "${OLYMPIA_ENGINE_BIN:-}" ] || return 0
	for a in "$@"; do
		if [ "${a}" = "--update" ]; then
			echo "error: --update with OLYMPIA_ENGINE_BIN set; only the default C engine writes expected output"
			exit 2
		fi
	done
}
