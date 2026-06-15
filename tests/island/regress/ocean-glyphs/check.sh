#!/bin/bash
###########################################################################
# Regression: island-g3 must respect every ocean glyph the author may use
#
# island classifies each input cell as water (available for a new island) or
# land.  mapgen treats EIGHT glyphs as ocean -- ';' ',' ':' '.' '~' ' ' '"' '\''
# (the ';' ':' '~' '"' variants become sea lanes) -- and a map author may seed a
# starting map with any of them.  Before the fix, island recognized only four
# (',' '.' '\'' ' ') as water and misread the other four (notably '~', the
# canonical water glyph) as LAND: it then found "no room" for an island and
# placed a degenerate 1-province blob.  See issue #24.
#
# This check feeds island an all-ocean map for each of the eight glyphs (fixed
# seed) and asserts, per glyph:
#   (1) clean exit,
#   (2) a non-degenerate island (more than 1 province),
#   (3) the same province count for every glyph (placement is glyph-independent:
#       the classifier normalizes all ocean to '~' in its scratch grid), and
#   (4) the output preserves the author's ocean glyph and contains no '_'
#       (island's private continental-shelf marker must never reach the output).
#
# It deliberately does NOT bake the exact province count or full output (those
# are RNG-sequence dependent; cf. the #25 granularity work) -- only the
# bug-defining invariants above.
#
# Pass: prints YES and exits 0.
###########################################################################
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../../../.." && pwd)"
PRESET="${OLYMPIA_PRESET:-debug}"
BIN="${ROOT}/build/${PRESET}/island-g3"
SIZE=20

[ -x "${BIN}" ] || { echo "error: missing ${BIN} (build the ${PRESET} preset first)"; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

# All glyphs mapgen treats as ocean (must match island's input classifier).
OCEAN=(';' ',' ':' '.' '~' ' ' '"' "'")

prev=""
for g in "${OCEAN[@]}"; do
	# Build a SIZE x SIZE map filled with this ocean glyph.
	map="${WORK}/Map"
	row="$(printf "%${SIZE}s" "" | tr ' ' "X")"   # SIZE copies of a placeholder
	row="${row//X/$g}"
	: > "${map}"
	for ((i = 0; i < SIZE; i++)); do printf '%s\n' "${row}" >> "${map}"; done

	cp -p "${HERE}/randseed" "${WORK}/randseed" || exit 2

	out="$(cd "${WORK}" && "${BIN}" -c 3 < "${map}" 2>"${WORK}/err")"
	ec=$?
	prov="$(grep -oE 'island of [0-9]+' "${WORK}/err" | grep -oE '[0-9]+')"

	label="$(printf '%q' "${g}")"

	if [ "${ec}" -ne 0 ]; then
		echo "NO  (glyph ${label}: island-g3 exit ${ec})"; exit 1
	fi
	if [ -z "${prov}" ] || [ "${prov}" -le 1 ]; then
		echo "NO  (glyph ${label}: degenerate island, provinces='${prov:-none}' -- ocean read as land?)"; exit 1
	fi
	if printf '%s' "${out}" | grep -q '_'; then
		echo "NO  (glyph ${label}: '_' shelf marker leaked into output)"; exit 1
	fi
	if ! printf '%s' "${out}" | grep -qF "${g}"; then
		echo "NO  (glyph ${label}: ocean glyph not preserved in output)"; exit 1
	fi
	if [ -n "${prev}" ] && [ "${prov}" -ne "${prev}" ]; then
		echo "NO  (glyph ${label}: ${prov} provinces != ${prev} for a prior glyph -- placement should be glyph-independent)"; exit 1
	fi
	prev="${prov}"
done

echo "YES"
exit 0
