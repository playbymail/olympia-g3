# Genesis

Genesis creates a new Map and the supporting inputs (Region, etc).

One quirk of Genesis is the determinism. You must specify the seeds for PCG.
Each step of the generator reinitializes the PRNG stream from the seeds.
This allows us to reorder steps and still keep outcomes from each step deterministic.

## PRNG

Use PCG for the random number generator.

## Create a blank map

The canvas must be square, so the `--size` option specifies both the width and height.
The size must be between 10 and 99 (inclusive) and defaults to 99.

## Create the seas

Update the canvas, adding a number of seas.

The `--number-of-oceans` flag specifies the number of oceans (defaults to 9).
The effective count is capped to the canvas: `max_oceans = min(ceil(size / 3), 12)`
(e.g. size 10 → 4, size 30 → 10, size 36+ → 12). A larger request is clamped to
the cap with a warning, so the default works on every size.

The map is partitioned into several distinct oceans grown from random seed points,
then 4-colored with the plain ocean glyphs so that mapgen reads each ocean as its own
region. The oceans must not contain sea lanes.

By default this partition happens **up front**, over the blank canvas, before the
islands are grown. The `--defer-oceans` flag instead generates the oceans **after**
the islands and Mt. Olympus (see "Deferred oceans" below), which produces seas that
follow the finished coastlines.

### Step 1 — Partition into oceans (partition)

This is the core "assign the oceans" logic — a randomized flood-fill / region-growth:

- Create a size × size grid, every cell marked -1 (unclaimed).
- Seed each ocean (0..oceans-1) at a distinct random cell; push those cells onto a frontier list.
- Grow: while cells remain unclaimed, pick a random frontier cell, find its unclaimed 4-neighbors (cardinal only), claim one at random for that cell's ocean, and push it onto the frontier. If a frontier cell has no open neighbors, drop it.

The randomized frontier pick is what gives oceans their organic, jagged boundaries rather than neat blobs. Result: a 2D array where region[r][c] is an ocean ID 0..oceans-1, every cell filled.

### Step 2 — Color the oceans (colorOceans)

The ASCII map only has a handful of ocean glyphs, so adjacent oceans need different glyphs to stay visually/logically distinct for mapgen. So it does a graph 4-coloring:

- Build an ocean-adjacency graph using mapgen's exact flood rule: 8-neighbor, columns wrap, rows don't. Any two different ocean IDs touching under that rule become graph neighbors.
- 4-color the graph by deterministic backtracking (colorVertex, maxColors = 4).

Note: 4-coloring is **not** always possible here. Because the adjacency rule is
8-neighbor (diagonals) on a column-wrapped cylinder, the graph need not be planar,
and on a crowded canvas a cell can border more than four distinct oceans — there
are only four ocean glyphs, so no valid assignment exists. The size-scaled ocean
cap above makes this rare; when coloring still fails, genesis reduces the ocean
count by one and re-partitions/re-colors until it succeeds (a single ocean always
colors), so it always produces a valid map.

The reason it matches mapgen's adjacency rule precisely is so the separate oceans we draw are read back as separate regions downstream.

### Deferred oceans (`--defer-oceans`)

With `--defer-oceans`, steps 1–2 are skipped at the start. The canvas is filled with
a single ocean glyph (`' '`) so the islands have valid water to grow into, the islands
and Mt. Olympus are laid down, and only then are the oceans carved out of the water
that remains. This runs on its own PCG stream (`STEP_ORIGINS`), so determinism and the
"reorder steps freely" property still hold.

1. **Pick origins.** Choose `--number-of-oceans` "ocean-origin provinces" among the
   water (`' '`) cells using Mitchell's best-candidate sampling with a minimum spacing
   of `~0.65 · sqrt(water_cells / N)`. If an origin can't clear the spacing within
   `N·N` candidate draws, the count is reduced by one and the placement restarts (the
   spacing floor is held fixed, so fewer points is strictly easier).
2. **Partition (water only).** Grow each origin into an ocean, claiming only
   unclaimed water cells and stepping only to the four **cardinal** neighbors
   (columns wrap). Cardinal growth matters: two oceans racing into a shared corridor
   under 8-neighbor growth interleave cell-by-cell, each staying connected only
   through diagonals, which paints a checkerboard seam (#86). Growth runs through the
   channels, and each ocean is one connected water body. `--ocean-growth` picks how
   the oceans grow:
   - `frontier` (the default): the same randomized-frontier flood as step 1. Each
     step picks a random frontier cell and claims one random unclaimed neighbor, so
     an ocean's final reach depends on how often it gets picked. Boundaries come out
     ragged and sizes uneven.
   - `bfs` (#87): a multi-source breadth-first search. All origins grow outward
     one ring at a time, so every water cell joins the ocean whose origin is nearest
     **through the water** (a geodesic Voronoi partition). Seas come out smoother and
     more even in size, and they still follow channels around islands. Ties (a cell
     equidistant from two origins) go to whichever ring cell is expanded first, and
     each ring is shuffled on the same `STEP_ORIGINS` stream, so the seed decides
     ties rather than the origin order.

   `bfs` requires `--defer-oceans`. `frontier` output is byte-identical to the
   output from before the switch existed.

   Neither mode is strictly better, so the choice is left to the gamemaster when
   generating. `bfs` gives somewhat more even seas (across sizes 10–99 the
   largest sea averaged 4.0× the smallest, versus 4.7× for `frontier`), but
   because growth is cardinal its boundaries run as straight 45° staircases.
   `frontier` gives more natural, ragged coastlines between seas. Shuffling the
   growth directions per cell under `bfs` was tried and changes nothing visible:
   a cell's neighbors all join that cell's ocean whatever order they are visited
   in, so only exact ties move (#87).
3. **Discover the rest.** Islands shouldn't enclose water, but dropping in Mt. Olympus
   can seal off a small pocket. Any water body no origin reached is swept row-major and
   becomes its own ocean, so every water cell ends up in a named sea.
4. **Color** exactly as step 2 above (4-color, reduce-and-retry on failure), painting
   only the water cells.

The `ocean_id[][]` partition is kept alive through region writing (it also feeds the
size-based naming below).

## Create the islands

Update the canvas, adding a number of islands.

The `--island-iterations` specifies the number of island iterations.
It must be between 2 and 10 (inclusive) and defaults to 10.

The minimum is 2 (not 1): iterations 1 and 2 together grow 1 + 2 = 3 islands,
which the continental-shelf spacing keeps as at least 3 distinct land regions.
`mapgen` needs at least 3 land regions to lay its stone-circle gates (each circle
links to two *other* circles); fewer would wedge it. A single-island world is not
playable in any case.

The size of the islands depends on the iterations.

| Iteration | Island Size | Number of Islands to add |
|-----------|-------------|--------------------------|
| 1         | 521         | 1                        |
| 2         | 257         | 2                        |
| 3         | 257         | 3                        |
| 4         | 127         | 4                        |
| 5         | 61          | 5                        |
| 6         | 61          | 6                        |
| 7         | 31          | 7                        |
| 8         | 17          | 8                        |
| 9         | 11          | 9                        |
| 10        | 7           | 10                       |

For example, if 2 iterations are requested, the 1st would create one island with a size of 521.
The 2nd would create two islands with size of 257.
If 12 islands are generated, the 10th, 11th, and 12th would all have a size of 7.

To get the seeds for each iteration, use a hash of the original seeds, the iteration number, and the island number to derive a set of seeds for the iteration.

Use the logic from the `island` command to generate the islands.

### The five stages

1. Classify.
Walk the map into a work grid: ocean glyphs → '~' (available water), everything else → 'p' (existing land, off-limits).
Sea-lane glyphs (; : ~ ") are a hard stop — if the map contains any, the generator refuses to run, since sea lanes mean the map is finalized.

2. Continental shelf. For every existing-land cell, recursively mark shelf rings of surrounding water as '_' (unavailable).
Default 3 → new islands can't grow within 3 cells of existing land.

3. Border. Mark the outer border rows/columns as '_'.
Default 2 → islands stay off the map edges.

4. Distance field. Compute, for every water cell, its distance to the nearest non-water cell (land, shelf, or border), capped at 9.
Non-water starts at 0, water at 9, then extendDistance relaxes neighbors outward.
The upshot: the most "open ocean" cells get the highest distance values.

5. Seed + grow + terrain.

- Seed: find the maximum distance value, count how many cells share it, and randomly pick one of those. That cell becomes island cell 0, marked 'o'. This is what places each island in the emptiest available water — naturally spacing them apart.
- Grow: repeat until the island hits its target size. Each step enumerates every available '~' cell adjacent (4-neighbor) to the current island, then picks one uniformly at random and claims it:

```text
for islandSize < target {
    // count all '~' neighbors across all current island cells
    // pick a random one, append it, mark 'o'
}
```

Because interior boundary cells get counted from multiple sides, growth tends to fill in and stay roughly compact rather than spindly. If no available neighbor remains (boxed in by
shelf/border/other land), it stops early.

- Terrain: the 'o' cells get real terrain via probabilistic clustering. Five types, each with min/max cluster size and a target share:

```text
┌───────┬──────────┬─────────┬────────┐
│ glyph │ terrain  │ min–max │ target │
├───────┼──────────┼─────────┼────────┤
│ p     │ plains   │ 12–30   │ 30%    │
├───────┼──────────┼─────────┼────────┤
│ f     │ forest   │ 6–14    │ 30%    │
├───────┼──────────┼─────────┼────────┤
│ m     │ mountain │ 6–10    │ 20%    │
├───────┼──────────┼─────────┼────────┤
│ d     │ desert   │ 15–30   │ 10%    │
├───────┼──────────┼─────────┼────────┤
│ s     │ swamp    │ 1–3     │ 10%    │
└───────┴──────────┴─────────┴────────┘
```

Targets are normalized to integer weights (GCD/LCM), island cells are shuffled, then each unclaimed cell starts (or continues) a cluster: a terrain is chosen by weight and flood-filled
into contiguous unclaimed neighbors up to its cluster size. Result: organic patches of like terrain, e.g. a forest core ringed by plains with stray mountain/swamp dabs.

Note islands don't create provinces — they only paint terrain glyphs. The `mapgen` application reads those glyphs and turns each into a province/tile in the game store.

The whole thing is deterministic given seed + input map + flags: distance field places the island in open water, boundary randomization shapes it, and the advanced seed makes the next island land elsewhere.

## Add Mt. Olympus

Mt. Olympus is the 'O' glyph surrounded by 'M' glyphs.
It overwrites the cell at the center of the map and the 8 adjacent neighbors.

## Place start cities

`mapgen` creates safe-haven start cities only from the digit glyphs in `Map`, and
`olympia-g3 -a` can't add a player without one (an empty `lib/startloc` aborts on
`valid_box(where)`; issue #85). So the last terrain step writes start-city digits
onto the land. It runs after every island/Olympus/ocean step (including
`--defer-oceans`) on its own PCG stream (`STEP_START_CITIES`), so it changes nothing
upstream of itself.

The `--start-cities N` flag (0..16, default 6) sets the count; `0` turns placement
off and reproduces the pre-#85 output byte for byte.

- **Candidates.** Plains and forest cells, or any land terrain if there are none.
  Never ocean, Mt. Olympus (`O`/`M`), or a cell touching it, and never the
  first (anchor) cell of a land mass. `Regions` and `Land` name each mass at that
  cell, and `Land`'s clump type must match its glyph, while a start city is its
  own one-cell clump in mapgen. Excluding the anchor also leaves every land
  region at least one non-safe-haven province. mapgen's
  `random_tile_from_each_region` redraws until it finds one, so a region made
  only of start cities would spin forever.
- **Spacing.** The same best-candidate sampling as the deferred-ocean origins:
  each city is the farthest-from-existing of up to `N·N` random candidates, with a
  floor of `~0.65 · sqrt(candidates / N)` cells, never under 2, so no two cities
  touch. Distance wraps across columns, as mapgen's columns do. If a city can't
  clear the floor, `N` drops by one and placement restarts, with the floor held fixed.
  One city always fits.
- **Digits.** In placement order: `1` Drassa, `2` Rimmon, `3` Harn, `4` Imperial
  City, `5` Port Aurnos, `6` Greyfell, `7` Yellowleaf, then alternating `9`/`0`
  (random-name start cities). `8` (Golden City) is never written: it is a city but
  not a safe haven, so it isn't a start location.

A digit cell is still land (mapgen makes it forest), so the land masses, their
anchors, and the `Regions`/`Land` output are unchanged.

## Generate Regions

### Seas
By default, the Great Sea is the sea starting in the top left cell.

```text
0,0	Great Sea
```

Assign random names to the remaining regions.

It is likely that the island generation split a sea into two parts.
When that happens, the generated map will have an unnamed sea.

Under `--defer-oceans`, naming is **size-based** rather than position-based. Each ocean
is counted, and the **largest** becomes the Great Sea — naming the smallest-area sea
"Great" just because it sits at the corner makes no sense. Ties break by: (1) the ocean
that owns the top-left cell `(0,0)`, then (2) the origin nearest `(0,0)`, then (3) the
ocean created first. Every other ocean draws a random pool name, and a **landlocked**
water body smaller than 12 provinces is recast as a lake ("Great Sea" → "Great Lake",
otherwise "Lake <name>") — a light editorial touch; the GM is expected to hand-edit the
`Map` and names afterward.

Landlocked water bodies smaller than **4 provinces** are **filled in with land**
(the `'o'` random-terrain glyph, so mapgen rolls each filled province's terrain) and
merge into the enclosing land mass, so the tiniest island-/Olympus-enclosed puddles
don't become seas. mapgen requires every water region to be named, so filling them in —
rather than leaving them as unnamed water — is what keeps the map valid.


## Regression gates

`tests/genesis/regress/*/check.sh` pin genesis-g3's output: each runs recorded
argument vectors and checks the exit status, stderr and every file written. See
[tests/genesis/README.md](../tests/genesis/README.md).
