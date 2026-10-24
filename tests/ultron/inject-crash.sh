#!/bin/bash
# Test engine for the loop driver (tests/ultron/loop.py --engine).
#
# Runs build/$OLYMPIA_PRESET/olympia-g3 unchanged, except that a turn run (-r)
# whose order files hold an "ultron-crash" order aborts the way a failed
# assert does. This plants a crash that depends only on the order files, so
# the loop's freeze-and-replay path can be tested without a real engine bug:
#
#   tests/ultron/loop.py --scenario ... --engine tests/ultron/inject-crash.sh \
#       --inject 2:400:4126:ultron-crash
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BIN="${ROOT}/build/${OLYMPIA_PRESET:-debug}/olympia-g3"

lib=./lib run=0 prev=
for a in "$@"; do
	[ "${prev}" = "-l" ] && lib="${a}"
	[ "${a}" = "-r" ] && run=1
	prev="${a}"
done

if [ "${run}" -eq 1 ] && grep -qs '^[0-9-]*:ultron-crash' "${lib}"/orders/*; then
	echo "Assertion failed: (injected ultron-crash order), function main, file inject-crash.sh, line 1." >&2
	kill -ABRT $$
fi
exec "${BIN}" "$@"
