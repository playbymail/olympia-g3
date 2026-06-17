/*
 * genesis/pcg.c -- PCG32 generator + splitmix64 seed mixing for genesis-g3.
 * See genesis/pcg.h for the contract and rationale.
 */

#include "pcg.h"

/* Minimal-period PCG32 (O'Neill, pcg-random.org) -- the classic constants. */
#define PCG_MULT	6364136223846793005ULL

uint64_t
splitmix64(uint64_t x)
{
	x += 0x9e3779b97f4a7c15ULL;
	x = (x ^ (x >> 30)) * 0xbf58476d1ce4e5b9ULL;
	x = (x ^ (x >> 27)) * 0x94d049bb133111ebULL;
	x = x ^ (x >> 31);
	return x;
}

uint32_t
pcg32_next(pcg32_t *r)
{
	uint64_t old = r->state;
	uint32_t xorshifted;
	uint32_t rot;

	r->state = old * PCG_MULT + r->inc;
	xorshifted = (uint32_t)(((old >> 18) ^ old) >> 27);
	rot = (uint32_t)(old >> 59);

	/* rotate right by rot (rot in 0..31); the (-rot & 31) form is branchless. */
	return (xorshifted >> rot) | (xorshifted << (((uint32_t)(-(int32_t)rot)) & 31));
}

void
pcg32_init(pcg32_t *r, uint64_t initstate, uint64_t initseq)
{
	r->state = 0;
	r->inc = (initseq << 1) | 1;	/* inc must be odd */
	(void) pcg32_next(r);
	r->state += initstate;
	(void) pcg32_next(r);
}

void
pcg32_seed_step(pcg32_t *r, uint64_t seed, uint64_t step, uint64_t island)
{
	uint64_t k;
	uint64_t s0;
	uint64_t s1;

	/* Mix the tuple, then split into two independent 64-bit halves. */
	k = splitmix64(seed
		+ step * 0x9e3779b97f4a7c15ULL
		+ island * 0xd1b54a32d192ed03ULL);
	s0 = splitmix64(k);
	s1 = splitmix64(s0);

	pcg32_init(r, s0, s1);
}

int
pcg32_range(pcg32_t *r, int lo, int hi)
{
	uint32_t range = (uint32_t)(hi - lo);
	uint32_t mask = 0;
	uint32_t n;
	uint32_t x;

	for (x = range; x; x >>= 1)
		mask |= x;

	do {
		n = pcg32_next(r) & mask;
	} while (n > range);

	return (int)(n + (uint32_t)lo);
}
