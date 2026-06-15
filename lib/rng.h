/*
 *  Prototype: addressable, hierarchical RNG layer (issue #25 groundwork).
 *
 *  The legacy generator (lib/rnd.c) advances ONE process-global digest in
 *  strict call order, so reordering or adding a single rnd() call anywhere
 *  shifts every downstream draw and re-bakes the whole golden manifest. This
 *  layer is the seam for the recommended fix: derive randomness from stable
 *  keys (a hierarchy of deterministic seeds with keyed leaf draws) instead of
 *  from stream position. See doc/rng-state-granularity.md.
 *
 *  It is MD5-backed (reuses MD5() from rnd.h) -- the generator is NOT being
 *  replaced here; PCG32 is a separate, later track. This prototype is
 *  intentionally UNWIRED: nothing in the engine/mapgen/island calls it yet,
 *  so golden output stays byte-identical. It exists to be reviewed and to back
 *  a standalone self-check (tests/rng/).
 */

#ifndef OLYMPIA_RNG_H
#define OLYMPIA_RNG_H

#include <stdint.h>

/*
 *  A stream is a 128-bit seed plus a counter for sequential draws. Copy it by
 *  value; there is no global state. Derive children with rng_stream_of(), draw
 *  sequentially with rng_draw(), or draw position-independently with
 *  rng_keyed().
 */
typedef struct {
	uint32_t seed[4];
	uint32_t counter;
} rng_stream;

/* Root stream from a 16-byte master seed (e.g. the lib/randseed bytes). */
extern rng_stream rng_seed(const uint32_t master[4]);

/*
 *  Derive a child stream from a parent + an integer key + a purpose tag.
 *  Order-independent: the same (parent, key, tag) always yields the same child
 *  regardless of how many siblings were derived first -- so initializing the
 *  combat stream before or after the market stream cannot move either one.
 */
extern rng_stream rng_stream_of(const rng_stream *parent, int key, uint32_t tag);

/*
 *  Sequential draw in [low, high]; advances s->counter. A convenience for
 *  migrating an ordered run of legacy rnd() calls that share one scope. Still
 *  sequence-dependent WITHIN the stream, but isolated from every other stream.
 */
extern int rng_draw(rng_stream *s, int low, int high);

/*
 *  Keyed leaf draw in [low, high]. The value depends only on
 *  (stream, k1, k2, tag) -- NOT on how many draws happened before it. Inserting
 *  or removing an unrelated draw cannot perturb it. This is the strongest
 *  isolation (it generalizes the existing md5_int() helper).
 */
extern int rng_keyed(const rng_stream *s, int k1, int k2, uint32_t tag,
		     int low, int high);

#endif /* OLYMPIA_RNG_H */
