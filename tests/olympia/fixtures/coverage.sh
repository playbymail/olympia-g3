#!/bin/bash
###########################################################################
# Shared coverage helpers for regress fixtures (issue #181). Source this
# file; do not run it.
#
#   use_cells <use-coverage.tsv> <cell>...
#       check that every cell has a nonzero count in a dump written by
#       olympia-g3 --use-coverage. A cell is <kind>:<key>:<outcome>, where
#       kind is skill (key = skill id) or item (key = use key, see the
#       use_* defines in olympia/oly.h), and outcome is ok or fail, the
#       outcome columns of tests/ultron/use-backlog.tsv:
#           use_cells "${WORK}/use-coverage.tsv" skill:675:ok item:2:fail
#       Prints a NO line for each cell not reached and returns 1 if any
#       was not, 0 otherwise.
###########################################################################

use_cells() {	# args: use-coverage.tsv cell...
	local tsv="$1" cell kind key o n bad=0
	shift
	for cell in "$@"; do
		kind="${cell%%:*}"; key="${cell#*:}"; o="${key#*:}"; key="${key%%:*}"
		n="$(awk -F'\t' -v k="${kind}" -v n="${key}" -v o="${o}" '
			NR == 1 { for (i = 1; i <= NF; i++) if ($i == o) col = i; next }
			col && $1 == k && $2 == n { print $col }' "${tsv}")"
		[ "${n:-0}" -gt 0 ] || { echo "NO  (use ${kind} ${key} did not reach ${o}: ${o}=${n:-0})"; bad=1; }
	done
	return "${bad}"
}
