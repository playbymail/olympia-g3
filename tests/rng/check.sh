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
# It also enforces the issue #25 EXIT CRITERION as a standing gate: after the
# mint migration (Unit F, the last) the engine has ZERO gameplay/world-build
# draws on the process-global rnd() -- it survives only as the low-level MD5
# primitive the rng layer is built on. The audit grep below must therefore find
# NO rnd() call site anywhere in the engine sources (olympia/*.c), excluding
# lib/rnd.c's own definition and comment lines. A future stray rnd() in game
# logic fails this gate (and so re-opens #25).
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

if ! "${BIN}"; then
	exit $?
fi

###########################################################################
# Standing no-gameplay-rnd() audit (issue #25 exit criterion).
#
# The same grep the #25 endgame plan defines: every live rnd() call site in the
# engine sources, minus lib/rnd.c's own definition and comment lines. After
# Unit F (mint) this must be EMPTY -- the entity-id allocator, the add-player
# id/password draws, and the -R self-test were the last holdouts, and the dead
# rnd() blocks were deleted. (Indirect lib-helper draws -- ilist_scramble /
# exit_views_scramble -- were also migrated onto streams in Unit F; this grep
# guards the direct call sites that define the criterion.)
###########################################################################
AUDIT="$(grep -rnE '[^_a-zA-Z]rnd\(' "${ROOT}"/olympia/*.c \
	| grep -v 'olympia/rnd.c' \
	| grep -vE ':[[:space:]]*\*|//' || true)"

if [ -n "${AUDIT}" ]; then
	echo "NO  (issue #25: gameplay rnd() call site(s) remain in olympia/*.c)"
	echo "${AUDIT}"
	exit 1
fi

echo "YES  (no-gameplay-rnd() audit: clean)"
exit 0
