#!/bin/bash
###########################################################################
# Regression: the -R self-test draws in a fixed order (issue #241).
#
# On a terminal, test_random() (olympia/z.c) prints its first 100 draws as
# a 10x10 grid. It used to pass ten rng_draw() calls to one printf(), so the
# order within each row was the compiler's argument-evaluation order, which
# C leaves unspecified (right to left on x86-64 GCC, left to right on clang).
# Now each row is drawn into an array first, in order.
#
# -R runs before any DB is loaded, so its stream is rooted at the all-zero
# master seed: no lib or scenario is needed. Two checks, both required:
#   1. EXPECT.txt: the non-tty output (one draw per line), byte for byte;
#   2. the tty output, with the grid read row by row, is the same as the
#      non-tty output: the grid shows the same draws in draw order.
# Check 2 runs -R under a pseudo-terminal (python3's pty module).
#
# Pass:  prints YES and exits 0.   Re-baseline: ./check.sh --update
###########################################################################
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../../../.." && pwd)"
. "${ROOT}/tests/olympia/engine.sh"
engine_no_update "$@"

command -v python3 >/dev/null || { echo "error: python3 is needed to run -R on a pty"; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

( cd "${WORK}" && "${BIN}" -R </dev/null >"${WORK}/plain.txt" 2>&1 )
ec=$?
if [ "${ec}" -ne 0 ]; then
	echo "NO  (olympia-g3 -R failed: exit ${ec})"
	exit 1
fi

if [ "${1:-}" = "--update" ]; then
	cp "${WORK}/plain.txt" "${HERE}/EXPECT.txt"
	echo "updated ${HERE}/EXPECT.txt"
	exit 0
fi

# Run -R with stdout on a pty; print what it wrote with the CRs dropped.
( cd "${WORK}" && python3 -I -c '
import os, pty, sys
pid, fd = pty.fork()
if pid == 0:
	os.execv(sys.argv[1], [sys.argv[1], "-R"])
out = b""
while True:
	try:
		d = os.read(fd, 4096)
	except OSError:
		break
	if not d:
		break
	out += d
_, st = os.waitpid(pid, 0)
sys.stdout.write(out.decode().replace("\r", ""))
sys.exit(os.waitstatus_to_exitcode(st))
' "${BIN}" >"${WORK}/tty.txt" )
ec=$?
if [ "${ec}" -ne 0 ]; then
	echo "NO  (olympia-g3 -R on a pty failed: exit ${ec})"
	exit 1
fi

# The grid is the run of lines of ten numbers; split it one number per line.
awk 'NF == 10 && $0 ~ /^[ 0-9]+$/ { for (i = 1; i <= NF; i++) print $i; next } { print }' \
	"${WORK}/tty.txt" >"${WORK}/tty-flat.txt"

fail=0
if ! diff -u "${HERE}/EXPECT.txt" "${WORK}/plain.txt" >/dev/null; then
	echo "NO  (-R output changed vs EXPECT.txt)"
	diff -u "${HERE}/EXPECT.txt" "${WORK}/plain.txt"
	fail=1
fi
if ! diff -u "${WORK}/plain.txt" "${WORK}/tty-flat.txt" >/dev/null; then
	echo "NO  (the tty grid is not the draws in draw order)"
	diff -u "${WORK}/plain.txt" "${WORK}/tty-flat.txt"
	fail=1
fi
if [ "${fail}" -eq 0 ]; then
	echo "YES"
	exit 0
fi
exit 1
