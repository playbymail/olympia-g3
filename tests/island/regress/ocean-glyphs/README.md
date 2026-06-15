# island ocean-glyph regression (issue #24)

## The bug

`island-g3` reads a map on stdin, adds a randomly generated island, and prints the
result for `mapgen-g3` to consume. It classifies each input cell as **water**
(available for a new island) or **land**.

`mapgen` treats eight glyphs as ocean — `; , : . ~` space `" '` (the `;` `:` `~`
`"` variants additionally mark a *sea lane*). A map author building land masses
may seed the starting map with **any** of them; sea lanes are assigned later, but
the glyph is still ocean.

island's input classifier recognized only four of them (`, . '` space) as water.
The other four — including `~`, the canonical water glyph island itself uses
internally — fell through to the `default` arm and were treated as **land**.
Consequence: feed island an all-`~` (or `:`/`"`/`;`) ocean map and it sees the
whole map as land, reports *"Not enough room to expand island!"*, and places a
degenerate **1-province** island. The author's choice of ocean marker was not
respected.

(The originally filed premise — that `make_shelf`'s `_` marker leaks into the
output and crashes mapgen — does not hold: `_` is written only to island's
internal `working` scratch grid, never to the printed map. The misleading
`map`-named parameter of `make_shelf` was renamed to `working` and its comment
corrected in the same fix.)

## The fix

Broaden island's input classifier (`island/island.c`, in `main()`) to recognize
the full ocean set mapgen uses. The output map preserves the author's original
glyph verbatim, so only the *input* classification needed widening.

## What this check asserts

For each of the eight ocean glyphs, on a fixed seed, feeding island an all-ocean
map must yield:

1. a clean exit,
2. a **non-degenerate** island (more than one province),
3. the **same** province count for every glyph — placement is glyph-independent
   because the classifier normalizes all ocean to `~` in its scratch grid, and
4. output that **preserves** the author's ocean glyph and contains **no `_`**.

It deliberately does not bake the exact province count or full output (both are
RNG-sequence dependent; cf. the #25 RNG-granularity work) — only the invariants
that define the bug. Verified to fail on the pre-fix engine (`;`/`~`/`:`/`"` →
1 province) and pass after.

## Run

```bash
cmake --build --preset debug          # builds build/debug/island-g3
./tests/island/regress/ocean-glyphs/check.sh   # prints YES
```

Override the build with `OLYMPIA_PRESET=release ./check.sh`.
