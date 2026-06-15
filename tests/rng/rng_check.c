/*
 *  Standalone self-check for the prototype rng_* layer (issue #25).
 *
 *  Proves the three design claims the layer is meant to deliver, WITHOUT
 *  touching the engine or the golden manifest (it links only lib/rng.c +
 *  lib/rnd.c). See doc/rng-state-granularity.md.
 *
 *    1. Determinism          -- same key always yields the same value.
 *    2. Keyed independence    -- inserting an unrelated keyed draw does not
 *                                move another keyed draw (the blast-radius win
 *                                in miniature).
 *    3. Order-independence    -- a child stream depends only on its key, not on
 *                                how many siblings were derived first.
 *
 *  It also demonstrates the CONTRAST that motivates the work: sequential
 *  rng_draw() within a stream IS sequence-dependent (informational, not a
 *  failure) -- which is exactly why keyed leaf draws are the isolation tool.
 *
 *  Exit 0 = all asserted claims hold; nonzero = a claim failed.
 */

#include <stdio.h>
#include <stdint.h>
#include "rng.h"

/* purpose tags (arbitrary, stable) */
#define TAG_COMBAT 0x636f6d62u	/* "comb" */
#define TAG_MARKET 0x6d726b74u	/* "mrkt" */
#define TAG_HIT    0x68697420u	/* "hit " */
#define TAG_DMG    0x646d6720u	/* "dmg " */
#define TAG_MORALE 0x6d726c20u	/* "mrl " */

static int failures = 0;

static void
check(const char *name, int ok)
{
	printf("  [%s] %s\n", ok ? "PASS" : "FAIL", name);
	if (!ok)
		failures++;
}

static int
seeds_equal(const rng_stream *a, const rng_stream *b)
{
	return a->seed[0] == b->seed[0] && a->seed[1] == b->seed[1] &&
	       a->seed[2] == b->seed[2] && a->seed[3] == b->seed[3];
}

int
main(void)
{
	const uint32_t master[4] = { 0x01234567u, 0x89abcdefu,
				     0xfedcba98u, 0x76543210u };
	rng_stream root = rng_seed(master);

	printf("rng_* prototype self-check (issue #25)\n");

	/* 1. Determinism: identical inputs -> identical output. */
	{
		int a = rng_keyed(&root, 501, 17, TAG_HIT, 1, 100);
		int b = rng_keyed(&root, 501, 17, TAG_HIT, 1, 100);
		check("determinism: same key -> same value", a == b);
	}

	/*
	 * 2. Keyed independence: a battle draws hit then damage. Inserting a
	 *    brand-new morale draw BETWEEN them must not move hit or damage --
	 *    because each is keyed, not position-dependent.
	 */
	{
		rng_stream battle = rng_stream_of(&root, 501, TAG_COMBAT);

		int hit1 = rng_keyed(&battle, 1, 0, TAG_HIT, 1, 20);
		int dmg1 = rng_keyed(&battle, 1, 0, TAG_DMG, 1, 6);

		/* later code inserts a morale check between hit and damage */
		int hit2    = rng_keyed(&battle, 1, 0, TAG_HIT, 1, 20);
		int morale2 = rng_keyed(&battle, 1, 0, TAG_MORALE, 1, 10);
		int dmg2    = rng_keyed(&battle, 1, 0, TAG_DMG, 1, 6);
		(void)morale2;

		check("keyed independence: hit unmoved by inserted draw",
		      hit1 == hit2);
		check("keyed independence: damage unmoved by inserted draw",
		      dmg1 == dmg2);
	}

	/*
	 * 3. Order-independent derivation: deriving the combat stream before or
	 *    after the market stream yields identical seeds for each.
	 */
	{
		rng_stream combat_a = rng_stream_of(&root, 0, TAG_COMBAT);
		rng_stream market_a = rng_stream_of(&root, 0, TAG_MARKET);

		rng_stream market_b = rng_stream_of(&root, 0, TAG_MARKET);
		rng_stream combat_b = rng_stream_of(&root, 0, TAG_COMBAT);

		check("order-independence: combat stream stable",
		      seeds_equal(&combat_a, &combat_b));
		check("order-independence: market stream stable",
		      seeds_equal(&market_a, &market_b));
		check("distinct tags -> distinct streams",
		      !seeds_equal(&combat_a, &market_a));
	}

	/*
	 * Contrast (informational): sequential rng_draw IS sequence-dependent.
	 * Inserting one draw shifts the rest -- which is why the global serial
	 * stream couples everything, and why keyed draws above are the fix.
	 */
	{
		rng_stream s1 = rng_stream_of(&root, 7, TAG_COMBAT);
		rng_stream s2 = s1;	/* same starting state */

		int a1 = rng_draw(&s1, 1, 1000000);
		int a2 = rng_draw(&s1, 1, 1000000);

		(void)rng_draw(&s2, 1, 1000000);	/* an inserted draw */
		int b1 = rng_draw(&s2, 1, 1000000);
		int b2 = rng_draw(&s2, 1, 1000000);

		printf("  [info] sequential draws shift when reordered: "
		       "%d,%d vs %d,%d\n", a1, a2, b1, b2);
	}

	if (failures == 0) {
		printf("YES (all %s)\n", "claims hold");
		return 0;
	}
	printf("NO (%d claim(s) failed)\n", failures);
	return 1;
}
