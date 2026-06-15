#!/bin/bash
###########################################################################
# Self-check for the prototype rng_* layer (issue #25 groundwork).
#
# Compiles tests/rng/rng_check.c against lib/rng.c + lib/rnd.c (the MD5
# primitive) and runs it. The driver asserts the three design claims the
# layer is meant to deliver -- determinism, keyed independence, and
# order-independent stream derivation -- so a regression in the prototype
# shows up here WITHOUT touching the engine or the golden manifest.
#
# This does NOT use a built preset; it compiles the two .c files directly,
# so it works regardless of which target the layer is linked into.
#
# Pass: prints YES and exits 0.   Fail: prints NO and exits nonzero.
###########################################################################
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../.." && pwd)"
CC="${CC:-cc}"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

BIN="${WORK}/rng_check"
# No -Wall/-Wextra here: the project's CMake ladder already enforces warnings
# on lib/rng.c; this driver only checks behavior, and -Wextra would surface
# pre-existing legacy idioms in lib/rnd.c that are out of scope.
"${CC}" -std=c11 -I "${ROOT}/lib" \
	"${HERE}/rng_check.c" "${ROOT}/lib/rng.c" "${ROOT}/lib/rnd.c" \
	-o "${BIN}" || { echo "NO  (rng_check failed to compile)"; exit 2; }

"${BIN}"
exit $?
