/*
 * genesis/pcg.h -- PCG32 generator + splitmix64 seed mixing for genesis-g3.
 *
 * This is a genesis-PRIVATE RNG.  The doc (doc/genesis.md) requires PCG and the
 * property that every generation STEP reseeds its stream from the user seed, so
 * steps can be reordered without changing any step's outcome.  It deliberately
 * does NOT use the engine's MD5-backed lib/rng.c / rnd.c (those stay byte-locked
 * for the golden gates).  splitmix64 is the same mixer used in olympia/buy.c.
 */
#ifndef GENESIS_PCG_H
#define GENESIS_PCG_H

#include <stdint.h>

typedef struct {
	uint64_t state;
	uint64_t inc;
} pcg32_t;

/* 64-bit avalanche mixer (identical to olympia/buy.c splitmix64). */
uint64_t splitmix64(uint64_t x);

/* Initialize a generator from an explicit (state, sequence) pair. */
void pcg32_init(pcg32_t *r, uint64_t initstate, uint64_t initseq);

/*
 * Seed a generator for one generation step.  The (seed, step, island) tuple is
 * folded through splitmix64 into a PCG (state, sequence) pair, so each step's
 * stream is a deterministic function of the user seed alone -- reordering steps
 * leaves every step byte-identical.  Pass island = 0 for whole-step draws.
 */
void pcg32_seed_step(pcg32_t *r, uint64_t seed, uint64_t step, uint64_t island);

/* Raw 32-bit draw (advances the stream). */
uint32_t pcg32_next(pcg32_t *r);

/*
 * Unbiased bounded draw in [lo, hi] inclusive (bitmask + rejection), matching
 * the semantics of the legacy rnd(low, high) the island port is derived from.
 * Requires hi >= lo.
 */
int pcg32_range(pcg32_t *r, int lo, int hi);

#endif /* GENESIS_PCG_H */
