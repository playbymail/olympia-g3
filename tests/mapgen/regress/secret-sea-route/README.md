# Regression: secret-sea-route NULL deref (`adjacent_tile_water` off-by-one)

**Seed:** `S000000000000002` (the 16-byte `randseed` in this directory).

## What it reproduces

`bridge_mountain_ports()` (`mapgen/mapgen.c`) bridges mountain port cities to
the sea. For each such city it calls `bridge_mountain_sup()`, which asks
`adjacent_tile_water()` for an adjacent ocean tile and then builds a road to it.

`adjacent_tile_water()` shuffles the 8 direction slots (`dir_vector[1..8]`,
`MAX_DIR == 9`) and scans for an ocean neighbour. The original return guard was:

```c
return (i < MAX_DIR) ? p : NULL;     /* off-by-one */
```

When the ocean neighbour was found in the **last** slot (`dir_vector[8]`), the
loop incremented `i` to `9` before exiting, so the guard `(9 < 9)` returned
`NULL` even though a valid ocean tile had been found. `bridge_mountain_sup()`
then passed that `NULL` to `add_road()`, which dereferenced it
(`&to->roads` → address `0x70`) → **SIGSEGV**. (Asserts are compiled out in this
build, so the crash lands in `add_road`/`roads_append` rather than the
`assert(to->terrain == terr_ocean)` a few lines earlier.)

It is seed-sensitive because it requires a mountain port city whose sole ocean
neighbour shuffles into slot 8 **and** `rnd(1,7) == 7`. The canonical fixture
seed does not trigger it; `S000000000000002` does (found by a brute-force seed
sweep — it was the third seed tried).

## The fix

`adjacent_tile_water()` now returns based on what was actually found, not the
loop counter:

```c
return (p && p->terrain == terr_ocean) ? p : NULL;
```

Output-neutral for every seed that did not crash; slot-8 ocean hits now become
valid "secret sea route" roads instead of a crash.

## Run it

```bash
cmake --build --preset debug          # build mapgen-g3
./tests/mapgen/regress/secret-sea-route/check.sh           # YES = pass
./tests/mapgen/regress/secret-sea-route/check.sh --update  # refresh EXPECT.sha256
```

`EXPECT.sha256` pins the sha256 of the `gate`/`loc`/`road` this seed produces on
a fixed 64-bit build (the full `loc` is ~700 KB, so only the manifest is
committed, not the files). A future reintroduction of the bug fails the exit-code
check; any output drift fails the hash check.
