#!/bin/bash
###########################################################################
# Shared world generator selection and driver for the genesis gates (issue
# #290). Source this file; do not run it. It sets BIN to the generator the
# gate runs:
#
#   GENESIS_BIN unset   build/${OLYMPIA_PRESET:-debug}/genesis-g3, the C
#                       reference world generator (the default).
#   GENESIS_BIN=<path>  that executable instead, e.g. a port's generator.
#                       A relative path is taken from the current directory.
#                       A missing or non-executable path is an error (exit
#                       2); it never falls back to C.
#
# The selected generator gets the same arguments and checks either way.
#
#   genesis_no_update "$@"
#       exit 2 if the gate was asked to --update while GENESIS_BIN is set:
#       only the default C generator may write expected output.
#
#   genesis_gate "$@"
#       run every case in the gate's CASES array and compare the results
#       with the gate's EXPECT.sha256 and EXPECT.log (see below). Prints
#       YES and exits 0 on a pass; prints NO and the differences and exits
#       1 on a failure. With --update it rewrites both files instead.
#
# Each CASES entry is "name|arguments". The arguments are split on blanks
# (no quoting). Each case runs in its own empty directory, ${WORK}/<name>.
# Before the run, genesis_gate calls genesis_setup <name> <dir> when the gate
# defines it, so a gate can plant a directory where an output file goes.
#
#   EXPECT.sha256  sha256 of every regular file the case leaves behind
#                  (Map, Regions, Land, Cities, randseed, any --image BMP),
#                  as <name>/<file>.
#   EXPECT.log     per case: the arguments, the exit status and genesis's
#                  stderr, in order. stdout must be empty.
#
# After the comparison genesis_gate calls genesis_extra when the gate defines
# it; a non-zero return fails the gate. The case directories are still
# there, so it can compare outputs across cases.
#
# Also sets PRESET (for the default generator's messages) and exports
# GENESIS_BIN as the absolute path when it was set, so gates run from a
# different directory see the same generator.
###########################################################################

GENESIS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PRESET="${OLYMPIA_PRESET:-debug}"

if [ -n "${GENESIS_BIN:-}" ]; then
	case "${GENESIS_BIN}" in
	/*) BIN="${GENESIS_BIN}" ;;
	*)  BIN="${PWD}/${GENESIS_BIN}" ;;
	esac
	if [ ! -f "${BIN}" ] || [ ! -x "${BIN}" ]; then
		echo "error: GENESIS_BIN=${GENESIS_BIN} is not an executable file"
		exit 2
	fi
	export GENESIS_BIN="${BIN}"
else
	BIN="${GENESIS_ROOT}/build/${PRESET}/genesis-g3"
	[ -x "${BIN}" ] || { echo "error: missing ${BIN} (build the ${PRESET} preset first)"; exit 2; }
fi

genesis_no_update() {	# args: the gate's arguments
	local a
	[ -n "${GENESIS_BIN:-}" ] || return 0
	for a in "$@"; do
		if [ "${a}" = "--update" ]; then
			echo "error: --update with GENESIS_BIN set; only the default C generator writes expected output"
			exit 2
		fi
	done
}

# Run one case: genesis_case <name> <arguments>. Appends to ${WORK}/log.
genesis_case() {
	local name="$1" args="$2" dir="${WORK}/$1" ec
	mkdir "${dir}" || exit 2
	if declare -F genesis_setup >/dev/null; then
		genesis_setup "${name}" "${dir}" || exit 2
	fi
	# shellcheck disable=SC2086	# the arguments are split on purpose
	( cd "${dir}" && "${BIN}" ${args} >"${WORK}/${name}.out" 2>"${WORK}/${name}.err" )
	ec=$?
	{
		echo "== ${name}:${args:+ ${args}}"
		echo "exit ${ec}"
		cat "${WORK}/${name}.err"
		if [ -s "${WORK}/${name}.out" ]; then
			echo "-- stdout"
			cat "${WORK}/${name}.out"
		fi
	} >>"${WORK}/log"
}

genesis_gate() {	# args: the gate's arguments
	local entry rc=0
	genesis_no_update "$@"

	WORK="$(mktemp -d)" || exit 2
	trap 'rm -rf "${WORK:?}"' EXIT
	: >"${WORK}/log"
	for entry in "${CASES[@]}"; do
		genesis_case "${entry%%|*}" "${entry#*|}"
	done

	manifest() {
		( cd "${WORK}" && find . -mindepth 2 -type f | sed 's|^\./||' |
			LC_ALL=C sort | while IFS= read -r f; do shasum -a 256 "${f}"; done )
	}

	if [ "${1:-}" = "--update" ]; then
		manifest >"${HERE}/EXPECT.sha256"
		cp "${WORK}/log" "${HERE}/EXPECT.log"
		echo "updated ${HERE}/EXPECT.sha256 and EXPECT.log"
		return 0
	fi

	if ! diff -u "${HERE}/EXPECT.log" "${WORK}/log" >"${WORK}/log.diff"; then
		echo "NO  (exit status or stderr changed vs EXPECT.log)"
		cat "${WORK}/log.diff"
		rc=1
	fi
	if ! diff -u "${HERE}/EXPECT.sha256" <(manifest) >"${WORK}/sha.diff"; then
		echo "NO  (output changed vs EXPECT.sha256)"
		cat "${WORK}/sha.diff"
		rc=1
	fi
	if declare -F genesis_extra >/dev/null && ! genesis_extra; then
		rc=1
	fi
	[ "${rc}" -eq 0 ] && echo "YES"
	return "${rc}"
}
