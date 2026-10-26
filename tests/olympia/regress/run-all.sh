#!/bin/bash
###########################################################################
# Run the olympia regress fixtures and report each one (issue #269).
#
#   ./run-all.sh              every fixture's check.sh
#   ./run-all.sh name...      just those fixtures (directory names)
#
# Runs the engine that tests/olympia/engine.sh selects: the C engine at
# build/${OLYMPIA_PRESET:-debug}/olympia-g3, or OLYMPIA_ENGINE_BIN=<path>.
# check-lua.sh is not run: it authors the scenario with olyscript-g3, which
# only the C tree has; check.sh replays the frozen scenario instead.
#
# Prints one line per fixture, then a summary:
#   PASS  <name>     check.sh printed YES (exit 0)
#   FAIL  <name>     output differs from the expected files (exit 1)
#   ERROR <name>     the check could not run: missing input, bad engine
#                    path, ... (exit 2 or anything else)
# and the check's own output, indented, under each FAIL or ERROR.
# Exits 0 when every fixture passed, else 1.
###########################################################################
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../../.." && pwd)"
. "${ROOT}/tests/olympia/engine.sh"
case " $* " in
*" --update "*) echo "error: run-all.sh does not re-baseline; run that fixture's check.sh --update"; exit 2 ;;
esac

if [ $# -gt 0 ]; then
	names=("$@")
else
	names=()
	for d in "${HERE}"/*/; do
		[ -f "${d}check.sh" ] && names+=("$(basename "${d}")")
	done
fi

echo "engine: ${BIN}"
pass=0 fail=0 error=0
for n in "${names[@]}"; do
	if [ ! -f "${HERE}/${n}/check.sh" ]; then
		echo "ERROR ${n}"
		echo "      no such fixture: ${HERE}/${n}/check.sh"
		error=$((error + 1))
		continue
	fi
	out="$("${HERE}/${n}/check.sh" 2>&1)"
	ec=$?
	case "${ec}" in
	0) echo "PASS  ${n}"; pass=$((pass + 1)); continue ;;
	1) echo "FAIL  ${n}"; fail=$((fail + 1)) ;;
	*) echo "ERROR ${n} (exit ${ec})"; error=$((error + 1)) ;;
	esac
	printf '%s\n' "${out}" | sed 's/^/      /'
done

echo "pass ${pass}  fail ${fail}  error ${error}"
[ "${fail}" -eq 0 ] && [ "${error}" -eq 0 ]
