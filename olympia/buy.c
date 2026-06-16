

#include 	<stdlib.h>
#include	<stdio.h>
#include	"z.h"
#include	"oly.h"
#include	"rng.h"


/*
 *  Issue #25: economy/market draws -- city trade seeding (seed_city_trade in
 *  seed.c), the per-turn suffuse-ring restock, and the FIND BUY/SELL trade
 *  goods -- draw from a per-market RNG stream instead of the global rnd()
 *  serial stream. The stream is derived from the immutable master seed + turn +
 *  market location, so a city's trade rolls are addressable and no longer
 *  depend on how many global draws preceded them: a change to an unrelated
 *  subsystem can no longer perturb a market. begin_economy(where) reseeds it per
 *  market; the econ_*() helpers are keyed leaf draws (rng_keyed) so inserting or
 *  removing one market roll cannot move a sibling roll (the leaf key is
 *  (item, where, purpose), as recommended in doc/rng-state-granularity.md).
 *
 *  The non-market city seeding that runs in the same INIT pass -- skill teaching
 *  and prominence (seed_city_skill / choose_city_prominence) and garrisons
 *  (add_city_garrisons) -- has since moved onto the "wgen" worldgen stream
 *  (issue #25 step 11, seed.c), not market-specific. The production/skill player
 *  commands in produce.c stay on the global rnd() (an economy residual).
 *  The md5_int() buyer test in d_find_buy() (below) is already a keyed leaf and
 *  is intentionally turn-INDEPENDENT -- the set of buyer cities must be stable
 *  across turns -- so it stays as-is rather than moving onto the turn-keyed
 *  stream. Its 4th md5_int() arg (the buyer secret) is per-game; see issue #46
 *  and the trade-route-secret block below.
 */
static rng_stream economy_rng;

/*
 *  Issue #46: per-game trade-route buyer secret.
 *
 *  The FIND BUY buyer test in d_find_buy() picks which cities will buy a given
 *  tradegood via md5_int(city_sold, where, item, SECRET) & 1. The set must stay
 *  stable for the life of a game (a buyer this turn is a buyer next turn), so the
 *  draw is turn-INDEPENDENT -- it is NOT on the per-turn economy_rng stream.
 *
 *  The legacy SECRET was a hardcoded 0xb05c0e, which gave the buyer map ZERO
 *  per-game entropy: two games built on the same map (same city ids) shared an
 *  identical route table, and anyone with the source + a city list could compute
 *  every route offline. We now derive the secret from an optional per-game GM
 *  seed (splitmix64, folded 64->32). With NO seed the secret stays 0xb05c0e
 *  UNMIXED, so the default golden flow is byte-identical and no file is written.
 *  When a seed is supplied (the -G flag or lib/trade-route-seed, consulted only
 *  at game creation), the ORIGINAL seed is persisted to lib/trade_routes so the
 *  GM can recover it and rebuild the same game; a persisted lib/trade_routes
 *  always wins on a continuing game, so the secret can never change mid-game.
 *  Scope is routes only -- the per-market econ_*() stream above is unaffected.
 */
#define	TRADE_ROUTE_DEFAULT_SECRET	0xb05c0eu

static int trade_route_have_seed = FALSE;	/* a custom seed is in effect    */
static uint64_t trade_route_seed = 0;		/* the original GM seed (recover) */
static uint32_t trade_route_secret = TRADE_ROUTE_DEFAULT_SECRET;

/*
 *  main.c stashes a "-G <seed>" here (before load_db); init_trade_routes()
 *  consumes it, subject to the persisted-file-wins precedence.
 */
int trade_route_seed_pending = FALSE;
uint64_t trade_route_seed_value = 0;

static uint64_t
splitmix64(uint64_t x)
{
	x += 0x9e3779b97f4a7c15ULL;
	x = (x ^ (x >> 30)) * 0xbf58476d1ce4e5b9ULL;
	x = (x ^ (x >> 27)) * 0x94d049bb133111ebULL;
	x = x ^ (x >> 31);
	return x;
}

static void
apply_trade_route_seed(uint64_t seed)
{
	uint64_t s = splitmix64(seed);

	trade_route_have_seed = TRUE;
	trade_route_seed = seed;
	trade_route_secret = (uint32_t)(s ^ (s >> 32));		/* fold 64 -> 32 */
}

/*
 *  Establish the per-game buyer secret. Precedence:
 *	1. a persisted lib/trade_routes (continuing game) -- always wins;
 *	   -G / the input file are ignored with a warning.
 *	2. -G <seed> (new game).
 *	3. lib/trade-route-seed input file (new game).
 *	4. the legacy default 0xb05c0e (no per-game entropy, no file written).
 */
void
init_trade_routes(void)
{
	FILE *fp;
	char *fnam;
	unsigned long long seed;

	fnam = sout("%s/trade_routes", libdir);
	fp = fopen(fnam, "r");
	if (fp)
	{
		if (fscanf(fp, "%llu", &seed) == 1)
			apply_trade_route_seed((uint64_t) seed);
		fclose(fp);

		if (trade_route_seed_pending)
			fprintf(stderr, "trade-route seed: %s already exists; "
					"ignoring -G/lib/trade-route-seed\n", fnam);
		return;
	}

	if (trade_route_seed_pending)
	{
		apply_trade_route_seed(trade_route_seed_value);
		return;
	}

	fnam = sout("%s/trade-route-seed", libdir);
	fp = fopen(fnam, "r");
	if (fp)
	{
		if (fscanf(fp, "%llu", &seed) == 1)
			apply_trade_route_seed((uint64_t) seed);
		fclose(fp);
	}
}

/*
 *  Persist the original GM seed so the game's route table is reproducible.
 *  Only written when a custom seed is in effect -- the default flow writes no
 *  file, keeping the golden manifest unchanged.
 */
void
save_trade_routes(void)
{
	FILE *fp;
	char *fnam;

	if (!trade_route_have_seed)
		return;

	fnam = sout("%s/trade_routes", libdir);
	fp = fopen(fnam, "w");
	if (fp == NULL)
	{
		fprintf(stderr, "couldn't write %s: ", fnam);
		perror("");
		return;
	}

	fprintf(fp, "%llu\n", (unsigned long long) trade_route_seed);
	fclose(fp);
}

#define	TAG_TURN	0x7475726eu	/* "turn" */
#define	TAG_ECONOMY	0x65636f6eu	/* "econ" */

/* economy leaf-draw purpose tags (kept private, like combat.c's stream tags) */
#define	ETAG_PICK	0x7069636bu	/* "pick" -- choose one of several goods  */
#define	ETAG_STOCK	0x73746f6bu	/* "stok" -- does the market carry a good */
#define	ETAG_QTY	0x716e7479u	/* "qnty" -- quantity offered             */
#define	ETAG_COST	0x636f7374u	/* "cost" -- price                        */
#define	ETAG_EXPIRE	0x65787072u	/* "expr" -- expiry countdown             */
#define	ETAG_MINE	0x6d696e65u	/* "mine" -- mine gate-crystal find       */
#define	ETAG_HARVEST	0x68617276u	/* "harv" -- per-harvest yield chance     */
#define	ETAG_RING	0x72696e67u	/* "ring" -- suffuse-ring kind on restock */

void
begin_economy(int where)
{
	uint32_t m[4];
	rng_stream root, turn;

	rng_master_seed(m);
	root = rng_seed(m);
	turn = rng_stream_of(&root, sysclock.turn, TAG_TURN);
	economy_rng = rng_stream_of(&turn, where, TAG_ECONOMY);
}

int
econ_pick(int item, int where, int low, int high)
{
	return rng_keyed(&economy_rng, item, where, ETAG_PICK, low, high);
}

int
econ_stock(int item, int where, int low, int high)
{
	return rng_keyed(&economy_rng, item, where, ETAG_STOCK, low, high);
}

int
econ_qty(int item, int where, int low, int high)
{
	return rng_keyed(&economy_rng, item, where, ETAG_QTY, low, high);
}

int
econ_cost(int item, int where, int low, int high)
{
	return rng_keyed(&economy_rng, item, where, ETAG_COST, low, high);
}

int
econ_expire(int item, int where, int low, int high)
{
	return rng_keyed(&economy_rng, item, where, ETAG_EXPIRE, low, high);
}

/*
 *  Issue #25 Unit A: skills/magic economy residuals routed onto the existing
 *  per-market stream. Each is a keyed leaf on (item, where) with its own purpose
 *  tag, so it shares begin_economy(where) with the city-trade rolls but cannot
 *  perturb (or be perturbed by) them.
 *
 *    econ_mine    -- produce.c finish_generic_mine gate-crystal find (MINE)
 *    econ_harvest -- produce.c d_generic_harvest per-harvest yield chance
 *    econ_ring    -- art.c new_suffuse_ring kind pick (per-turn faery/cloud restock)
 *
 *  Because these are keyed leaves (not stream-position draws), the mine/harvest
 *  yield is deterministic per (item, where, turn): a multi-day MINE/HARVEST now
 *  draws the same roll each day rather than an independent roll per day. This is
 *  the documented keyed-leaf consequence and is byte-neutral on both golden trees
 *  (neither issues a MINE/HARVEST command). See doc/rng-state-granularity.md.
 */
int
econ_mine(int item, int where, int low, int high)
{
	return rng_keyed(&economy_rng, item, where, ETAG_MINE, low, high);
}

int
econ_harvest(int item, int where, int low, int high)
{
	return rng_keyed(&economy_rng, item, where, ETAG_HARVEST, low, high);
}

int
econ_ring(int item, int where, int low, int high)
{
	return rng_keyed(&economy_rng, item, where, ETAG_RING, low, high);
}


/*
 *  Explanation of trade->cloak field:
 *
 *	0	normal -- open buy or sell, list in market report
 *	1	cloak trader, but list in market report
 *	2	invisible -- don't list in market report, cloak trader
 */

/*
 *  How it works
 *
 *  Each unit has a list of possible trades.
 *  Each trade is either a buy or a sell.
 *  When a trade is entered with the BUY or SELL command, the
 *	list of possible trades from other units in the city
 *	is consulted for a possible match.
 *  If no match is found, the trade is added to the unit's list
 *	of pending trades.
 *  When a unit enters the city, their trades are scanned to see if
 *	any match the pending trades of other units in the city.
 *  When an item is added to a unit, a check is made to see if the
 *	addition might validate a pending trade.  If so, we will try
 *	to match pending trades for the unit when the command is
 *	finished running.
 *	(perhaps this should happen at the end of the day?)
 */

static int
market_here(int who)
{

	while (who > 0 && subkind(who) != sub_city)
	{
		if (is_ship(who))
			return 0;

		who = loc(who);
	}

	return who;
}


void
clear_all_trades(int who)
{
	struct trade *t;

	loop_trade(who, t)
	{
		my_free(t);
	}
	next_trade;

	trades_clear(&bx[who]->trades);
}


static int
seller_comp(const void *av, const void *bv)
{
	trades_list a = (trades_list) av;
	trades_list b = (trades_list) bv;

	if ((*a)->cost == (*b)->cost)
		return (*a)->sort - (*b)->sort;

	return (*a)->cost - (*b)->cost;
}


static trades_list
seller_list(int where, int except)
{
	static trades_list l = NULL;
	int i;
	struct trade *t;
	int count = 0;

	trades_clear(&l);

	loop_char_here(where, i)
	{
/*
 *  Don't trade with ourselves, moving characters, or prisoners
 */
		if (i == except || is_prisoner(i) || char_moving(i))
			continue;

		loop_trade(i, t)
		{
			if (t->kind == SELL)
			{
				t->sort = count++;
				trades_append(&l, t);
			}
		}
		next_trade;
	}
	next_char_here;

	if (trades_len(l) > 0)
		safe_qsort(l, (unsigned) trades_len(l), sizeof(*l), seller_comp);

	loop_trade(where, t)
	{
		if (t->kind == SELL)
			trades_append(&l, t);
	}
	next_trade;

	return l;
}


static trades_list
buyer_list(int where, int except)
{
	static trades_list l = NULL;
	int i;
	struct trade *t;

	trades_clear(&l);

	loop_char_here(where, i)
	{
/*
 *  Don't trade with ourselves, moving characters, or prisoners
 */
		if (i == except || is_prisoner(i) || char_moving(i))
			continue;

		loop_trade(i, t)
		{
			if (t->kind == BUY)
				trades_append(&l, t);
		}
		next_trade;
	}
	next_char_here;

	loop_trade(where, t)
	{
		if (t->kind == BUY)
			trades_append(&l, t);
	}
	next_trade;

	return l;
}


/*
 *  If we're a buyer, reduce qty to how many we can afford, given cost
 *  If we're a seller, reduce qty to how many we actually have to sell
 *  If we're a city, leave qty alone, since we just gen the gold or item
 *
 *  Also reduce such that we don't exceed our own have_left requirement
 */

static int
reduce_qty(struct trade *t, int cost)
{
	int has;

	if (kind(t->who) == T_loc)
		return t->qty;

	if (t->kind == BUY)
	{
		has = has_item(t->who, item_gold) - t->have_left;
		if (has < 0)
			has = 0;

		return min(t->qty, has / cost);
	}

	if (t->kind == SELL)
	{
		has = has_item(t->who, t->item) - t->have_left;
		if (has < 0)
			has = 0;

		return min(t->qty, has);
	}

	assert(FALSE);
	return 0;
}


static void
attempt_trade(struct trade *buyer, struct trade *seller)
{
	int item = buyer->item;
	int qty;
	int cost;
	char *seller_s;
	char *buyer_s;
	extern int gold_pot_basket;
	extern int gold_trade;
	extern int gold_opium;

	assert(buyer != NULL);
	assert(seller != NULL);
	assert(buyer->item == seller->item);

	if (buyer->cost < seller->cost)
		return;

	{
		int buyer_qty;
		int seller_qty;

		buyer_qty = reduce_qty(buyer, seller->cost);
		seller_qty = reduce_qty(seller, seller->cost);

		qty = min(buyer_qty, seller_qty);
	}

	if (qty <= 0)
		return;

	cost = seller->cost * qty;

	buyer->qty -= qty;
	seller->qty -= qty;

	assert(buyer->qty >= 0);
	assert(seller->qty >= 0);

	if (kind(buyer->who) == T_loc)
	{
		gen_item(seller->who, item_gold, cost);
		consume_item(seller->who, item, qty);

		if (item == item_pot || item == item_basket)
			gold_pot_basket += cost;
		else if (item == item_opium)
		{
			log_write(LOG_SPECIAL, "%s earned %s selling opium.",
					box_name(seller->who), gold_s(cost));
			gold_opium += cost;
		}
		else
			gold_trade += cost;
	}
	else if (kind(seller->who) == T_loc)
	{
		consume_item(buyer->who, item_gold, cost);

		if (item_unique(item))
			move_item(seller->who, buyer->who, item, qty);
		else
			gen_item(buyer->who, item, qty);
	}
	else
	{
		move_item(buyer->who, seller->who, item_gold, cost);
		move_item(seller->who, buyer->who, item, qty);
	}

	if (seller->cloak)
		seller_s = "";
	else
		seller_s = sout(" from %s", box_name(seller->who));

	if (buyer->cloak)
		buyer_s = "";
	else
		buyer_s = sout(" to %s", box_name(buyer->who));

	if (kind(buyer->who) != T_loc)
		wout(buyer->who, "Bought %s%s for %s.",
			box_name_qty(item, qty),
			seller_s,
			gold_s(cost));

	if (kind(seller->who) != T_loc)
		wout(seller->who, "Sold %s%s for %s.",
			box_name_qty(item, qty),
			buyer_s,
			gold_s(cost));

	{
		int where;

		if (kind(buyer->who) == T_loc)
			where = buyer->who;
		else if (kind(seller->who) == T_loc)
			where = seller->who;
		else
			where = subloc(buyer->who);

		if (!seller->cloak && !buyer->cloak)
		{
			wout(where, "%s bought %s from %s for %s.",
				box_name(buyer->who),
				box_name_qty(item, qty),
				box_name(seller->who),
				gold_s(cost));
		}
		else if (seller->cloak)
		{
			wout(where, "%s bought %s for %s.",
				box_name(buyer->who),
				box_name_qty(item, qty),
				gold_s(cost));
		}
		else if (buyer->cloak)
		{
			wout(where, "%s sold %s for %s.",
				box_name(seller->who),
				box_name_qty(item, qty),
				gold_s(cost));
		}
	}
}


static void
scan_trades(struct trade *t, trades_list l)
{
	int i;

	for (i = 0; i < trades_len(l) && t->qty > 0; i++)
	{
		if (l[i]->item != t->item)
			continue;

		if (l[i]->who == t->who)
			continue;	/* don't trade with ourself */

		if (t->kind == BUY)
			attempt_trade(t, l[i]);
		else if (t->kind == SELL)
			attempt_trade(l[i], t);
	}
}


void
match_trades(int who)
{
	struct trade *t;
	int where = subloc(who);
	int first_buy = TRUE;
	int first_sell = TRUE;
	trades_list sellers;
	trades_list buyers;

	if (!market_here(who))
		return;

	loop_trade(who, t)
	{
		assert(t->who == who);

		if (t->kind == BUY)
		{
			if (first_buy)
			{
				first_buy = FALSE;
				sellers = seller_list(where, who);
			}

			scan_trades(t, sellers);
		}
		else if (t->kind == SELL)
		{
			if (first_sell)
			{
				first_sell = FALSE;
				buyers = buyer_list(where, who);
			}

			scan_trades(t, buyers);
		}
	}
	next_trade;
}


void
match_all_trades(void)
{
	int where;
	trades_list sellers;
	trades_list buyers;
	int i;

	loop_loc(where)
	{
		if (!market_here(where))
			continue;

		sellers = seller_list(where, 0);
		buyers = buyer_list(where, 0);

		if (trades_len(buyers) <= 0 || trades_len(sellers) <= 0)
			continue;

		for (i = 0; i < trades_len(buyers); i++)
			scan_trades(buyers[i], sellers);
	}
	next_loc;
}


ilist trades_to_check = NULL;


void
check_validated_trades(void)
{
	int i;

	for (i = 0; i < ilist_len(trades_to_check); i++)
	{
		match_trades(trades_to_check[i]);
	}

	ilist_clear(&trades_to_check);
}


/*
 *  Who has been given some item.  See if this validates
 *  any pending trades.
 *
 *  Our strategy is to see if any pending trades weren't already
 *  active at the old quantity of the item.  If so, we'll attempt
 *  a match soon.
 *
 *  We don't fire the trade inside of add_item, since it's too
 *  dangerous.  We want the command to complete, and be able to
 *  assert that a unit actually has an item after add_item has
 *  been called.
 */

void
investigate_possible_trade(int who, int item, int old_has)
{
	struct trade *t;
	int check = FALSE;

	if (item == item_gold)
	{
		loop_trade(who, t)
		{
			if (t->kind != BUY)
				continue;

			if ((old_has - t->have_left) / t->cost < t->qty)
			{
				check = TRUE;
				break;
			}
		}
		next_trade;
	}
	else
	{
		loop_trade(who, t)
		{
#if 0
			if (t->kind != SELL)
#else
			if (t->kind != SELL || t->item != item)
#endif
				continue;

			if (old_has - t->have_left < t->qty)
			{
				check = TRUE;
				break;
			}
		}
		next_trade;
	}

	if (check)
		ilist_append(&trades_to_check, who);
}


static struct trade *
find_trade(int who, int kind, int item)
{
	struct trade *t;
	struct trade *ret = NULL;

	loop_trade(who, t)
	{
		if (t->kind == kind && t->item == item)
		{
			ret = t;
			break;
		}
	}
	next_trade;

	return ret;
}


static struct trade *
find_trade_city(int *where, int kind, int item)
{
	struct trade *ret;
	int city;

	*where = 0;

	loop_city(city)
	{
		ret = find_trade(city, kind, item);
		if (ret) {
			*where = city;
			break;
		}
	}
	next_city;

	return ret;
}


static struct trade *
new_trade(int who, int kind, int item)
{
	struct trade *ret;

	ret = find_trade(who, kind, item);

	if (ret == NULL)
	{
		ret = my_malloc(sizeof(*ret));

		ret->who = who;
		ret->kind = kind;
		ret->item = item;

		trades_append(&bx[who]->trades, ret);
	}

	return ret;
}


static char *
gold_each(int cost, int qty)
{

	if (qty == 1)
		return gold_s(cost);

	return sout("%s each", gold_s(cost));
}


int
v_buy(struct command *c)
{
	int where = subloc(c->who);
	int item = c->a;
	int qty = c->b;
	int cost = c->c;
	int have_left = c->d;
	int hide_me = c->e;
	struct trade *t;

	if (kind(item) != T_item)
	{
		wout(c->who, "%s is not an item.", box_code(item));
		return FALSE;
	}

	if (item == item_gold)
	{
		wout(c->who, "Can't buy or sell gold.");
		return FALSE;
	}

	if (hide_me)
	{
		if (has_skill(c->who, sk_cloak_trade))
			hide_me = 1;
		else
		{
			wout(c->who, "Must have %s to conceal trades.",
					box_code_less(sk_cloak_trade));
			return FALSE;
		}
	}

	if (qty > 0 && cost < 1)
	{
		wout(c->who, "No price given.");
		return FALSE;
	}

	t = new_trade(c->who, BUY, item);
	assert(t->who == c->who);

	if (qty <= 0)
	{
	    if (t->qty <= 0)
		wout(c->who, "No pending buy for %s.", box_name(item));
	    else
		wout(c->who, "Cleared pending buy for %s.", box_name(item));
	}

	t->qty = qty;
	t->cost = cost;
	t->cloak = hide_me;
	t->have_left = have_left;

	if (qty > 0)
	{
		wout(c->who, "Try to buy %s for %s.",
					box_name_qty(item, qty),
					gold_each(cost, qty));

		if (market_here(c->who))
			scan_trades(t, seller_list(where, c->who));
	}

	return TRUE;
}


int
v_sell(struct command *c)
{
	int where = subloc(c->who);
	int item = c->a;
	int qty = c->b;
	int cost = c->c;
	int have_left = c->d;
	int hide_me = c->e;
	struct trade *t;

	if (kind(item) != T_item)
	{
		wout(c->who, "%s is not an item.", box_code(item));
		return FALSE;
	}

	if (item == item_gold)
	{
		wout(c->who, "Can't buy or sell gold.");
		return FALSE;
	}

	if (hide_me)
	{
		if (has_skill(c->who, sk_cloak_trade))
			hide_me = 1;
		else
		{
			wout(c->who, "Must have %s to conceal trades.",
					box_code_less(sk_cloak_trade));
			return FALSE;
		}
	}

	if (qty > 0 && cost < 1)
	{
		wout(c->who, "No price given.");
		return FALSE;
	}

	t = new_trade(c->who, SELL, item);
	assert(t->who == c->who);

	if (qty <= 0)
	{
	    if (t->qty <= 0)
		wout(c->who, "No pending sell for %s.", box_name(item));
	    else
		wout(c->who, "Cleared pending sell for %s.", box_name(item));
	}

	t->qty = qty;
	t->cost = cost;
	t->cloak = hide_me;
	t->have_left = have_left;

	if (qty > 0)
	{
		wout(c->who, "Try to sell %s for %s.",
					box_name_qty(item, qty),
					gold_each(cost, qty));

		if (market_here(c->who))
			scan_trades(t, buyer_list(where, c->who));
	}

	return TRUE;
}


static int
list_market_items(int who, trades_list l, int first)
{
	int i;
	int qty;

	for (i = 0; i < trades_len(l); i++)
	{
		if (l[i]->cloak >= 2)
			continue;

		qty = reduce_qty(l[i], l[i]->cost);

		if (qty <= 0)
			continue;

		if (first)
		{
			out(who, "");
			out(who, "%5s %*s %7s %6s %9s   %-25s",
				"{<b>}trade", CHAR_FIELD, "who", "price",
				"qty", "wt/ea", "item{</b>}");
			out(who, "%5s %*s %7s %6s %9s   %-25s",
				"-----", CHAR_FIELD, "---", "-----", "---",
				"-----", "----");

			first = FALSE;
		}

		out(who, "%5s %*s %7s %6s %9s   %-25s",
			l[i]->kind == BUY ? "buy" : "sell",
			CHAR_FIELD,
			l[i]->cloak ? "?" : box_code_less(l[i]->who),
			comma_num(l[i]->cost),
			comma_num(qty),
			comma_num(item_weight(l[i]->item)),
			plural_item_box(l[i]->item, qty));
	}

	return first;
}


void
market_report(int who, int where)
{
	trades_list l;
	int first = TRUE;

	out(who, "");
	out(who, "Market report:");
	indent += 3;

	{
		struct trade *t;
		int flag = TRUE;

		loop_trade(where, t)
		{
			if (t->kind == PRODUCE && t->month_prod)
			{
				if (flag)
				{
					out(who, "");
					flag = FALSE;
				}

				wout(who, "%s produces %s on month %d.",
					just_name(where),
					plural_item_name(t->item, 2),
					t->month_prod);
			}
		}
		next_trade;
	}

	l = buyer_list(where, 0);

	if (trades_len(l) > 0)
	{
		first = list_market_items(who, l, first);
	}

	l = seller_list(where, 0);

	if (trades_len(l) > 0)
	{
		first = list_market_items(who, l, first);
	}

	if (first)
		out(who, "No goods offered for trade.");

	indent -= 3;
}


void
list_pending_trades(int who, int num)
{
	int first = TRUE;
	struct trade *t;

	loop_trade(num, t)
	{
		if (t->kind != BUY && t->kind != SELL)
			continue;

		if (first)
		{
			out(who, "");
			out(who, "Pending trades:");
			out(who, "");
			indent += 3;
			first = FALSE;

			out(who, "%5s  %7s  %5s   %s",
					"trade", "price", "qty", "item");
			out(who, "%5s  %7s  %5s   %s",
					"-----", "-----", "---", "----");
		}

		out(who, "%5s  %7s  %5s   %s",
				t->kind == BUY ? "buy" : "sell",
				comma_num(t->cost),
				comma_num(t->qty),
				box_name(t->item));
	}
	next_trade;

	if (!first)
		indent -= 3;
}


struct trade *
add_city_trade(int where, int kind, int item, int qty, int cost, int month)
{
	struct trade *t;

	t = new_trade(where, kind, item);
	t->qty = qty;
	t->cost = cost;
	t->month_prod = month;

	return t;
}


/*
 *  Opium model
 *
 *	Every city has a status indicating its level of opium economic
 *	development, i.e. how addicted is the local populace.
 *	This status is 1-8.  Any sale maintains, saturation causes
 *	rise, no sale decay.
 *
 *	level	profit	qty	price
 *	-----	------	---	-----
 *	  8	 800	 80	 10
 *	  7	 700	 70	 10
 *	  6	 600	 66	  9
 *	  5	 500	 55	  9
 *	  4	 400	 50	  8
 *	  3	 300	 37	  8
 *	  2	 200	 28	  7
 *	  1	 100	 15	  7
 */

struct
{
	int qty;
	int cost;
}
opium_data[] =
{
	{15, 17},
	{28, 17},
	{37, 18},
	{50, 18},
	{55, 19},
	{66, 19},
	{70, 20},
	{80, 20},
};

#define		MAX_OPIUM_ECON		7


static void
opium_market_delta(int where)
{
	struct entity_subloc *p;
	struct trade *t;

	assert(subkind(where) == sub_city);

	t = find_trade(where, BUY, item_opium);
	p = p_subloc(where);

	if (t)
	{
		if (t->qty < 1)			/* sold everything */
		{
			p->opium_econ++;
		}
		else if (t->qty == opium_data[p->opium_econ].qty)
		{
			p->opium_econ--;	/* sold none */
		}
	}

	if (p->opium_econ > MAX_OPIUM_ECON)
		p->opium_econ = MAX_OPIUM_ECON;
	if (p->opium_econ < 0)
		p->opium_econ = 0;

	t = new_trade(where, CONSUME, item_opium);

	t->qty = opium_data[p->opium_econ].qty;
	t->cost = opium_data[p->opium_econ].cost;

	if (p->opium_econ > 0)
		t->cloak = 1;
	else
		t->cloak = 2;
}

void
expire_trades(int where)
{
	int i, j, done;
	struct trade *t;
	struct item_ent *e;

	for (i = 0; i < trades_len(bx[where]->trades); i++)
	{
		t = bx[where]->trades[i];

		if (t->expire > 0)
			t->expire--;

		if (is_tradegood(t->item) && t->expire <= 0) {
			done = TRUE;
			if (t->kind == BUY) {
				/*
				 * Leave the last BUY order if someone is still
				 * carrying some of the trade good
				 */
				loop_char(j)
				{
					loop_inv(j, e)
					{
						if (e->item == t->item)
							done = FALSE;
					}
					next_inv;
				}
				next_char;
			}
			if (done) {
				trades_delete(&bx[where]->trades, i);
				i--;
			}
		}
	}
}


/*
 *  Override causes cities which only produce a good once per year
 *  to produce it now anyway.  This is useful for epoch city trade
 *  seeding.
 */

void
loc_trade_sup(int where, int override)
{
	struct trade *t;
	struct trade *new;

	expire_trades(where);

	loop_trade(where, t)
	{
		int okay = TRUE;
		int next_month;

		if (t->month_prod && !override)
		{
			int this_month = oly_month(sysclock) - 1;
			int next_month = (this_month + 1) % NUM_MONTHS;
			int prod_month = t->month_prod - 1;

			if (next_month != prod_month)
				okay = FALSE;
		}

		if (t->kind == PRODUCE && okay)
		{
			new = new_trade(where, SELL, t->item);

			if (new->qty < t->qty)
				new->qty = t->qty;

			new->cost = t->cost;
			new->cloak = t->cloak;
			new->expire = t->expire;
		}
		else if (t->kind == CONSUME)
		{
			new = new_trade(where, BUY, t->item);
			if (new->qty < t->qty)
				new->qty = t->qty;

			new->cost = t->cost;
			new->cloak = t->cloak;
			new->expire = t->expire;
		}
	}
	next_trade;
}


void
trade_suffuse_ring(int where)
{
	struct trade *t;
	struct trade *new;
	int found = FALSE;
	int item;

	loop_trade(where, t)
	{
		if (subkind(t->item) == sub_suffuse_ring &&
		    t->kind == SELL && t->qty > 0)
			found = TRUE;
	}
	next_trade;

	begin_economy(where);

	if (found || econ_stock(sub_suffuse_ring, where, 1, 3) < 3)
		return;

	item = new_suffuse_ring(where);

	new = new_trade(where, SELL, item);

	new->qty = 1;
	new->cost = 450 + econ_cost(sub_suffuse_ring, where, 0, 12) * 50;
	new->cloak = FALSE;
}


void
location_trades(void)
{
	int where;

	stage("location_trades()");

	loop_city(where)
	{
		opium_market_delta(where);
		loc_trade_sup(where, FALSE);

		if (in_faery(where) || in_clouds(where))
			trade_suffuse_ring(where);
	}
	next_city;
}


static ilist
tradegoods_for_sale(int where)
{
	struct trade *t;
	int sum = 0;
	ilist ret = NULL;

	assert(subkind(where) == sub_city);

	loop_trade(where, t)
	{
		if (t->kind == PRODUCE && subkind(t->item) == sub_tradegood)
			ilist_append(&ret, t->item);
	}
	next_trade;

	return ret;
}


static ilist
tradegoods_bought(int where)
{
	struct trade *t;
	int sum = 0;
	ilist ret = NULL;

	assert(subkind(where) == sub_city);

	loop_trade(where, t)
	{
		if (t->kind == CONSUME && subkind(t->item) == sub_tradegood)
			ilist_append(&ret, t->item);
	}
	next_trade;

	return ret;
}


struct tradegood_ent {
	char *name;		/* name of tradegood */
	char *namep;		/* plural name */
	int weight;
	int base_price;
} tradegoods [] = {
	{"cardamom", "cardamom", 23, 50},
	{"pepper", "pepper", 16, 10},
	{"pipeweed", "pipeweed", 62, 25},
	{"ale", "ale", 50, 25},
	{"fine cloak", "fine cloaks", 80, 75},
	{"chocolate", "chocolate", 72, 50},
	{"ivory", "ivory", 100, 100},
	{"honey", "honey", 100, 25},
	{"ink", "ink", 50, 30},
	{"licorice", "licorice", 50, 25},
	{"soap", "soap", 50, 10},
	{"jade", "jade", 100, 100},
	{"purple cloth", "purple cloth", 100, 100},
	{"rose perfume", "rose perfume", 15, 80},
	{"silk", "silk", 45, 95},
	{"incense", "incense", 30, 20},
	{"ochre", "ochre", 75, 65},
	{"jeweled egg", "jeweled eggs", 30, 100},
	{"obsidian", "obsidian", 100, 90},
	{"orange", "oranges", 100, 10},
	{"cinnabar", "cinnabar", 55, 20},
	{"myrrh", "myrrh", 28, 40},
	{"saffron", "saffron", 27, 15},
	{"sugar", "sugar", 100, 15},
	{"salt", "salt", 100, 10},
	{"linen", "linen", 100, 10},
	{"beans", "beans", 100, 10},
	{"walnuts", "walnuts", 100, 15},
	{"flax", "flax", 100, 10},
	{"cassava", "cassava", 100, 10},
	{"plum wine", "plum wine", 65, 30},
	{"vinegar", "vinegar", 38, 30},
	{"tea", "tea", 43, 25},

	{NULL, NULL, 0}
};

int
is_tradegood(int item)
{
	return (subkind(item) == sub_tradegood);

#if 0
	struct tradegood_ent *t;
	int i;
	char *s = name(item);

	for (i = 0; tradegoods[i].name; i++)
		if (strcmp(s, tradegoods[i].name) == 0)
			return TRUE;

	return FALSE;
#endif
}

int
new_tradegood(int where)
{
	int new;
	struct entity_item *p;
	ilist l;
	int already;
	struct tradegood_ent *t;
	int i;
	int attempt = 0;

	assert(subkind(where) == sub_city);

	begin_economy(where);

	l = tradegoods_for_sale(where);

	do {
		t = &tradegoods[rng_keyed(&economy_rng, where, attempt++,
				ETAG_PICK, 0, sizeof(tradegoods) /
				sizeof(struct tradegood_ent) - 2)];

		/* pick a tradegood with a different name */

		already = 0;
		for (i = 0; i < ilist_len(l); i++)
			if (strcmp(name(l[i]), t->name) == 0)
				already = 1;
	}
	while (already);

	ilist_reclaim(&l);

	new = new_ent(T_item, sub_tradegood);

	bx[new]->name = str_save(t->name);

	p = p_item(new);
	p->plural_name = str_save(t->namep);
	p->weight = (short) t->weight;
	p->base_price = t->base_price;

	return new;
}


int
v_find_sell(struct command *c)
{
	int where = subloc(c->who);

	if (subkind(where) != sub_city)
	{
		wout(c->who, "Must be in a city.");
		return FALSE;
	}

	if (greater_region(where) != 0)
	{
		wout(c->who, "Sorry, trade may only be practiced in the main world.");
		return FALSE;
	}

	return TRUE;
}


int
d_find_sell(struct command *c)
{
	int where = subloc(c->who);
	int item;
	int qty;
	int cost;
	ilist l;
	struct trade *t;

	if (subkind(where) != sub_city)
	{
		wout(c->who, "Must be in a city.");
		return FALSE;
	}

	if (greater_region(where) != 0)
	{
		wout(c->who, "Sorry, trade may only be practiced in the main world.");
		return FALSE;
	}

	l = tradegoods_for_sale(where);

	if (ilist_len(l) >= 2)
	{
		wout(c->who, "At most two tradegoods may be offered "
				"for sale in each city.");
		ilist_reclaim(&l);
		return FALSE;
	}
	ilist_reclaim(&l);

	begin_economy(where);

	item = new_tradegood(where);

	qty = econ_qty(item, where, 25, 50);

	/* cost is 0-50% over base price */

	cost = item_price(item);
	cost = cost + cost * econ_cost(item, where, 0, 5) * 10 / 100;

	t = add_city_trade(where, PRODUCE, item, qty, cost, 0);

	t->expire = econ_expire(item, where, 25, 37);

	wout(c->who, "%s sells %s at %s.",
				box_name(where),
				box_name(item),
				comma_num(cost));

	return TRUE;
}


int
v_find_buy(struct command *c)
{
	int where = subloc(c->who);
	int item = c->a;

	if (subkind(where) != sub_city)
	{
		wout(c->who, "Must be in a city.");
		return FALSE;
	}

	if (greater_region(where) != 0)
	{
		wout(c->who, "Sorry, trade may only be practiced in the main world.");
		return FALSE;
	}

	if (kind(item) != T_item || subkind(item) != sub_tradegood)
	{
		wout(c->who, "%s is not a tradegood.", box_name(item));
		return FALSE;
	}

	if (has_item(c->who, item) < 1)
	{
		wout(c->who, "%s doesn't have any %s.",
				box_name(c->who), box_name(item));
		return FALSE;
	}

	return TRUE;
}


int
d_find_buy(struct command *c)
{
	int where = subloc(c->who);
	int item = c->a;
	int qty, cost, distance;
	ilist l;
	struct trade *t, *tt;
	int city_sold, city_bought;

	if (subkind(where) != sub_city)
	{
		wout(c->who, "Must be in a city.");
		return FALSE;
	}

	if (greater_region(where) != 0)
	{
		wout(c->who, "Sorry, trade may only be practiced in the main world.");
		return FALSE;
	}

	if (kind(item) != T_item || subkind(item) != sub_tradegood)
	{
		wout(c->who, "%s is not a tradegood.", box_name(item));
		return FALSE;
	}

	if (has_item(c->who, item) < 1)
	{
		wout(c->who, "%s doesn't have any %s.",
				box_name(c->who), box_name(item));
		return FALSE;
	}

#if 0
/*
 *  limit purchase to one city only
 */

	t = find_trade_city(&city_bought, CONSUME, item);

	if (t)
	{
		wout(c->who, "%s is already purchased elsewhere.",
				box_code(item));
		return FALSE;
	}
#endif

	l = tradegoods_bought(where);

	if (ilist_len(l) >= 2)
	{
		wout(c->who, "At most two tradegoods may be purchased "
				"in each city.");
		ilist_reclaim(&l);
		return FALSE;
	}
	ilist_reclaim(&l);

	t = find_trade_city(&city_sold, PRODUCE, item);

	if (t == NULL)
	{
		wout(c->who, "No one is interested in purchasing %s here.",
				box_code(item));
		return FALSE;
	}

#if 0
	fprintf(stderr, "(%s is sold in %s for %d)\n",
			box_name(item), box_name(city_sold), t->cost);
#endif

/*
 *  Distance check 
 */

	distance = los_province_distance(where, city_sold);
	if (distance < 0)
	{
		wout(c->who, "Cannot find route to the source of %s!",
				box_name(item));
		return FALSE;
	}
	if (distance < 8)
	{
		wout(c->who, "Must find a city further away from the source of %s.",
				box_name(item));
		return FALSE;
	}

/*
 *  50% check
 *
 *  For a given tradegood, half of the cities which are a suitable
 *  distance away should be interested in purchasing it.
 *  To determine which ones are and which aren't, we
 *  MD5 the selling city, the target city, the item, and a secret
 *  number (for security).  If the resulting lowest bit is zero,
 *  then the target city will purchase the tradegood.
 */

	if (md5_int(city_sold, where, item, (int) trade_route_secret) & 1)
	{
		wout(c->who, "No buyer for %s can be found here.",
				box_code(item));
		return FALSE;
	}

	qty = t->qty;

/*
 *  2000-3000 gold profit
 */

	begin_economy(where);

	cost = t->cost + econ_cost(item, where, 200, 300)*10/t->qty;

	tt = add_city_trade(where, CONSUME, item, qty, cost, 0);

	tt->expire = t->expire;

	wout(c->who, "%s buys %s at %s.",
				box_name(where),
				box_name(item),
				comma_num(cost));

	return TRUE;
}

