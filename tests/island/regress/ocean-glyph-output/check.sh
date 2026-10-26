#!/bin/bash
###########################################################################
# Regression: exact output for each ocean glyph (issue #292).
#
# The ocean-glyphs gate checks only invariants. This one pins the exact map
# and randseed for an all-ocean 20x20 map of each glyph mapgen treats as ocean
# (; , : . ~ space " '), with -c 3 and the ocean-glyphs seed. Placement is
# glyph-independent, so the island is the same in each; only the ocean glyph
# differs.
#
# Runs each case in CASES in its own empty directory and checks the exit
# status and stderr (EXPECT.log), and every stage's stdout and the final
# randseed (EXPECT.sha256). See tests/island/island.sh.
#
# Pass:  prints YES and exits 0.   Update: ./check.sh --update (C build only)
###########################################################################
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${HERE}/../../island.sh"

# name|map|randseed|stage args|...
CASES=(
	"semicolon|semicolon.map|seed-1|-c 3"
	"comma|comma.map|seed-1|-c 3"
	"colon|colon.map|seed-1|-c 3"
	"period|period.map|seed-1|-c 3"
	"tilde|tilde.map|seed-1|-c 3"
	"space|space.map|seed-1|-c 3"
	"dquote|dquote.map|seed-1|-c 3"
	"squote|squote.map|seed-1|-c 3"
)

island_gate "$@"
