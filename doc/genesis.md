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

The `--number-of-oceans` flag specifies the number of oceans.
The number of oceans must be between 1 and 9 (inclusive) and defaults to 9.

The map is partitioned into several distinct oceans grown from random seed points,
then 4-colored with the plain ocean glyphs so that mapgen reads each ocean as its own
region. The oceans must not contain sea lanes.

### Step 1 — Partition into oceans (partition)

This is the core "assign the oceans" logic — a randomized flood-fill / region-growth:

- Create a size × size grid, every cell marked -1 (unclaimed).
- Seed each ocean (0..oceans-1) at a distinct random cell; push those cells onto a frontier list.
- Grow: while cells remain unclaimed, pick a random frontier cell, find its unclaimed 4-neighbors (cardinal only), claim one at random for that cell's ocean, and push it onto the frontier. If a frontier cell has no open neighbors, drop it.

The randomized frontier pick is what gives oceans their organic, jagged boundaries rather than neat blobs. Result: a 2D array where region[r][c] is an ocean ID 0..oceans-1, every cell filled.

### Step 2 — Color the oceans (colorOceans)

The ASCII map only has a handful of ocean glyphs, so adjacent oceans need different glyphs to stay visually/logically distinct for mapgen. So it does a graph 4-coloring:

- Build an ocean-adjacency graph using mapgen's exact flood rule: 8-neighbor, columns wrap, rows don't. Any two different ocean IDs touching under that rule become graph neighbors.
- 4-color the graph by deterministic backtracking (colorVertex, maxColors = 4). This is guaranteed to succeed — the region-adjacency graph of a contiguous partition is planar, hence
  4-colorable (the panic is unreachable).

The reason it matches mapgen's adjacency rule precisely is so the separate oceans we draw are read back as separate regions downstream.

## Create the islands

Update the canvas, adding a number of islands.

The `--island-iterations` specifies the number of island iterations.
It must be between 1 and 10 (inclusive) and defaults to 10.

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

## Generate Regions

### Seas
By convention, the Great Sea is always the sea starting in the top left cell.

```text
0,0	Great Sea
```

Assign random names to the remaining regions.

It is likely that the island generation split a sea into two parts.
When that happens, the generated map will have an unnamed sea.

