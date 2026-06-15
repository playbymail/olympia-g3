/*
 *  Prototype: addressable, hierarchical RNG layer (issue #25 groundwork).
 *
 *  MD5-backed; reuses MD5() from rnd.h as the tuple -> 128-bit seed hash. The
 *  per-draw range reduction mirrors legacy rnd() exactly (lib/rnd.c): a bit
 *  mask covering the range, then a rejection loop that re-hashes the working
 *  digest until a draw lands in [0, range]. This keeps the distribution
 *  semantics identical to the legacy generator -- only the *addressing* changes
 *  (a draw is keyed on stable inputs instead of global stream position).
 *
 *  Intentionally UNWIRED: nothing else links against these symbols yet, so the
 *  engine/mapgen/island output is byte-identical. See doc/rng-state-granularity.md.
 */

#include <stdint.h>
#include "rnd.h"		/* MD5() */
#include "rng.h"

/*
 *  Mask + rejection reduction of a 128-bit working digest into [low, high].
 *  `h` is advanced in place by MD5 on each rejection, exactly like rnd()'s
 *  treatment of the global digest -- so the loop is deterministic given the
 *  digest it starts from.
 */
static int
reduce_range(uint32_t h[4], int low, int high)
{
	unsigned int range = (unsigned int)(high - low);	/* high >= low */
	unsigned int mask = 0;
	unsigned int num;
	int r;

	for (r = (int)range; r; r >>= 1)
		mask |= (unsigned int)r;

	do {
		MD5(h, h, 4 * (int)sizeof(uint32_t));
		num = h[0] & mask;
	} while (num > range);

	return (int)(num + (unsigned int)low);
}

rng_stream
rng_seed(const uint32_t master[4])
{
	rng_stream s;

	s.seed[0] = master[0];
	s.seed[1] = master[1];
	s.seed[2] = master[2];
	s.seed[3] = master[3];
	s.counter = 0;

	return s;
}

rng_stream
rng_stream_of(const rng_stream *parent, int key, uint32_t tag)
{
	rng_stream child;
	uint32_t in[6];

	in[0] = parent->seed[0];
	in[1] = parent->seed[1];
	in[2] = parent->seed[2];
	in[3] = parent->seed[3];
	in[4] = (uint32_t)key;
	in[5] = tag;

	MD5(child.seed, in, (int)sizeof(in));
	child.counter = 0;

	return child;
}

int
rng_draw(rng_stream *s, int low, int high)
{
	uint32_t h[4];
	uint32_t in[5];

	in[0] = s->seed[0];
	in[1] = s->seed[1];
	in[2] = s->seed[2];
	in[3] = s->seed[3];
	in[4] = s->counter;

	s->counter++;

	MD5(h, in, (int)sizeof(in));

	return reduce_range(h, low, high);
}

int
rng_keyed(const rng_stream *s, int k1, int k2, uint32_t tag, int low, int high)
{
	uint32_t h[4];
	uint32_t in[7];

	in[0] = s->seed[0];
	in[1] = s->seed[1];
	in[2] = s->seed[2];
	in[3] = s->seed[3];
	in[4] = (uint32_t)k1;
	in[5] = (uint32_t)k2;
	in[6] = tag;

	MD5(h, in, (int)sizeof(in));

	return reduce_range(h, low, high);
}
