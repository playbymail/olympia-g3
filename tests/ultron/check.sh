#!/bin/bash
# Consistency check for the Ultron fixture backlogs (tests/ultron/backlog.tsv
# and tests/ultron/use-backlog.tsv).
#
#   1. Every cmd_tbl verb in olympia/glob.c has exactly one backlog row, and
#      every backlog row is a cmd_tbl verb (so the backlog can't drift from
#      the engine's command list).
#   2. Every use_tbl skill in olympia/use.c and every use key dispatched by
#      v_use_item() has exactly one use-backlog row, keyed by its id and named
#      by its sk_/use_ define, and every use-backlog row is one of them
#      (issue #181).
#   3. Every cell that names a fixture names one that exists: "golden" (the
#      main manifest) or a directory under tests/olympia/regress/.
#
# Prints YES when consistent, NO plus the reasons otherwise.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../.." && pwd)"
BACKLOG="${HERE}/backlog.tsv"
USE_BACKLOG="${HERE}/use-backlog.tsv"
GLOB="${ROOT}/olympia/glob.c"
USE_C="${ROOT}/olympia/use.c"

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

# use_tbl skills and v_use_item() use keys, as "kind key name" lines; the ids
# come from the sk_/use_ defines in olympia/*.h
tbl_uses() {
	{
		grep -hE '^#define[[:space:]]+(sk|use)_[a-z_]+[[:space:]]+[0-9]+' "${ROOT}"/olympia/*.h |
			awk '{ print "def", $2, $3 }'
		sed -n '/^struct use_tbl_ent use_tbl\[\] = {/,/^};/p' "${USE_C}" |
			sed -n 's/^{"c", *\(sk_[a-z_]*\),.*/skill \1/p'
		sed -n '/^v_use_item(struct command \*c)/,/^}/p' "${USE_C}" |
			sed -n '/^	switch (n)/,/^	}/p' | sed -n 's/^	case \(use_[a-z_]*\):/item \1/p' |
			sort -u
	} | awk '$1 == "def" { id[$2] = $3; next }
		{ k = $2; sub(/^(sk|use)_/, "", k); print $1, id[$2], k }' | sort
}
backlog_uses() { awk -F'\t' 'NR > 1 { print $1, $2, $3 }' "${USE_BACKLOG}" | sort; }

d="$(diff <(tbl_uses) <(backlog_uses))"
if [ -n "${d}" ]; then
	echo "NO  (use-backlog rows differ from use_tbl/v_use_item; < engine only, > backlog only)"
	echo "${d}"
	bad=1
fi

dups="$(awk -F'\t' 'NR > 1 { print $1, $2 }' "${USE_BACKLOG}" | sort | uniq -d)"
if [ -n "${dups}" ]; then
	echo "NO  (duplicate use-backlog rows: ${dups})"
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
done < <(awk -F'\t' 'NR > 1 { print $1, $5; print $1, $6; print $1, $7 }' "${BACKLOG}"
	awk -F'\t' 'NR > 1 { print $1 ":" $3, $6; print $1 ":" $3, $7 }' "${USE_BACKLOG}")

[ "${bad}" -eq 0 ] && echo "YES"
exit "${bad}"
