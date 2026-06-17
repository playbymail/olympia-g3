/*
 * genesis-g3 -- generate a fresh input set for mapgen-g3.
 *
 * Implements doc/genesis.md: build a blank square ocean canvas, partition it
 * into distinct oceans, 4-color them so mapgen reads each as its own region,
 * grow islands (the island-g3 algorithm, re-derived here on PCG), drop in
 * Mt. Olympus, then emit the full mapgen input set: Map, Regions, Land, Cities,
 * randseed.
 *
 * genesis is UPSTREAM of the golden gate: its output is the *input* to mapgen,
 * so a genesis-made world deliberately does NOT reproduce the golden snapshots.
 *
 * Determinism: a single --seed drives everything; each generation STEP reseeds
 * its own PCG stream off that seed (see genesis/pcg.h), so steps can be
 * reordered without changing any step's outcome.
 *
 * GLYPH CONTRACT (verified against mapgen/mapgen.c's reader):
 *   - Ocean: genesis writes only the four PLAIN ocean glyphs ',' '.' ' ' '\''
 *     which mapgen maps to its four ocean "colors" 1..4 (mapgen.c case labels).
 *     The sea-lane variants ';' ':' '~' '"' are NEVER written (a sea lane means
 *     "finalized map"; the island stage refuses to run if one is present).
 *   - Terrain: 'p' plains, 'f' forest, 'm' mountain, 'd' desert, 's' swamp.
 *   - Mt. Olympus is 'O' (mapgen.c:552), NOT '0' (which mapgen reads as a
 *     random-name starting city); doc/genesis.md says '0' in error.
 *   - The 4-color adjacency mirrors mapgen's flood rule exactly
 *     (adjacent_tile_sup / flood_water_inside: 8-neighbor, columns wrap, rows
 *     clamp, group by ->color) so each painted ocean reads back as one region.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <getopt.h>
#include <stdint.h>
#include <limits.h>
#include <assert.h>

#include "pcg.h"
#include "names.h"

#define MAX_DIM			100	/* mapgen MAX_ROW/MAX_COL; size is 10..99 */
#define DISTANCE_CAP		9
#define NUM_TERRAINS		5

/* Continental-shelf / border widths (island-g3 defaults). */
#define SHELF_WIDTH		3
#define BORDER_WIDTH		2

/* Per-step PCG stream tags (the "step number" fed to pcg32_seed_step). */
#define STEP_PARTITION		1
#define STEP_NAMES		2
#define STEP_CITIES		3
#define STEP_RANDSEED		4
#define STEP_ORIGINS		5	/* --defer-oceans origin selection + frontier */
#define STEP_ISLAND_BASE	100	/* island streams: STEP_ISLAND_BASE + iteration */

/*
 * --defer-oceans tuning (issue #80).
 *   ALPHA_SQ        : (0.65)^2 -- min origin spacing ~0.65*sqrt(water_cells/N).
 *   LAKE_MAX        : a landlocked water body smaller than this gets a "lake" name.
 *   MIN_NAMED_WATER : landlocked water bodies smaller than this are filled in with
 *                     land rather than kept as (necessarily named) tiny seas.
 */
#define ALPHA_SQ		0.4225
#define LAKE_MAX		12
#define MIN_NAMED_WATER		4

typedef struct {
	int x, y;
} location;

typedef struct {
	char symbol;
	int min, max;
	int target_prob, prob;
} terrain;

/*
 * Iteration -> (island size, count) table (doc/genesis.md).  Index 1..10; the
 * count for iteration N is N.  Index 0 is unused.
 */
static const int island_size_tab[11] = {
	0, 521, 257, 257, 127, 61, 61, 31, 17, 11, 7
};

/* The map under construction and per-step scratch grids. */
static int  g_size;
static char map[MAX_DIM][MAX_DIM];
static int  ocean_id[MAX_DIM][MAX_DIM];
static char working[MAX_DIM][MAX_DIM];
static char distance[MAX_DIM][MAX_DIM];
static int  ids[MAX_DIM][MAX_DIM];
static location island_cells[MAX_DIM * MAX_DIM];

/* Region-labeling scratch (iterative flood). */
static int  label[MAX_DIM][MAX_DIM];
static int  flood_stack[MAX_DIM * MAX_DIM];

/*
 * --defer-oceans state (issue #80).  When set, oceans are generated AFTER the
 * islands and Mt. Olympus rather than partitioned up-front.  The partition is
 * recorded in ocean_id[][] (kept alive through region writing) plus per-ocean
 * metadata used for size-based naming.  defer_n counts the oceans actually made
 * (N seeded survivors + any origin-less water bodies discovered by the sweep).
 */
static int  g_defer_oceans;
static int  defer_n;
static int  ocean_size[MAX_DIM];
static int  ocean_origin_r[MAX_DIM];	/* tie-break point + output anchor (a region cell) */
static int  ocean_origin_c[MAX_DIM];
static int  ocean_landlocked[MAX_DIM];	/* 1 = never touches a top/bottom border row */

/* ------------------------------------------------------------------------- */
/* Glyph helpers (must agree with mapgen.c's reader).                        */
/* ------------------------------------------------------------------------- */

static int
is_ocean_glyph(char c)
{
	switch (c) {
	case ',': case '.': case ' ': case '\'':	/* plain (genesis writes these) */
	case ';': case ':': case '~': case '"':		/* sea-lane variants (tolerated) */
		return 1;
	default:
		return 0;
	}
}

/* mapgen's ocean ->color value (1..4); 0 for non-ocean. */
static int
ocean_color(char c)
{
	switch (c) {
	case ',': case ';': return 1;
	case '.': case ':': return 2;
	case ' ': case '~': return 3;
	case '\'': case '"': return 4;
	default: return 0;
	}
}

/* The four plain ocean glyphs, indexed by 4-coloring result 0..3. */
static const char ocean_glyph[4] = { ',', '.', ' ', '\'' };

/* ------------------------------------------------------------------------- */
/* Neighbor rules.                                                           */
/* ------------------------------------------------------------------------- */

/*
 * mapgen's 8-neighbor adjacency: columns wrap, rows clamp off-map
 * (mapgen.c adjacent_tile_sup).  Returns 1 and fills *nr,*nc when on-map.
 */
static const int DR8[8] = { -1, -1,  0,  1,  1,  1,  0, -1 };
static const int DC8[8] = {  0,  1,  1,  1,  0, -1, -1, -1 };

static int
neighbor8(int r, int c, int d, int *nr, int *nc)
{
	int rr = r + DR8[d];
	int cc = c + DC8[d];

	if (cc < 0)
		cc = g_size - 1;
	else if (cc > g_size - 1)
		cc = 0;

	if (rr < 0 || rr > g_size - 1)
		return 0;

	*nr = rr;
	*nc = cc;
	return 1;
}

/* ------------------------------------------------------------------------- */
/* Step: partition the canvas into oceans (doc/genesis.md step 1).           */
/* Randomized frontier flood-fill, cardinal 4-neighbors, no wrap.            */
/* ------------------------------------------------------------------------- */

static void
partition_oceans(int n_oceans, pcg32_t *rng)
{
	static int frontier[MAX_DIM * MAX_DIM];
	int fn = 0;
	int total = g_size * g_size;
	int claimed = 0;
	int r, c, o, i;

	for (r = 0; r < g_size; r++)
		for (c = 0; c < g_size; c++)
			ocean_id[r][c] = -1;

	/* Seed each ocean at a distinct random cell. */
	for (o = 0; o < n_oceans; o++) {
		int idx;
		do {
			idx = pcg32_range(rng, 0, total - 1);
		} while (ocean_id[idx / g_size][idx % g_size] != -1);
		ocean_id[idx / g_size][idx % g_size] = o;
		claimed++;
		frontier[fn++] = idx;
	}

	/* Grow from the frontier until every cell is claimed. */
	while (claimed < total) {
		int fi, cell, cr, cc, k;
		int nb[4];

		assert(fn > 0);
		fi = pcg32_range(rng, 0, fn - 1);
		cell = frontier[fi];
		cr = cell / g_size;
		cc = cell % g_size;

		k = 0;
		if (cr > 0 && ocean_id[cr - 1][cc] == -1)
			nb[k++] = (cr - 1) * g_size + cc;
		if (cr < g_size - 1 && ocean_id[cr + 1][cc] == -1)
			nb[k++] = (cr + 1) * g_size + cc;
		if (cc > 0 && ocean_id[cr][cc - 1] == -1)
			nb[k++] = cr * g_size + (cc - 1);
		if (cc < g_size - 1 && ocean_id[cr][cc + 1] == -1)
			nb[k++] = cr * g_size + (cc + 1);

		if (k == 0) {
			frontier[fi] = frontier[--fn];	/* drop boxed-in cell */
			continue;
		}

		i = nb[pcg32_range(rng, 0, k - 1)];
		ocean_id[i / g_size][i % g_size] = ocean_id[cr][cc];
		claimed++;
		frontier[fn++] = i;
	}
}

/* ------------------------------------------------------------------------- */
/* Step: 4-color the oceans (doc/genesis.md step 2).                         */
/* Deterministic backtracking over the mapgen-rule adjacency graph.          */
/* ------------------------------------------------------------------------- */

static int
color_solve(int v, int n, const char adj[MAX_DIM][MAX_DIM], int *colors)
{
	int k, u;

	if (v == n)
		return 1;

	for (k = 0; k < 4; k++) {
		int ok = 1;
		for (u = 0; u < n; u++)
			if (adj[v][u] && colors[u] == k) {
				ok = 0;
				break;
			}
		if (ok) {
			colors[v] = k;
			if (color_solve(v + 1, n, adj, colors))
				return 1;
			colors[v] = -1;
		}
	}
	return 0;
}

/* Returns 1 and paints the ocean glyphs on success, 0 if not 4-colorable. */
static int
color_oceans(int n_oceans)
{
	static char adj[MAX_DIM][MAX_DIM];	/* n_oceans <= 12, but keep it simple */
	int colors[MAX_DIM];
	int r, c, d, i;

	for (i = 0; i < n_oceans; i++) {
		int j;
		for (j = 0; j < n_oceans; j++)
			adj[i][j] = 0;
		colors[i] = -1;
	}

	/* Build the ocean-adjacency graph with mapgen's exact 8-neighbor rule. */
	for (r = 0; r < g_size; r++)
		for (c = 0; c < g_size; c++)
			for (d = 0; d < 8; d++) {
				int nr, nc, a, b;
				if (!neighbor8(r, c, d, &nr, &nc))
					continue;
				a = ocean_id[r][c];
				b = ocean_id[nr][nc];
				if (a != b) {
					adj[a][b] = 1;
					adj[b][a] = 1;
				}
			}

	/*
	 *  Try to 4-color the oceans.  This is NOT always possible: the 8-neighbor
	 *  adjacency (diagonals included) can make the ocean-adjacency graph
	 *  non-planar, and with many oceans crammed onto a small canvas a cell can
	 *  border more than four distinct oceans -- there simply aren't enough of
	 *  mapgen's four ocean glyphs to keep them all distinct.  The size-scaled
	 *  ocean cap (see add_oceans) makes this rare; the caller reduces the ocean
	 *  count and retries when it does happen, so a failure here is not fatal.
	 */
	if (!color_solve(0, n_oceans, adj, colors))
		return 0;

	for (r = 0; r < g_size; r++)
		for (c = 0; c < g_size; c++)
			map[r][c] = ocean_glyph[colors[ocean_id[r][c]]];
	return 1;
}

/*
 * Cap of distinct oceans for a given canvas (issue #78):
 *	max_oceans = min(ceil(size / 3), 12)
 * Examples: size 10 -> 4, size 30 -> 10, size 36+ -> 12.
 */
static int
ocean_cap(void)
{
	int cap = (g_size + 2) / 3;	/* ceil(size / 3) */
	return cap > 12 ? 12 : cap;
}

/*
 * Partition + 4-color the oceans, honoring the size-scaled cap.  A request above
 * the cap is clamped (with a warning).  The cap is a heuristic, not a proof --
 * the 8-neighbor / column-wrap adjacency can still be infeasible near the ceiling
 * (color_oceans returns 0) -- so we reduce the count and re-partition/re-color
 * until it succeeds.  A single ocean is always 4-colorable, so this terminates.
 * Returns the ocean count actually used.
 */
static int
add_oceans(int requested, uint64_t seed)
{
	pcg32_t rng;
	int cap = ocean_cap();
	int n = requested;

	if (n > cap) {
		fprintf(stderr,
			"genesis: --number-of-oceans %d exceeds the cap for size %d; using %d\n",
			requested, g_size, cap);
		n = cap;
	}

	for (; n >= 1; n--) {
		/* Reseed the partition stream each attempt: deterministic per count. */
		pcg32_seed_step(&rng, seed, STEP_PARTITION, 0);
		partition_oceans(n, &rng);
		if (color_oceans(n))
			return n;
		fprintf(stderr,
			"genesis: %d oceans not 4-colorable on this map; retrying with %d\n",
			n, n - 1);
	}

	fprintf(stderr, "genesis: internal error: could not color even one ocean\n");
	exit(1);
}

/* ------------------------------------------------------------------------- */
/* --defer-oceans: generate oceans AFTER islands + Olympus (issue #80).      */
/*                                                                           */
/* Flow: fill the canvas with ' ' water, grow islands, drop Olympus, then    */
/* (here) pick N well-spaced ocean-origin provinces among the remaining      */
/* water, grow each into an ocean (frontier flood through water only),       */
/* discover any origin-less water body as its own ocean, 4-color the lot,    */
/* and name them by size (largest = Great Sea).                              */
/* ------------------------------------------------------------------------- */

/* Reset the whole canvas to open water (the four-ocean coloring comes later). */
static void
fill_ocean_canvas(void)
{
	int r, c;

	for (r = 0; r < g_size; r++)
		for (c = 0; c < g_size; c++)
			map[r][c] = ' ';
}

/* Squared Euclidean distance (no column wrap -- spacing/anchoring only). */
static long
dist2(int r1, int c1, int r2, int c2)
{
	long dr = r1 - r2;
	long dc = c1 - c2;

	return dr * dr + dc * dc;
}

/*
 * Pick n ocean-origin cells among the water (' ') cells, spaced at least
 * sqrt(r2) apart, using Mitchell's best-candidate sampling: each origin is the
 * farthest-from-existing of up to n*n random candidates, accepted early once it
 * clears the spacing floor.  Returns 1 with origins in orow/ocol, or 0 if some
 * origin couldn't clear r2 within budget (the caller then reduces n).  r2 is held
 * fixed across reductions, so fewer points at the same spacing is strictly easier.
 */
static int
place_origins(int n, long r2, pcg32_t *rng, int *orow, int *ocol)
{
	static int wr[MAX_DIM * MAX_DIM];
	static int wc[MAX_DIM * MAX_DIM];
	int wn = 0;
	int r, c, i;

	for (r = 0; r < g_size; r++)
		for (c = 0; c < g_size; c++)
			if (map[r][c] == ' ') {
				wr[wn] = r;
				wc[wn] = c;
				wn++;
			}
	if (wn < n)
		return 0;

	for (i = 0; i < n; i++) {
		int best = -1;
		long best_d2 = -1;

		if (i == 0) {
			best = pcg32_range(rng, 0, wn - 1);
		} else {
			int budget = n * n;
			int a;
			for (a = 0; a < budget; a++) {
				int cand = pcg32_range(rng, 0, wn - 1);
				long d2 = LONG_MAX;
				int j;
				for (j = 0; j < i; j++) {
					long dd = dist2(wr[cand], wc[cand], orow[j], ocol[j]);
					if (dd < d2)
						d2 = dd;
				}
				if (d2 > best_d2) {
					best_d2 = d2;
					best = cand;
				}
				if (d2 >= r2)
					break;	/* clears the spacing floor: accept */
			}
			if (best_d2 < r2)
				return 0;	/* couldn't space this origin -- reduce n */
		}
		orow[i] = wr[best];
		ocol[i] = wc[best];
	}
	return 1;
}

/*
 * Partition the water into oceans: seed ocean_id[][] at the n origins and grow
 * each via randomized-frontier flood, claiming only unclaimed water (' ') cells
 * with mapgen's 8-neighbor (column-wrap) rule -- so growth is geodesic through
 * the water and each ocean is one connected component under mapgen's own flood.
 * Then sweep row-major: every still-unclaimed water cell seeds a fresh discovered
 * ocean (an island-/Olympus-enclosed body no origin reached).  Sets defer_n.
 *
 * TODO(#80): try multi-source BFS Voronoi over the water subgraph as an alt.
 */
static void
partition_oceans_deferred(int n, const int *orow, const int *ocol, pcg32_t *rng)
{
	static int frontier[MAX_DIM * MAX_DIM];
	int fn = 0;
	int r, c, i;

	for (r = 0; r < g_size; r++)
		for (c = 0; c < g_size; c++)
			ocean_id[r][c] = -1;

	for (i = 0; i < n; i++) {
		ocean_id[orow[i]][ocol[i]] = i;
		frontier[fn++] = orow[i] * g_size + ocol[i];
	}

	while (fn > 0) {
		int fi = pcg32_range(rng, 0, fn - 1);
		int cell = frontier[fi];
		int cr = cell / g_size;
		int cc = cell % g_size;
		int nb[8];
		int k = 0;
		int d;

		for (d = 0; d < 8; d++) {
			int nr, nc;
			if (!neighbor8(cr, cc, d, &nr, &nc))
				continue;
			if (map[nr][nc] == ' ' && ocean_id[nr][nc] == -1)
				nb[k++] = nr * g_size + nc;
		}
		if (k == 0) {
			frontier[fi] = frontier[--fn];	/* boxed in */
			continue;
		}
		i = nb[pcg32_range(rng, 0, k - 1)];
		ocean_id[i / g_size][i % g_size] = ocean_id[cr][cc];
		frontier[fn++] = i;
	}

	/* Discover origin-less water bodies (single flood each). */
	defer_n = n;
	for (r = 0; r < g_size; r++)
		for (c = 0; c < g_size; c++)
			if (map[r][c] == ' ' && ocean_id[r][c] == -1) {
				int top = 0;
				ocean_id[r][c] = defer_n;
				flood_stack[top++] = r * g_size + c;
				while (top > 0) {
					int pc = flood_stack[--top];
					int pr = pc / g_size;
					int qc = pc % g_size;
					int d;
					for (d = 0; d < 8; d++) {
						int nr, nc;
						if (!neighbor8(pr, qc, d, &nr, &nc))
							continue;
						if (map[nr][nc] == ' ' && ocean_id[nr][nc] == -1) {
							ocean_id[nr][nc] = defer_n;
							flood_stack[top++] = nr * g_size + nc;
						}
					}
				}
				defer_n++;
			}
}

/*
 * 4-color the deferred oceans (ocean_id 0..defer_n-1) with mapgen's 8-neighbor /
 * column-wrap adjacency, painting only water cells (land keeps its glyph).
 * Returns 1 on success, 0 if not 4-colorable (caller reduces the origin count).
 */
static int
color_oceans_deferred(void)
{
	static char adj[MAX_DIM][MAX_DIM];
	int colors[MAX_DIM];
	int r, c, d, i, j;

	assert(defer_n <= MAX_DIM);

	for (i = 0; i < defer_n; i++) {
		for (j = 0; j < defer_n; j++)
			adj[i][j] = 0;
		colors[i] = -1;
	}

	for (r = 0; r < g_size; r++)
		for (c = 0; c < g_size; c++) {
			if (ocean_id[r][c] < 0)
				continue;
			for (d = 0; d < 8; d++) {
				int nr, nc, a, b;
				if (!neighbor8(r, c, d, &nr, &nc))
					continue;
				if (ocean_id[nr][nc] < 0)
					continue;
				a = ocean_id[r][c];
				b = ocean_id[nr][nc];
				if (a != b) {
					adj[a][b] = 1;
					adj[b][a] = 1;
				}
			}
		}

	if (!color_solve(0, defer_n, adj, colors))
		return 0;

	for (r = 0; r < g_size; r++)
		for (c = 0; c < g_size; c++)
			if (ocean_id[r][c] >= 0)
				map[r][c] = ocean_glyph[colors[ocean_id[r][c]]];
	return 1;
}

/*
 * Per-ocean metadata for size-based naming: province count, landlocked flag
 * (never touches a top/bottom border row -- columns wrap, so left/right aren't
 * edges), and an anchor/tie-break cell.  The anchor defaults to each ocean's
 * first row-major cell; seeded oceans (0..seeded_n-1) override it with their
 * actual origin.  Both are valid cells of the region, fine as the output anchor.
 */
static void
compute_ocean_metadata(int seeded_n, const int *orow, const int *ocol)
{
	int r, c, i;

	for (i = 0; i < defer_n; i++) {
		ocean_size[i] = 0;
		ocean_landlocked[i] = 1;
		ocean_origin_r[i] = -1;
		ocean_origin_c[i] = -1;
	}
	for (r = 0; r < g_size; r++)
		for (c = 0; c < g_size; c++) {
			int id = ocean_id[r][c];
			if (id < 0)
				continue;
			ocean_size[id]++;
			if (r == 0 || r == g_size - 1)
				ocean_landlocked[id] = 0;
			if (ocean_origin_r[id] < 0) {
				ocean_origin_r[id] = r;
				ocean_origin_c[id] = c;
			}
		}
	for (i = 0; i < seeded_n; i++) {
		ocean_origin_r[i] = orow[i];
		ocean_origin_c[i] = ocol[i];
	}
}

/*
 * Fill in landlocked water bodies smaller than MIN_NAMED_WATER: mapgen requires
 * every water region to carry a name (island_allowed derefs inside_names[]), so a
 * tiny puddle either clutters Regions or crashes mapgen if left unnamed.  Filling
 * it with land removes it as a water region; the cell merges into the enclosing
 * land mass.  Only landlocked bodies are filled, so this never puts land on the
 * all-water border (the main sea, the one body that touches it, is huge anyway).
 * The fill glyph is 'o' (mapgen's random-terrain marker), so mapgen rolls each
 * filled province's terrain rather than getting a uniform patch.
 * Returns the number of bodies filled.  Must run before coloring/metadata.
 */
static int
fill_tiny_water(void)
{
	int size[MAX_DIM];
	int lock[MAX_DIM];
	int r, c, i, filled = 0;

	for (i = 0; i < defer_n; i++) {
		size[i] = 0;
		lock[i] = 1;
	}
	for (r = 0; r < g_size; r++)
		for (c = 0; c < g_size; c++) {
			int id = ocean_id[r][c];
			if (id < 0)
				continue;
			size[id]++;
			if (r == 0 || r == g_size - 1)
				lock[id] = 0;
		}
	for (r = 0; r < g_size; r++)
		for (c = 0; c < g_size; c++) {
			int id = ocean_id[r][c];
			if (id < 0)
				continue;
			if (size[id] < MIN_NAMED_WATER && lock[id]) {
				map[r][c] = 'o';	/* random terrain; merges into enclosing land */
				ocean_id[r][c] = -1;
			}
		}
	for (i = 0; i < defer_n; i++)
		if (size[i] < MIN_NAMED_WATER && lock[i])
			filled++;
	return filled;
}

/*
 * Driver for --defer-oceans: pick origins, partition, color, retrying with one
 * fewer seeded ocean on either a placement or a coloring failure.  The spacing
 * floor r2 is computed once from the requested count and held fixed, so each
 * reduction is strictly easier; a single ocean always colors, so this terminates.
 */
static void
defer_oceans(int requested, uint64_t seed)
{
	static int orow[MAX_DIM];
	static int ocol[MAX_DIM];
	int cap = ocean_cap();
	int n0 = requested;
	int wn = 0;
	int r, c, n;
	long r2;

	if (n0 > cap) {
		fprintf(stderr,
			"genesis: --number-of-oceans %d exceeds the cap for size %d; using %d\n",
			requested, g_size, cap);
		n0 = cap;
	}

	for (r = 0; r < g_size; r++)
		for (c = 0; c < g_size; c++)
			if (map[r][c] == ' ')
				wn++;
	if (wn < 1) {
		fprintf(stderr, "genesis: no open water left for oceans\n");
		exit(1);
	}

	r2 = (long)(ALPHA_SQ * (double)wn / (double)n0);
	if (r2 < 1)
		r2 = 1;	/* keep origins on distinct cells */

	for (n = n0; n >= 1; n--) {
		pcg32_t rng;
		int nfilled;
		pcg32_seed_step(&rng, seed, STEP_ORIGINS, (uint64_t)n);
		if (!place_origins(n, r2, &rng, orow, ocol)) {
			fprintf(stderr,
				"genesis: couldn't place %d ocean origins; retrying with %d\n",
				n, n - 1);
			continue;
		}
		partition_oceans_deferred(n, orow, ocol, &rng);
		nfilled = fill_tiny_water();
		if (color_oceans_deferred()) {
			compute_ocean_metadata(n, orow, ocol);
			fprintf(stderr,
				"genesis: deferred oceans: %d seeded, %d total, %d tiny filled\n",
				n, defer_n, nfilled);
			return;
		}
		fprintf(stderr,
			"genesis: %d deferred oceans not 4-colorable; retrying with %d\n",
			n, n - 1);
	}

	fprintf(stderr, "genesis: internal error: could not color even one deferred ocean\n");
	exit(1);
}

/* ------------------------------------------------------------------------- */
/* Step: grow one island onto the current map (port of island/island.c).     */
/* MD5 rnd() is replaced by the supplied PCG stream.                          */
/* ------------------------------------------------------------------------- */

/*
 * Original terrain weights.  The GCD/LCM normalization below MUTATES the table,
 * so grow_one_island() works on a fresh per-call copy of this base -- unlike
 * island-g3 (one island per process), genesis grows many islands in one run and
 * a shared mutable table would compound the reductions and corrupt the weights.
 */
static const terrain terrains_base[NUM_TERRAINS] = {
	{ 'p', 12, 30, 30, 0 },
	{ 'f',  6, 14, 30, 0 },
	{ 'm',  6, 10, 20, 0 },
	{ 'd', 15, 30, 10, 0 },
	{ 's',  1,  3, 10, 0 }
};

static void
make_shelf(int y, int x, int shelf)
{
	if (working[y][x] == '~')
		working[y][x] = '_';
	if (shelf < 1)
		return;

	if (y > 0)
		make_shelf(y - 1, x, shelf - 1);
	if (y < g_size - 1)
		make_shelf(y + 1, x, shelf - 1);
	if (x > 0)
		make_shelf(y, x - 1, shelf - 1);
	if (x < g_size - 1)
		make_shelf(y, x + 1, shelf - 1);
}

static void
extend_distance(int y, int x)
{
	if (y > 0 && distance[y - 1][x] > distance[y][x] + 1) {
		distance[y - 1][x] = (char)(distance[y][x] + 1);
		extend_distance(y - 1, x);
	}
	if (y < g_size - 1 && distance[y + 1][x] > distance[y][x] + 1) {
		distance[y + 1][x] = (char)(distance[y][x] + 1);
		extend_distance(y + 1, x);
	}
	if (x > 0 && distance[y][x - 1] > distance[y][x] + 1) {
		distance[y][x - 1] = (char)(distance[y][x] + 1);
		extend_distance(y, x - 1);
	}
	if (x < g_size - 1 && distance[y][x + 1] > distance[y][x] + 1) {
		distance[y][x + 1] = (char)(distance[y][x] + 1);
		extend_distance(y, x + 1);
	}
}

static int
gcd(int a, int b)
{
	int t;
	while (b) {
		t = b;
		b = a % b;
		a = t;
	}
	return a;
}

static int
lcm(int a, int b)
{
	return a * b / gcd(a, b);
}

/* Returns the number of provinces actually grown (may be < target). */
static int
grow_one_island(int target, pcg32_t *rng)
{
	int x, y, x_size = g_size, y_size = g_size;
	int max, count, d, island_size, i;
	int GCD, LCM, o, terr, temp, size, cluster_end, id, nopt;
	terrain terrains[NUM_TERRAINS];

	if (target < 1)
		return 0;

	memcpy(terrains, terrains_base, sizeof terrains);	/* fresh weights per island */

	/* 1. classify: ocean -> '~' (available), everything else -> 'p' (land). */
	for (y = 0; y < y_size; y++)
		for (x = 0; x < x_size; x++) {
			working[y][x] = is_ocean_glyph(map[y][x]) ? '~' : 'p';
			ids[y][x] = 0;
		}

	/* 2. continental shelf: exclude water within SHELF_WIDTH of land. */
	for (y = 0; y < y_size; y++)
		for (x = 0; x < x_size; x++)
			if (working[y][x] == 'p')
				make_shelf(y, x, SHELF_WIDTH);

	/* 3. border: exclude the outer BORDER_WIDTH rows/cols. */
	for (y = 0; y < y_size; y++)
		for (x = 0; x < BORDER_WIDTH; x++) {
			if (working[y][x] == '~')
				working[y][x] = '_';
			if (working[y][x_size - x - 1] == '~')
				working[y][x_size - x - 1] = '_';
		}
	for (x = 0; x < x_size; x++)
		for (y = 0; y < BORDER_WIDTH; y++) {
			if (working[y][x] == '~')
				working[y][x] = '_';
			if (working[y_size - y - 1][x] == '~')
				working[y_size - y - 1][x] = '_';
		}

	/* 4. distance field: distance to nearest non-water, capped at 9. */
	for (y = 0; y < y_size; y++)
		for (x = 0; x < x_size; x++)
			distance[y][x] = (working[y][x] == '~') ? DISTANCE_CAP : 0;
	for (y = 0; y < y_size; y++)
		for (x = 0; x < x_size; x++)
			extend_distance(y, x);

	/* 5a. seed: pick a random max-distance cell (the emptiest water). */
	max = 0;
	count = 0;
	island_size = 0;
	for (y = 0; y < y_size; y++)
		for (x = 0; x < x_size; x++) {
			if (distance[y][x] > max) {
				max = distance[y][x];
				count = 1;
			} else if (distance[y][x] == max) {
				count++;
			}
		}
	if (max < 1 || count < 1)
		return 0;	/* no open water at all */

	d = pcg32_range(rng, 1, count);
	for (y = 0; d > 0 && y < y_size; y++)
		for (x = 0; d > 0 && x < x_size; x++)
			if (distance[y][x] == max) {
				d--;
				if (!d) {
					island_cells[0].x = x;
					island_cells[0].y = y;
					island_size = 1;
					working[y][x] = 'o';
					map[y][x] = 'o';
					ids[y][x] = 0;
				}
			}

	/* 5b. grow: claim a uniformly-random available 4-neighbor until target. */
	while (island_size < target) {
		count = 0;
		for (i = 0; i < island_size; i++) {
			if (island_cells[i].x > 0 && working[island_cells[i].y][island_cells[i].x - 1] == '~')
				count++;
			if (island_cells[i].x < x_size - 1 && working[island_cells[i].y][island_cells[i].x + 1] == '~')
				count++;
			if (island_cells[i].y > 0 && working[island_cells[i].y - 1][island_cells[i].x] == '~')
				count++;
			if (island_cells[i].y < y_size - 1 && working[island_cells[i].y + 1][island_cells[i].x] == '~')
				count++;
		}
		if (count < 1)
			break;		/* boxed in: stop early */

		d = pcg32_range(rng, 0, count - 1);
		for (i = 0; i < island_size; i++) {
			if (island_cells[i].x > 0 && working[island_cells[i].y][island_cells[i].x - 1] == '~')
				if (!d--) {
					island_cells[island_size].x = island_cells[i].x - 1;
					island_cells[island_size].y = island_cells[i].y;
				}
			if (island_cells[i].x < x_size - 1 && working[island_cells[i].y][island_cells[i].x + 1] == '~')
				if (!d--) {
					island_cells[island_size].x = island_cells[i].x + 1;
					island_cells[island_size].y = island_cells[i].y;
				}
			if (island_cells[i].y > 0 && working[island_cells[i].y - 1][island_cells[i].x] == '~')
				if (!d--) {
					island_cells[island_size].x = island_cells[i].x;
					island_cells[island_size].y = island_cells[i].y - 1;
				}
			if (island_cells[i].y < y_size - 1 && working[island_cells[i].y + 1][island_cells[i].x] == '~')
				if (!d--) {
					island_cells[island_size].x = island_cells[i].x;
					island_cells[island_size].y = island_cells[i].y + 1;
				}
		}
		working[island_cells[island_size].y][island_cells[island_size].x] = 'o';
		map[island_cells[island_size].y][island_cells[island_size].x] = 'o';
		ids[island_cells[island_size].y][island_cells[island_size].x] = island_size;
		island_size++;
	}

	/* 5c. terrain: GCD/LCM integer weights, then weighted flood-fill clusters. */
	for (i = 0; i < NUM_TERRAINS; i++) {
		terrains[i].prob = terrains[i].min + terrains[i].max;
		GCD = gcd(terrains[i].target_prob, terrains[i].prob);
		terrains[i].target_prob /= GCD;
		terrains[i].prob /= GCD;
	}
	for (i = 0, LCM = 1; i < NUM_TERRAINS; i++)
		LCM = lcm(LCM, terrains[i].prob);
	for (i = 0, count = 0; i < NUM_TERRAINS; i++) {
		terrains[i].target_prob *= LCM / terrains[i].prob;
		count += terrains[i].target_prob;
	}

	o = island_size;
	size = 0;
	terr = 0;
	while (o > 0) {
		cluster_end = o;
		o--;
		d = pcg32_range(rng, 0, o);
		temp = island_cells[d].x;
		island_cells[d].x = island_cells[o].x;
		island_cells[o].x = temp;
		temp = island_cells[d].y;
		island_cells[d].y = island_cells[o].y;
		island_cells[o].y = temp;
		ids[island_cells[o].y][island_cells[o].x] = o;
		ids[island_cells[d].y][island_cells[d].x] = d;
		if (size < 1) {
			d = pcg32_range(rng, 1, count);
			for (terr = 0; d > terrains[terr].target_prob; terr++)
				d -= terrains[terr].target_prob;
			size = pcg32_range(rng, terrains[terr].min, terrains[terr].max);
		}
		map[island_cells[o].y][island_cells[o].x] = terrains[terr].symbol;
		working[island_cells[o].y][island_cells[o].x] = terrains[terr].symbol;
		size--;
		if (size > o)
			size = o;
		while (size > 0) {
			for (i = o, nopt = 0; i < cluster_end; i++) {
				if (island_cells[i].y > 0 && working[island_cells[i].y - 1][island_cells[i].x] == 'o')
					nopt++;
				if (island_cells[i].y < y_size - 1 && working[island_cells[i].y + 1][island_cells[i].x] == 'o')
					nopt++;
				if (island_cells[i].x > 0 && working[island_cells[i].y][island_cells[i].x - 1] == 'o')
					nopt++;
				if (island_cells[i].x < x_size - 1 && working[island_cells[i].y][island_cells[i].x + 1] == 'o')
					nopt++;
			}
			if (nopt < 1)
				break;
			d = pcg32_range(rng, 0, nopt - 1);
			id = 0;
			for (i = o; i < cluster_end; i++) {
				if (island_cells[i].y > 0 && working[island_cells[i].y - 1][island_cells[i].x] == 'o')
					if (!d--) {
						id = ids[island_cells[i].y - 1][island_cells[i].x];
						break;
					}
				if (island_cells[i].y < y_size - 1 && working[island_cells[i].y + 1][island_cells[i].x] == 'o')
					if (!d--) {
						id = ids[island_cells[i].y + 1][island_cells[i].x];
						break;
					}
				if (island_cells[i].x > 0 && working[island_cells[i].y][island_cells[i].x - 1] == 'o')
					if (!d--) {
						id = ids[island_cells[i].y][island_cells[i].x - 1];
						break;
					}
				if (island_cells[i].x < x_size - 1 && working[island_cells[i].y][island_cells[i].x + 1] == 'o')
					if (!d--) {
						id = ids[island_cells[i].y][island_cells[i].x + 1];
						break;
					}
			}
			o--;
			size--;
			temp = island_cells[id].x;
			island_cells[id].x = island_cells[o].x;
			island_cells[o].x = temp;
			temp = island_cells[id].y;
			island_cells[id].y = island_cells[o].y;
			island_cells[o].y = temp;
			map[island_cells[o].y][island_cells[o].x] = terrains[terr].symbol;
			working[island_cells[o].y][island_cells[o].x] = terrains[terr].symbol;
			ids[island_cells[o].y][island_cells[o].x] = o;
			ids[island_cells[id].y][island_cells[id].x] = id;
		}
	}

	return island_size;
}

static void
add_islands(int iterations, uint64_t seed)
{
	int it, j;
	long total = 0;

	for (it = 1; it <= iterations; it++) {
		int target = island_size_tab[it];
		for (j = 0; j < it; j++) {
			pcg32_t rng;
			pcg32_seed_step(&rng, seed, (uint64_t)(STEP_ISLAND_BASE + it),
				(uint64_t)j);
			total += grow_one_island(target, &rng);
		}
	}
	fprintf(stderr, "genesis: islands grown, %ld land provinces total\n", total);
}

/* ------------------------------------------------------------------------- */
/* Step: Mt. Olympus -- center cell 'O' ringed by 8 'M' (doc/genesis.md).     */
/* ------------------------------------------------------------------------- */

static void
add_olympus(void)
{
	int cr = g_size / 2;
	int cc = g_size / 2;
	int dr, dc;

	for (dr = -1; dr <= 1; dr++)
		for (dc = -1; dc <= 1; dc++) {
			int r = cr + dr;
			int c = cc + dc;
			if (r < 0 || r >= g_size || c < 0 || c >= g_size)
				continue;
			map[r][c] = 'M';
		}
	map[cr][cc] = 'O';
}

/* ------------------------------------------------------------------------- */
/* Region labeling (iterative flood; mirrors mapgen's flood rules).          */
/* ------------------------------------------------------------------------- */

/*
 * Flood the water region (same ->color, 8-neighbor wrap/clamp) reachable from
 * (sr,sc), tagging label[][] = lab.  Mirrors mapgen flood_water_inside.
 */
static void
flood_water(int sr, int sc, int lab)
{
	int top = 0;
	int col0 = ocean_color(map[sr][sc]);

	flood_stack[top++] = sr * g_size + sc;
	label[sr][sc] = lab;

	while (top > 0) {
		int cell = flood_stack[--top];
		int r = cell / g_size;
		int c = cell % g_size;
		int d;
		for (d = 0; d < 8; d++) {
			int nr, nc;
			if (!neighbor8(r, c, d, &nr, &nc))
				continue;
			if (label[nr][nc] != -1)
				continue;
			if (!is_ocean_glyph(map[nr][nc]) || ocean_color(map[nr][nc]) != col0)
				continue;
			label[nr][nc] = lab;
			flood_stack[top++] = nr * g_size + nc;
		}
	}
}

/*
 * Flood a land mass (any non-ocean cell, 8-neighbor wrap/clamp) from (sr,sc).
 * Mirrors mapgen flood_land_inside (ignores color; whole contiguous land mass).
 */
static void
flood_land(int sr, int sc, int lab)
{
	int top = 0;

	flood_stack[top++] = sr * g_size + sc;
	label[sr][sc] = lab;

	while (top > 0) {
		int cell = flood_stack[--top];
		int r = cell / g_size;
		int c = cell % g_size;
		int d;
		for (d = 0; d < 8; d++) {
			int nr, nc;
			if (!neighbor8(r, c, d, &nr, &nc))
				continue;
			if (label[nr][nc] != -1)
				continue;
			if (is_ocean_glyph(map[nr][nc]))
				continue;
			label[nr][nc] = lab;
			flood_stack[top++] = nr * g_size + nc;
		}
	}
}

/* ------------------------------------------------------------------------- */
/* Name pool (region/continent names), drawn without replacement via PCG.    */
/* ------------------------------------------------------------------------- */

static int region_order[sizeof(region_names) / sizeof(region_names[0])];
static int region_pool_n;
static int region_cursor;

static void
init_region_names(uint64_t seed)
{
	pcg32_t rng;
	int i;

	region_pool_n = (int)(sizeof(region_names) / sizeof(region_names[0]));
	for (i = 0; i < region_pool_n; i++)
		region_order[i] = i;

	/* Fisher-Yates shuffle (deterministic on the seed). */
	pcg32_seed_step(&rng, seed, STEP_NAMES, 0);
	for (i = region_pool_n - 1; i > 0; i--) {
		int j = pcg32_range(&rng, 0, i);
		int t = region_order[i];
		region_order[i] = region_order[j];
		region_order[j] = t;
	}
	region_cursor = 0;
}

/* Next region name; appends a numeric suffix once the pool wraps. */
static const char *
next_region_name(void)
{
	static char buf[160];
	int idx = region_order[region_cursor % region_pool_n];
	int wrap = region_cursor / region_pool_n;

	region_cursor++;
	if (wrap == 0)
		snprintf(buf, sizeof buf, "%s", region_names[idx]);
	else
		snprintf(buf, sizeof buf, "%s %d", region_names[idx], wrap + 1);
	return buf;
}

/* ------------------------------------------------------------------------- */
/* Output writers.                                                           */
/* ------------------------------------------------------------------------- */

static void
write_map(void)
{
	FILE *fp = fopen("Map", "w");
	int r, c;

	if (!fp) {
		perror("genesis: can't write Map");
		exit(1);
	}
	for (r = 0; r < g_size; r++) {
		for (c = 0; c < g_size; c++)
			fputc(map[r][c], fp);
		fputc('\n', fp);
	}
	fclose(fp);
}

/*
 * Recast a sea name as a lake name (--defer-oceans editorial touch): swap an
 * embedded "Sea"/"Ocean" for "Lake", else prepend "Lake ".  Returns a static
 * buffer; the caller uses it before the next next_region_name() draw.
 */
static const char *
lake_name(const char *base)
{
	static char buf[200];
	const char *p;

	if ((p = strstr(base, "Sea")) != NULL)
		snprintf(buf, sizeof buf, "%.*sLake%s", (int)(p - base), base, p + 3);
	else if ((p = strstr(base, "Ocean")) != NULL)
		snprintf(buf, sizeof buf, "%.*sLake%s", (int)(p - base), base, p + 5);
	else
		snprintf(buf, sizeof buf, "Lake %s", base);
	return buf;
}

/*
 * --defer-oceans water naming: name the partition oceans by size.  Great Sea is
 * the largest (tie -> the ocean owning (0,0); else origin nearest (0,0); else
 * lowest id).  Every other ocean draws a pool name; a small landlocked body
 * becomes a lake.  Anchored at each ocean's stored origin/first cell.
 */
static void
write_water_regions_deferred(FILE *fp)
{
	int i, great = -1, maxsize = -1;
	int id00 = ocean_id[0][0];

	for (i = 0; i < defer_n; i++)
		if (ocean_size[i] > maxsize)
			maxsize = ocean_size[i];

	if (id00 >= 0 && ocean_size[id00] == maxsize) {
		great = id00;
	} else {
		long best = -1;
		for (i = 0; i < defer_n; i++) {
			long d;
			if (ocean_size[i] != maxsize)
				continue;
			d = dist2(ocean_origin_r[i], ocean_origin_c[i], 0, 0);
			if (best < 0 || d < best) {	/* ties -> lowest id (first seen) */
				best = d;
				great = i;
			}
		}
	}

	fprintf(fp, "%d,%d\tGreat Sea\n", ocean_origin_r[great], ocean_origin_c[great]);
	for (i = 0; i < defer_n; i++) {
		const char *nm;
		if (i == great)
			continue;
		if (ocean_size[i] == 0)
			continue;	/* filled in by fill_tiny_water -- no longer water */
		nm = next_region_name();
		if (ocean_landlocked[i] && ocean_size[i] < LAKE_MAX)
			nm = lake_name(nm);
		fprintf(fp, "%d,%d\t%s\n", ocean_origin_r[i], ocean_origin_c[i], nm);
	}
}

/*
 * Regions: name every sea and continent.  By default the water region containing
 * (0,0) is "Great Sea" (doc/genesis.md); under --defer-oceans the largest ocean
 * is the Great Sea (see write_water_regions_deferred).  All others draw from the
 * pool.
 */
static void
write_regions(void)
{
	FILE *fp = fopen("Regions", "w");
	int r, c, next = 0;

	if (!fp) {
		perror("genesis: can't write Regions");
		exit(1);
	}

	if (g_defer_oceans) {
		write_water_regions_deferred(fp);
	} else {
		int great_sea_label;

		/* Label all water regions. */
		for (r = 0; r < g_size; r++)
			for (c = 0; c < g_size; c++)
				label[r][c] = -1;
		for (r = 0; r < g_size; r++)
			for (c = 0; c < g_size; c++)
				if (label[r][c] == -1 && is_ocean_glyph(map[r][c]))
					flood_water(r, c, next++);

		/* (0,0) is guaranteed ocean (border exclusion keeps islands off edges). */
		great_sea_label = label[0][0];
		fprintf(fp, "0,0\tGreat Sea\n");

		/* Name every other water region at its first (row-major) cell. */
		{
			int lab;
			for (lab = 0; lab < next; lab++) {
				int fr = -1, fc = -1;
				if (lab == great_sea_label)
					continue;
				for (r = 0; r < g_size && fr < 0; r++)
					for (c = 0; c < g_size; c++)
						if (label[r][c] == lab) {
							fr = r;
							fc = c;
							break;
						}
				if (fr >= 0)
					fprintf(fp, "%d,%d\t%s\n", fr, fc, next_region_name());
			}
		}
	}

	/* Label and name each land mass (continent) at its first cell. */
	for (r = 0; r < g_size; r++)
		for (c = 0; c < g_size; c++)
			label[r][c] = -1;
	next = 0;
	for (r = 0; r < g_size; r++)
		for (c = 0; c < g_size; c++)
			if (label[r][c] == -1 && !is_ocean_glyph(map[r][c])) {
				fprintf(fp, "%d,%d\t%s\n", r, c, next_region_name());
				flood_land(r, c, next++);
			}

	fclose(fp);
}

/*
 * Land: name one same-terrain province clump per land mass.  The 'type' glyph
 * must match the cell (set_province_clumps checks save_char == type).
 */
static void
write_land(void)
{
	FILE *fp = fopen("Land", "w");
	int r, c, next = 0;

	if (!fp) {
		perror("genesis: can't write Land");
		exit(1);
	}

	for (r = 0; r < g_size; r++)
		for (c = 0; c < g_size; c++)
			label[r][c] = -1;
	for (r = 0; r < g_size; r++)
		for (c = 0; c < g_size; c++)
			if (label[r][c] == -1 && !is_ocean_glyph(map[r][c]) && map[r][c] != 'O') {
				fprintf(fp, "%d,%d\t%c\t%s\n", r, c, map[r][c], next_region_name());
				flood_land(r, c, next++);
			}

	fclose(fp);
}

static void
write_cities(uint64_t seed)
{
	FILE *fp = fopen("Cities", "w");
	int n = (int)(sizeof(city_names) / sizeof(city_names[0]));
	int *order = malloc((size_t)n * sizeof(int));
	pcg32_t rng;
	int i;

	if (!fp) {
		perror("genesis: can't write Cities");
		exit(1);
	}
	if (!order) {
		fprintf(stderr, "genesis: out of memory\n");
		exit(1);
	}

	for (i = 0; i < n; i++)
		order[i] = i;
	pcg32_seed_step(&rng, seed, STEP_CITIES, 0);
	for (i = n - 1; i > 0; i--) {
		int j = pcg32_range(&rng, 0, i);
		int t = order[i];
		order[i] = order[j];
		order[j] = t;
	}
	for (i = 0; i < n; i++)
		fprintf(fp, "%s\n", city_names[order[i]]);

	free(order);
	fclose(fp);
}

/* randseed: 16 bytes for mapgen's MD5 RNG, derived deterministically. */
static void
write_randseed(uint64_t seed)
{
	FILE *fp = fopen("randseed", "wb");
	uint64_t a, b;

	if (!fp) {
		perror("genesis: can't write randseed");
		exit(1);
	}
	a = splitmix64(seed ^ ((uint64_t)STEP_RANDSEED << 32));
	b = splitmix64(a);
	fwrite(&a, sizeof a, 1, fp);
	fwrite(&b, sizeof b, 1, fp);
	fclose(fp);
}

/* ------------------------------------------------------------------------- */

static void
usage(const char *prog)
{
	fprintf(stderr,
		"Usage: %s [--seed N] [--size 10..99] [--number-of-oceans N]\n"
		"          [--island-iterations 2..10] [--defer-oceans]\n"
		"  --number-of-oceans is capped to min(ceil(size/3), 12) and clamped to\n"
		"  fit; larger requests are reduced with a warning.\n"
		"  --defer-oceans generates the oceans AFTER the islands and Mt. Olympus\n"
		"  (origin-seeded, size-named; largest sea = Great Sea).  See issue #80.\n"
		"Generates the mapgen input set (Map, Regions, Land, Cities, randseed)\n"
		"in the current directory.  See doc/genesis.md.\n", prog);
}

int
main(int argc, char *argv[])
{
	int size = 99;
	int oceans = 9;
	int iterations = 10;
	uint64_t seed = 0;
	int opt;

	static struct option longopts[] = {
		{ "size",              required_argument, 0, 's' },
		{ "number-of-oceans",  required_argument, 0, 'n' },
		{ "island-iterations", required_argument, 0, 'i' },
		{ "seed",              required_argument, 0, 'd' },
		{ "defer-oceans",      no_argument,       0, 'D' },
		{ "help",              no_argument,       0, 'h' },
		{ 0, 0, 0, 0 }
	};

	while ((opt = getopt_long(argc, argv, "s:n:i:d:Dh", longopts, NULL)) != -1)
		switch (opt) {
		case 's': size = atoi(optarg); break;
		case 'n': oceans = atoi(optarg); break;
		case 'i': iterations = atoi(optarg); break;
		case 'd': seed = strtoull(optarg, NULL, 0); break;
		case 'D': g_defer_oceans = 1; break;
		case 'h': usage(argv[0]); return 0;
		default:  usage(argv[0]); return 1;
		}

	if (size < 10 || size > 99) {
		fprintf(stderr, "genesis: --size must be 10..99 (got %d)\n", size);
		return 1;
	}
	/*
	 * Upper bound is the size-scaled cap (issue #78); a larger request is clamped
	 * with a warning in add_oceans rather than rejected, so the default (9) just
	 * works on small maps. Only a nonsensical < 1 is rejected here.
	 */
	if (oceans < 1) {
		fprintf(stderr, "genesis: --number-of-oceans must be >= 1 (got %d)\n", oceans);
		return 1;
	}
	/*
	 * Minimum is 2, not 1: iterations 1 and 2 grow 1 + 2 = 3 islands, which the
	 * continental-shelf spacing keeps as >= 3 distinct land regions. mapgen's
	 * gate_stone_circles needs >= 3 regions to link each stone circle to two
	 * distinct others; fewer used to hang it (issue #75 / #77). One island is
	 * never enough for a playable world anyway.
	 */
	if (iterations < 2 || iterations > 10) {
		fprintf(stderr, "genesis: --island-iterations must be 2..10 (got %d)\n", iterations);
		return 1;
	}

	g_size = size;
	fprintf(stderr, "genesis: seed=%llu size=%d oceans=%d iterations=%d%s\n",
		(unsigned long long)seed, size, oceans, iterations,
		g_defer_oceans ? " (defer-oceans)" : "");

	/* Each step reseeds its own stream off the user seed (see doc/genesis.md). */
	if (g_defer_oceans) {
		/*
		 * Deferred: islands need valid water to grow into, so fill the canvas
		 * first, grow the world, then carve oceans out of what water remains.
		 */
		fill_ocean_canvas();
		add_islands(iterations, seed);
		add_olympus();
		defer_oceans(oceans, seed);
	} else {
		oceans = add_oceans(oceans, seed);	/* caps/clamps + retries to a colorable count */
		add_islands(iterations, seed);
		add_olympus();
	}

	init_region_names(seed);
	write_map();
	write_regions();
	write_land();
	write_cities(seed);
	write_randseed(seed);

	fprintf(stderr, "genesis: wrote Map, Regions, Land, Cities, randseed\n");
	return 0;
}
