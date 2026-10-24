#!/bin/bash
# Consistency check for the Ultron fixture backlog (tests/ultron/backlog.tsv).
#
#   1. Every cmd_tbl verb in olympia/glob.c has exactly one backlog row, and
#      every backlog row is a cmd_tbl verb (so the backlog can't drift from
#      the engine's command list).
#   2. Every cell that names a fixture names one that exists: "golden" (the
#      main manifest) or a directory under tests/olympia/regress/.
#
# Prints YES when consistent, NO plus the reasons otherwise.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../.." && pwd)"
BACKLOG="${HERE}/backlog.tsv"
GLOB="${ROOT}/olympia/glob.c"

bad=0

tbl_verbs() {
	sed -n '/^struct cmd_tbl_ent cmd_tbl\[\] = {/,/^};/p' "${GLOB}" |
		sed -n 's/^{ *"[^"]*", *"\([^"][^"]*\)".*/\1/p' | sort
}
backlog_verbs() { awk -F'\t' 'NR > 1 { print $1 }' "${BACKLOG}" | sort; }

d="$(diff <(tbl_verbs) <(backlog_verbs))"
if [ -n "${d}" ]; then
	echo "NO  (backlog verbs differ from cmd_tbl; < cmd_tbl only, > backlog only)"
	echo "${d}"
	bad=1
fi

dups="$(backlog_verbs | uniq -d)"
if [ -n "${dups}" ]; then
	echo "NO  (duplicate backlog rows: ${dups})"
	bad=1
fi

# awk, not "read": IFS=tab would merge the empty alias_of column away
while read -r verb cell; do
	case "${cell}" in
	todo|n/a|golden) ;;
	*)	if [ ! -d "${ROOT}/tests/olympia/regress/${cell}" ]; then
			echo "NO  (${verb}: no fixture tests/olympia/regress/${cell})"
			bad=1
		fi ;;
	esac
done < <(awk -F'\t' 'NR > 1 { print $1, $5; print $1, $6; print $1, $7 }' "${BACKLOG}")

[ "${bad}" -eq 0 ] && echo "YES"
exit "${bad}"
