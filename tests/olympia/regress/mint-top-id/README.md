# mint-top-id — the top id range stops at MAX_BOXES - 1

Pins the fix for #245. `new_ent()` (`olympia/code.c`) minted storms, and
its fallback ranges for characters and everything else, with
`rnd_alloc_num(79000, MAX_BOXES)`. `rnd_alloc_num()` treats `high` as
inclusive: the draw is in `[low, high]` and the free-box scan runs
`i <= high`. `bx` has `MAX_BOXES` (150000) entries, so a draw of 150000, or
a scan that reached it, read `bx[150000]`, one past the array. When that
read was `NULL`, `new_ent()` returned 150000 and `alloc_box()` failed
`assert(n > 0 && n < MAX_BOXES)`.

Now the four calls pass `MAX_BOXES - 1`, the end of the "rest" range that
`print_box_usage_sup()` already reports.

## Why the goldens don't move

`rng_draw()` is keyed on the stream counter, so each mint draw is
independent of the others. The range width changes from 71000 to 70999,
but the mask stays `0x1ffff`, so a draw only changes when it would have
been exactly 150000: it is now rejected and re-hashed, like any other
out-of-range value. Every other draw is identical, and the golden turns
never drew 150000 (it would have crashed them), so both trees are
byte-identical.

## Scenario

No `scenario.patch`: the base world `tests/olympia/fixtures/world.tgz` with
`lib/randseed` set to `bug-245-1004...` and a newline (16 bytes). Under
that seed, mint draw 631 of the turn is a fog storm in the 79000 range that
drew 150000 before the fix. About one turn in ten on this world hits the
top id: the turn mints about 6,500 storms.

## Checks

The turn exits 0; storm 127766 (the redrawn id) is in `lib/misc`; and the
post-turn `lib` matches `EXPECT.sha256` byte for byte. Before the fix the
turn fails the `alloc_box()` assert (exit 134) on debug, and reports a
heap-buffer-overflow in `rnd_alloc_num` under asan-ubsan.
