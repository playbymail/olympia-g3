
#include	<stdio.h>
#include	<math.h>
#include	"z.h"
#include	"oly.h"
#include	"rng.h"


int faery_region = 0;
int faery_player = 0;


#define	SZ	100		/* SZ x SZ is the maximum size of faery */


/*
 *  issue #25 (regions, step 12): Faery draws from a per-turn "faer" stream
 *  instead of the global rnd(). Like hades/worldgen it is a hybrid -- one tag,
 *  two draw models (the weather/worldgen precedent):
 *
 *  - The WORLD BUILD (create_faery) is ordered terrain/gate/hill/city generation,
 *    so it uses a fresh per-build SEQUENTIAL stream (the tunnel.c model):
 *    begin_faery_build() reseeds it and fseq_rnd()/fseq_shuffle() draw in order.
 *    It fires at the -i/-s/-a world init (io.c, init-guarded if (faery_region ==
 *    0)), so the build half is NOT byte-neutral.
 *
 *  - The AUTONOMOUS turn-time behavior (auto_faery's create_elven_hunt spawns and
 *    the npc.c bandit ambushes) uses KEYED LEAVES on a turn-guarded per-turn
 *    stream (the explore/magic model): begin_faery() seeds once per turn and the
 *    faer_*() helpers are order-independent leaf draws. The build stream keys on
 *    the (nonzero) region id and the leaf stream keys on 0, so they never collide
 *    (the worldgen convention). The bandit helpers are exposed via proto.h.
 */
static rng_stream faery_seq;			/* build: ordered generation        */
static rng_stream faery_rng;			/* autonomous: keyed leaves         */
static int faery_rng_turn = -1;			/* seed faery_rng once per turn     */

#define	TAG_TURN	0x7475726eu	/* "turn" */
#define	TAG_FAERY	0x66616572u	/* "faer" */

/* faery autonomous leaf-draw purpose tags (kept private) */
#define	FTAG_HUNT	0x68756e74u	/* "hunt" -- create_elven_hunt where pick (retry-keyed) */
#define	FTAG_HQTY	0x68717479u	/* "hqty" -- create_elven_hunt elf count               */
#define	FTAG_BKND	0x626b6e64u	/* "bknd" -- create_faery_bandit kind                  */
#define	FTAG_BQTY	0x62717479u	/* "bqty" -- create_faery_bandit troop count           */
#define	FTAG_BGLD	0x62676c64u	/* "bgld" -- create_faery_bandit gold                  */
#define	FTAG_AMBS	0x616d6273u	/* "ambs" -- faery_attack_check ambush trigger         */
#define	FTAG_RTAL	0x7274616cu	/* "rtal" -- faery_attack_check retaliate              */

/* build: fresh per-build reseed (the tunnel.c/worldgen sequential model). */
static void
begin_faery_build(int where)
{
	uint32_t m[4];
	rng_stream root, turn;

	rng_master_seed(m);
	root = rng_seed(m);
	turn = rng_stream_of(&root, sysclock.turn, TAG_TURN);
	faery_seq = rng_stream_of(&turn, where, TAG_FAERY);
}

static int
fseq_rnd(int low, int high)
{
	return rng_draw(&faery_seq, low, high);
}

static void
fseq_shuffle(ilist l)
{
	ilist_shuffle_rng(l, &faery_seq);
}

/* autonomous: turn-guarded per-turn keyed-leaf stream (the explore/magic model). */
static void
begin_faery(void)
{
	uint32_t m[4];
	rng_stream root, turn;

	if (faery_rng_turn == sysclock.turn)
		return;			/* already seeded this turn */

	rng_master_seed(m);
	root = rng_seed(m);
	turn = rng_stream_of(&root, sysclock.turn, TAG_TURN);
	faery_rng = rng_stream_of(&turn, 0, TAG_FAERY);

	faery_rng_turn = sysclock.turn;
}

/* create_elven_hunt where pick: keyed on (auto_faery slot, retry). The legacy
 * pick sits in a do/while that re-rolls until the loc is non-ocean, so a fixed
 * leaf key would spin forever -- the retry index makes each re-roll distinct. */
static int
faer_hunt_loc(int slot, int retry, int low, int high)
{
	begin_faery();
	return rng_keyed(&faery_rng, slot, retry, FTAG_HUNT, low, high);
}

static int
faer_hunt_qty(int slot)
{
	begin_faery();
	return rng_keyed(&faery_rng, slot, 0, FTAG_HQTY, 25, 100);
}

/* exposed via proto.h for the npc.c bandit ambushes (region-environmental). */
int
faer_bandit_kind(int who, int where)
{
	begin_faery();
	return rng_keyed(&faery_rng, who, where, FTAG_BKND, 1, 3);
}

int
faer_bandit_qty(int unit)
{
	begin_faery();
	return rng_keyed(&faery_rng, unit, 0, FTAG_BQTY, 4, 24);
}

int
faer_bandit_gold(int unit)
{
	begin_faery();
	return rng_keyed(&faery_rng, unit, 0, FTAG_BGLD, 1, 25);
}

int
faer_ambush(int who, int where)
{
	begin_faery();
	return rng_keyed(&faery_rng, who, where, FTAG_AMBS, 1, 100);
}

int
faer_retal(int who, int where)
{
	begin_faery();
	return rng_keyed(&faery_rng, who, where, FTAG_RTAL, 1, 2);
}


void
create_faery(void)
{
	int r, c, hills, total, sz, space, base, clear;
	int map[SZ][SZ];
	int n;
	int i;
	int north, east, south, west;
	struct entity_loc *p;
	struct loc_info *li;
	int sk, new;
	char *pw;


/*
 *  Create region wrapper for Faery
 */

	faery_region = new_ent(T_loc, sub_region);
	set_name(faery_region, "Faery");

	fprintf(stderr, "INIT: creating %s\n", box_name(faery_region));

	begin_faery_build(faery_region);	/* issue #25: per-build faer stream */

/*
 * Size Faery dynamically to fit the number of faery hills we want
 */

	total = 0;
	loop_loc(i)
	{
		if (loc_depth(i) != LOC_region || i == faery_region)
			continue;

		li = rp_loc_info(i);

		if (li == NULL || ilist_len(li->here_list) < 1)
			continue;

		hills = ilist_len(li->here_list) / 50;
		if (hills < 1)
			hills = 1;

		total += hills;
	}
	next_loc;

	sz = (int) ceil(sqrt(total * 16)) + 2;
	if (sz > SZ)
		sz = SZ;
	
	fprintf(stderr, "Faery is %dx%d (max %d hills)\n", sz, sz, total);

/*
 *  Fill map[row,col] with locations.
 *  Capped on all edges with ocean
 */

	// see if there's a contiguous block of provinces so that Faery
	// map coords can follow the same pattern as the surface
	clear = 0;
	for (base = 0; base < 400 - sz; base += 20)
	{
		n = 10000 + base * 100;
		if (bx[n] == NULL)
		{
			clear = 1;
			for (r = 0; clear && r < sz; r++)
				for (c = 0; clear && c < sz; c++)
				{
					n = 10000 + (base + r) * 100 + c;
					if (bx[n] != NULL)
						clear = 0;
				}
			break;
		}
	}
	for (r = 0; r < sz; r++)
		for (c = 0; c < sz; c++)
		{
			if (c == 0 || c == sz - 1 || r == 0 || r == sz - 1)
				sk = sub_ocean;
			else
				sk = sub_forest;
			if (clear)
			{
				n = 10000 + (base + r) * 100 + c;
				alloc_box(n, T_loc, sk);
			}
			else
			{
				n = new_ent(T_loc, sk);
			}

			map[r][c] = n;
			set_where(n, faery_region);
		}

/*
 *  Set the NSEW exit routes for every map location
 */

	for (r = 0; r < sz; r++)
		for (c = 0; c < sz; c++)
		{
			p = p_loc(map[r][c]);

			if (r == 0)
				north = 0;
			else
				north = map[r-1][c];

			if (r < sz - 1)
				south = map[r+1][c];
			else
				south = 0;

			if (c < sz - 1)
				east = map[r][c+1];
			else
				east = 0;

			if (c == 0)
				west = 0;
			else
				west = map[r][c-1];

			ilist_append(&p->prov_dest, north);
			ilist_append(&p->prov_dest, east);
			ilist_append(&p->prov_dest, south);
			ilist_append(&p->prov_dest, west);
		}

	clear_temps(T_loc);
	space = sz * sz;

/*
 *  Make a ring of stones
 *  Randomly place it in Faery
 *  link with a gate to a Ring of Stones in the outside world
 */

	{
		int gate;
		int ring;
		struct loc_info *li;
		int randloc;
		ilist l = NULL;
		int i;
		int other_ring;

		loop_loc(i)
		{
			if (subkind(i) == sub_stone_cir)
				ilist_append(&l, i);
		}
		next_loc;

		assert(ilist_len(l) > 0);
		fseq_shuffle(l);
		other_ring = l[0];

		li = rp_loc_info(faery_region);
		assert(li && ilist_len(li->here_list) > 0);

		randloc = li->here_list[fseq_rnd(0, ilist_len(li->here_list)-1)];

		ring = new_ent(T_loc, sub_stone_cir);
		set_where(ring, randloc);
		bx[randloc]->temp = 1;
		space--;

		gate = new_ent(T_gate, 0);
		set_where(gate, ring);

		p_gate(gate)->to_loc = other_ring;
		rp_gate(gate)->seal_key = (short) fseq_rnd(111,999);

		ilist_reclaim(&l);
	}


/*
 *  Make a faery hill for every region on the map (except Faery itself).
 *  Place them randomly within Faery.
 *  Link them with the special road to a random location within the region.
 */

	loop_loc(i)
	{
		struct loc_info *li;
		int randloc;
		struct entity_subloc *sl;

		if (loc_depth(i) != LOC_region || i == faery_region)
			continue;

		li = rp_loc_info(i);

		if (li == NULL || ilist_len(li->here_list) < 1)
		{
			fprintf(stderr, "warning: loc info for %s is NULL\n",
					box_name(i));
			continue;
		}

		if (subkind(li->here_list[0]) == sub_ocean)
			continue;

		hills = ilist_len(li->here_list) / 50;
		if (hills < 1)
			hills = 1;

		while (space > 0 && hills > 0)
		{
			hills--;
			/* 50% chance of a hill for each 50 provinces
			 * in a region, but at least one
			 */
			if (hills && fseq_rnd(0,1))
				continue;
			do
			{
				randloc = li->here_list[fseq_rnd(0, ilist_len(li->here_list)-1)];
				r = fseq_rnd(1, sz - 2);
				c = fseq_rnd(1, sz - 2);
			}
			while (bx[randloc]->temp || bx[map[r][c]]->temp);

			n = new_ent(T_loc, sub_faery_hill);
			set_where(n, map[r][c]);

			sl = p_subloc(n);
			ilist_append(&sl->link_to, randloc);
			sl->link_when = (schar) fseq_rnd(0, NUM_MONTHS-1);

			sl = p_subloc(randloc);
			ilist_append(&sl->link_from, n);

			bx[map[r][c]]->temp = 1;
			bx[randloc]->temp = 1;
			space--;
		}
	}
	next_loc;

/*
 *  Create some Faery cities.  Faery cities have markets which sell
 *  rare items.
 */

	new = 0;
	for (r = 2; space > 0 && r < sz - 2; r++)
		for (c = 2; space > 0 && c < sz - 2; c++)
		{
			if (bx[map[r][c]]->temp)
				continue;
			if (fseq_rnd(0, 30))
				continue;
			new = new_ent(T_loc, sub_city);
			set_where(new, map[r][c]);
			set_name(new, "Faery city");
			seed_city(new);
			bx[map[r][c]]->temp = 1;
			space--;
		}
	
	while (!new && space > 0)
	{
		r = fseq_rnd(2, sz - 3);
		c = fseq_rnd(2, sz - 3);
		if (bx[map[r][c]]->temp)
			continue;
		new = new_ent(T_loc, sub_city);
		set_where(new, map[r][c]);
		set_name(new, "Faery city");
		seed_city(new);
		bx[map[r][c]]->temp = 1;
		space--;
	}

/*
 *  Create the Faery player
 */

	assert(faery_player == 0);

	faery_player = 204;
	alloc_box(faery_player, T_player, sub_pl_npc);
	set_name(faery_player, "Faery player");

	/* To override the default password below, create/edit the file "PWD" which contains:

fairy fairypassword
combat combatpassword

	   The string up to the first whitespace contains the keyword used to look up the password below
	   The string after the whitespace contains the password to use instead of the default one
	 */

	pw = read_pw("faery");
	if (pw == NULL)
		pw = "noyoudont";
	p_player(faery_player)->password = pw;

	printf("faery loc is %s\n", box_name(map[1][1]));
}


void
link_opener(int who, int where, int sk)
{
	struct entity_subloc *p, *pp;
	int i;
	int set_something = FALSE;

	p = rp_subloc(where);

	if (p == NULL)
	{
		wout(who, "Nothing happens.");
		return;
	}

	if (subkind(where) == sk && ilist_len(p->link_to) > 0)
	{
		if (p->link_open < 2 && p->link_open >= 0)
			p->link_open = 2;

		for (i = 0; i < ilist_len(p->link_to); i++)
			out(who, "A gateway to %s is here.",
					box_name(p->link_to[i]));

		set_something = TRUE;
	}

	for (i = 0; i < ilist_len(p->link_from); i++)
	{
		if (subkind(p->link_from[i]) != sk)
			continue;

		pp = rp_subloc(p->link_from[i]);
		assert(pp);

		if (pp->link_open < 2)
			pp->link_open = 2;

		out(who, "A gateway to %s is here.",
					box_name(p->link_from[i]));

		set_something = TRUE;
	}

	if (!set_something)
		wout(who, "Nothing happens.");
}


int
v_use_faery_stone(struct command *c)
{

	link_opener(c->who, subloc(c->who), sub_faery_hill);
	return TRUE;
}


static void
create_elven_hunt(int slot)
{
	int new;
	struct loc_info *p;
	int where;
	int retry = 0;

	p = rp_loc_info(faery_region);
	assert(p);

	do
	{
		where = p->here_list[faer_hunt_loc(slot, retry++, 0,
						ilist_len(p->here_list)-1)];
	}
	while (subkind(where) == sub_ocean);

	new = new_char(sub_ni, item_elf, where, 100, faery_player,
						LOY_npc, 0, "Faery Hunt");

	if (new < 0)
		return;

	gen_item(new, item_elf, faer_hunt_qty(slot));

	queue(new, "wait time 0");
	init_load_sup(new);   /* make ready to execute commands immediately */
}


static void
warn_human(int who, int targ)
{

	queue(who, "message 1 %s", box_code_less(targ));
	queue(who, "You are not welcome in Faery.  Leave, "
				"or you will be killed.");
	log_write(LOG_SPECIAL, "Faery hunt warned %s.", box_name(targ));
}


static void
auto_faery_sup(int who)
{
	int i;
	int where = subloc(who);
	struct entity_misc *p;
	int queued_something = FALSE;

	p = p_misc(player(who));

	loop_here(where, i)
	{
		if (kind(i) != T_char || subkind(player(i)) != sub_pl_regular)
			continue;

		if (stack_has_use_key(i, use_faery_stone))
			continue;

		queued_something = TRUE;

		if (!test_bit(p->npc_memory, i))
		{
			warn_human(who, i);
			set_bit(&p->npc_memory, i);
			continue;
		}

		queue(who, "attack %s", box_code_less(i));
	}
	next_here;

	if (!queued_something)
		npc_move(who);
}


void
auto_faery(void)
{
	int i;
	int n_faery = 0;

	loop_units(faery_player, i)
	{
		n_faery++;
	}
	next_unit;

	while (n_faery < 15)
	{
		create_elven_hunt(n_faery);
		n_faery++;
	}

	loop_units(faery_player, i)
	{
		auto_faery_sup(i);
	}
	next_unit;
}



