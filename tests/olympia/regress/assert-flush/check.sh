#!/bin/bash
###########################################################################
# Regression: an assertion failure flushes stdio first (issue #339).
#
# asfail() (olympia/z.c) prints the assertion and calls abort(). macOS's
# abort() flushes open streams and glibc's doesn't, so whatever was still
# buffered (a database file, or stdout sent to a file) survived on macOS
# and was lost on Linux. Now asfail() calls fflush(NULL) before abort(),
# so every platform keeps it. The exit status is still 134 (SIGABRT). A
# crash such as SIGSEGV is not an assertion and still flushes nothing.
#
# Extracts the shared base world, lists box 1 twice in lib/master, and
# loads it (-l, no -r, no -S) with stdout sent to a file. fast_scan() calls
# alloc_box() for box 1 twice, and the second call fails its DUP assert
# while the startup banner is still in stdout's buffer.
#
# Three checks, all required:
#   1. exit status 134;
#   2. stderr reports "alloc_box: DUP box 1" and the assertion failure;
#   3. stdout holds the startup banner's `sizeof(struct box) = N` line
#      (before the fix, on Linux: an empty file).
#
# Pass:  prints YES and exits 0.   No EXPECT files: the checks are inline.
###########################################################################
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../../../.." && pwd)"
. "${ROOT}/tests/olympia/engine.sh"
engine_no_update "$@"
WORLD="${ROOT}/tests/olympia/fixtures/world.tgz"

[ -f "${WORLD}" ] || { echo "error: missing ${WORLD} (run tests/olympia/fixtures/build-world.sh)"; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

tar zxf "${WORLD}" -C "${WORK}" || exit 2
perl -i -ne 'print; print if /^1\t4\.0\t/ && !$n++; END { exit(!$n) }' "${WORK}/lib/master" \
	|| { echo "error: lib/master has no entry for box 1"; exit 2; }

# the outer 2>/dev/null drops the shell's own "Abort trap" notice
( cd "${WORK}" && "${BIN}" -l ./lib </dev/null >"${WORK}/out" 2>"${WORK}/err" ) 2>/dev/null
ec=$?

fail=0
if [ "${ec}" -ne 134 ]; then
	echo "NO  (load exited ${ec}, want 134)"
	fail=1
fi
if ! grep -q '^alloc_box: DUP box 1$' "${WORK}/err" ||
   ! grep -q '^assertion failure: ' "${WORK}/err"; then
	echo "NO  (stderr does not report the DUP box 1 assertion)"
	fail=1
fi
if ! grep -q '^	sizeof(struct box) = [0-9]*$' "${WORK}/out"; then
	echo "NO  (stdout lost the startup banner: $(wc -c <"${WORK}/out") bytes)"
	fail=1
fi
if [ "${fail}" -eq 0 ]; then
	echo "YES"
	exit 0
fi
exit 1
