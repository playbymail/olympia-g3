#!/bin/bash
###########################################################################
# Shared island generator selection and driver for the island gates (issue
# #292). Source this file; do not run it. It sets BIN to the island
# generator the gate runs:
#
#   ISLAND_BIN unset   build/${OLYMPIA_PRESET:-debug}/island-g3, the C
#                      reference island generator (the default).
#   ISLAND_BIN=<path>  that executable instead, e.g. a port's generator.
#                      A relative path is taken from the current directory.
#                      A missing or non-executable path is an error (exit
#                      2); it never falls back to C.
#
# The selected generator gets the same inputs and checks either way.
#
#   island_no_update "$@"
#       exit 2 if the gate was asked to --update while ISLAND_BIN is set:
#       only the default C island generator may write expected output.
#
#   island_gate "$@"
#       run every case in the gate's CASES array and compare the results
#       with the gate's EXPECT.sha256 and EXPECT.log (see below). Prints
#       YES and exits 0 on a pass; prints NO and the differences and exits
#       1 on a failure. With --update it rewrites both files instead.
#
# Each CASES entry is "name|map|randseed|stage|stage...". map and randseed
# name input files, looked up in the gate's directory and then in
# tests/island/fixtures; a randseed of "-" means none. Each stage is the
# argument list of one island run (split on blanks, no quoting; empty for
# no arguments). The first stage reads map on stdin; each later stage reads
# the previous stage's stdout, as in `island < map | island | island`. All
# stages share the case's randseed, which each one reads and advances. A
# pipeline runs its stages one after another anyway: island reads stdin to
# EOF before it loads the seed, and the stage before writes its seed before
# it prints the map. A stage that exits non-zero ends the case.
#
# Each case runs in its own empty directory, ${WORK}/<name>. Before the run,
# island_gate calls island_setup <name> <dir> when the gate defines it, so a
# gate can plant a directory where randseed goes. The generator always runs
# as argv[0] "island-g3", so its usage line does not depend on the path.
#
#   EXPECT.sha256  sha256 of every regular file the case leaves behind:
#                  each stage's stdout (out.1, out.2, ...) and the final
#                  randseed, as <name>/<file>.
#   EXPECT.log     per case and stage: the arguments, the exit status and
#                  the stage's stderr, in order.
#
# After the comparison island_gate calls island_extra when the gate defines
# it; a non-zero return fails the gate. The case directories are still
# there, so it can compare outputs across cases.
#
# Also sets PRESET (for the default generator's messages) and exports
# ISLAND_BIN as the absolute path when it was set, so gates run from a
# different directory see the same generator.
###########################################################################

ISLAND_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ISLAND_FIX="${ISLAND_ROOT}/tests/island/fixtures"
PRESET="${OLYMPIA_PRESET:-debug}"

if [ -n "${ISLAND_BIN:-}" ]; then
	case "${ISLAND_BIN}" in
	/*) BIN="${ISLAND_BIN}" ;;
	*)  BIN="${PWD}/${ISLAND_BIN}" ;;
	esac
	if [ ! -f "${BIN}" ] || [ ! -x "${BIN}" ]; then
		echo "error: ISLAND_BIN=${ISLAND_BIN} is not an executable file"
		exit 2
	fi
	export ISLAND_BIN="${BIN}"
else
	BIN="${ISLAND_ROOT}/build/${PRESET}/island-g3"
	[ -x "${BIN}" ] || { echo "error: missing ${BIN} (build the ${PRESET} preset first)"; exit 2; }
fi

island_no_update() {	# args: the gate's arguments
	local a
	[ -n "${ISLAND_BIN:-}" ] || return 0
	for a in "$@"; do
		if [ "${a}" = "--update" ]; then
			echo "error: --update with ISLAND_BIN set; only the default C island generator writes expected output"
			exit 2
		fi
	done
}

# Print the path of input file $1: the gate's own, else the shared fixture.
island_input() {
	if [ -f "${HERE}/$1" ]; then
		echo "${HERE}/$1"
	elif [ -f "${ISLAND_FIX}/$1" ]; then
		echo "${ISLAND_FIX}/$1"
	else
		echo "error: no input file $1" >&2
		exit 2
	fi
}

# Run one case: island_case <CASES entry>. Appends to ${WORK}/log.
island_case() {
	local name map seed rest="$1" args more in dir ec k=1
	name="${rest%%|*}"; rest="${rest#*|}"
	map="${rest%%|*}";  rest="${rest#*|}"
	seed="${rest%%|*}"
	case "${rest}" in
	*'|'*) rest="${rest#*|}" ;;
	*)     rest="" ;;
	esac
	dir="${WORK}/${name}"
	mkdir "${dir}" || exit 2
	in="$(island_input "${map}")" || exit 2
	if [ "${seed}" != "-" ]; then
		cp "$(island_input "${seed}")" "${dir}/randseed" || exit 2
	fi
	if declare -F island_setup >/dev/null; then
		island_setup "${name}" "${dir}" || exit 2
	fi
	while :; do
		case "${rest}" in
		*'|'*) args="${rest%%|*}"; rest="${rest#*|}"; more=1 ;;
		*)     args="${rest}"; more=0 ;;
		esac
		# shellcheck disable=SC2086	# the arguments are split on purpose
		( cd "${dir}" && exec -a island-g3 "${BIN}" ${args} <"${in}" >"${dir}/out.${k}" 2>"${WORK}/${name}.err.${k}" )
		ec=$?
		{
			echo "== ${name} stage ${k}:${args:+ ${args}}"
			echo "exit ${ec}"
			cat "${WORK}/${name}.err.${k}"
		} >>"${WORK}/log"
		[ "${ec}" -eq 0 ] && [ "${more}" -eq 1 ] || break
		in="${dir}/out.${k}"
		k=$((k + 1))
	done
}

island_gate() {	# args: the gate's arguments
	local entry rc=0
	island_no_update "$@"

	WORK="$(mktemp -d)" || exit 2
	trap 'rm -rf "${WORK:?}"' EXIT
	: >"${WORK}/log"
	for entry in "${CASES[@]}"; do
		island_case "${entry}"
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
	if declare -F island_extra >/dev/null && ! island_extra; then
		rc=1
	fi
	[ "${rc}" -eq 0 ] && echo "YES"
	return "${rc}"
}
