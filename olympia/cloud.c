
#include	<stdio.h>
#include 	<string.h>
#include	"z.h"
#include	"oly.h"
#include	"rng.h"


int cloud_region = 0;


#define	SZ	4


/*
 *  issue #25 (regions, step 12): the Cloudlands world build draws from a fresh
 *  per-build SEQUENTIAL stream (tag "clud") instead of the global rnd(). Like
 *  tunnel.c's dungeon generation (the worldgen precedent), the build is an
 *  ordered terrain/gate generation (the corner-gate seal keys and the ring-of-
 *  stones shuffle), so it is the combat/quest sequential model, not keyed leaves.
 *  cloud.c is build-only -- it has no autonomous turn-time behavior -- so unlike
 *  faery/hades it carries just the one stream. It fires at the -i/-s/-a world
 *  init (io.c, init-guarded if (cloud_region == 0)), so it is NOT byte-neutral.
 */
static rng_stream cloud_seq;

#define	TAG_TURN	0x7475726eu	/* "turn" */
#define	TAG_CLOUD	0x636c7564u	/* "clud" */

/* Fresh per-build reseed (the tunnel.c/worldgen sequential model). */
static void
begin_cloud_build(int where)
{
	uint32_t m[4];
	rng_stream root, turn;

	rng_master_seed(m);
	root = rng_seed(m);
	turn = rng_stream_of(&root, sysclock.turn, TAG_TURN);
	cloud_seq = rng_stream_of(&turn, where, TAG_CLOUD);
}

static int
cseq_rnd(int low, int high)
{
	return rng_draw(&cloud_seq, low, high);
}

static void
cseq_shuffle(ilist l)
{
	ilist_shuffle_rng(l, &cloud_seq);
}


/*
 *  New Cloudlands for G2
 *
 *
 *	 12345
 *      +-----
 *     1|  c
 *     2|  b
 *     3|  a
 *     4|  d
 *     5|  e
 *
 *
 *
 *
 *        fghij
 *         |  |
 *      6789 abcd
 *        |  |  |
 *        42135 e
 *          |
 *
 *
 *  Configuration:
 *
 *	123456*8
 *
 *
 *	  8
 *	  7
 *   	12*34
 *	  5dc
 *	  6ab
 *
 *	* = contains Cloud City
 *	Cloud City has gate to ring of stones somewhere
 *	Cloud City has sealed gate to ring of stones
 *	other locs all have incoming gates from random locs elsewhere
 */


/*
 *	%%%%
 *	%*%%	*=Nimbus
 *	%^%*	*=Aerovia	^=Mt. Olympus link
 *	*%%%	*=Stratos
 */
	

void
create_cloudlands(void)
{
	int r, c, clear, base;
	int map[SZ+1][SZ+1];
	int n;
	int i;
	int north, east, south, west;
	struct entity_loc *p;

/*
 *  Create region wrapper
 */

	cloud_region = new_ent(T_loc, sub_region);
	set_name(cloud_region, "Cloudlands");

	fprintf(stderr, "INIT: creating %s\n", box_name(cloud_region));

	begin_cloud_build(cloud_region);	/* issue #25: per-build clud stream */

/*
 *  Fill map[row,col] with locations.
 */

	clear = 0;
	for (base = 0; base < 400 - SZ; base += 20)
	{
		n = 10000 + base * 100;
		if (bx[n] == NULL)
		{
			clear = 1;
			for (r = 0; clear && r <= SZ; r++)
				for (c = 0; clear && c <= SZ; c++)
				{
					n = 10000 + (base + r) * 100 + c;
					if (bx[n] != NULL)
						clear = 0;
				}
			break;
		}
	}
	for (r = 0; r <= SZ; r++)
	{
		for (c = 0; c <= SZ; c++)
		{
			if (clear)
			{
				n = 10000 + (base + r) * 100 + c;
				alloc_box(n, T_loc, sub_cloud);
			}
			else
			{
				n = new_ent(T_loc, sub_cloud);
			}
			map[r][c] = n;
			set_name(n, "Cloud");
			set_where(n, cloud_region);
		}
	}

/*
 *  Set the NSEW exit routes for every map location
 */

	for (r = 0; r <= SZ; r++)
	{
		for (c = 0; c <= SZ; c++)
		{
			p = p_loc(map[r][c]);

			if (r == 0)
				north = 0;
			else
				north = map[r-1][c];

			if (r == SZ)
				south = 0;
			else
				south = map[r+1][c];

			if (c == SZ)
				east = 0;
			else
				east = map[r][c+1];

			if (c == 0)
				west = 0;
			else
				west = map[r][c-1];

			ilist_append(&p->prov_dest, north);
			ilist_append(&p->prov_dest, east);
			ilist_append(&p->prov_dest, south);
			ilist_append(&p->prov_dest, west);
		}
	}

	{
		int nimbus, aerovia, stratos;

		nimbus = new_ent(T_loc, sub_city);
		set_where(nimbus, map[1][1]);
		set_name(nimbus, "Nimbus");
		seed_city(nimbus);

		aerovia = new_ent(T_loc, sub_city);
		set_where(aerovia, map[2][3]);
		set_name(aerovia, "Aerovia");
		seed_city(aerovia);

		stratos = new_ent(T_loc, sub_city);
		set_where(stratos, map[3][0]);
		set_name(stratos, "Stratos");
		seed_city(stratos);
	}

/*
 *  Create gates to rings of stones at the four corners of the Cloudlands
 */

	{
		ilist l = NULL;
		int i;
		int gate1, gate2, gate3, gate4;

		loop_loc(i)
		{
			if (subkind(i) == sub_stone_cir)
				ilist_append(&l, i);
		}
		next_loc;

		assert(ilist_len(l) >= 4);
		cseq_shuffle(l);

		gate1 = new_ent(T_gate, 0);
		set_where(gate1, map[0][0]);
		p_gate(gate1)->to_loc = l[0];
		rp_gate(gate1)->seal_key = (short) cseq_rnd(111,999);

		gate2 = new_ent(T_gate, 0);
		set_where(gate2, map[SZ][0]);
		p_gate(gate2)->to_loc = l[1];
		rp_gate(gate2)->seal_key = (short) cseq_rnd(111,999);

		gate3 = new_ent(T_gate, 0);
		set_where(gate3, map[0][SZ]);
		p_gate(gate3)->to_loc = l[2];
		rp_gate(gate3)->seal_key = (short) cseq_rnd(111,999);

		gate4 = new_ent(T_gate, 0);
		set_where(gate4, map[SZ][SZ]);
		p_gate(gate4)->to_loc = l[3];
		rp_gate(gate4)->seal_key = (short) cseq_rnd(111,999);

		ilist_reclaim(&l);
	}

	printf("Aerovia is in %s\n", box_name(map[2][3]));

/*
 *  Link a cloud to a Mt. Olympus below
 */

	{
		int i;
		struct entity_loc *p;

		loop_mountain(i)
		{
			if (strcmp(name(i), "Mt. Olympus") == 0)
			{
				mount_olympus = i;
				break;
			}
		}
		next_mountain;

		if (mount_olympus == 0)
		{
			fprintf(stderr,
				"ERROR: Can't find mountain 'Mt. Olympus'\n");
			return;
		}

		p = p_loc(map[2][1]);
		while (ilist_len(p->prov_dest) < DIR_DOWN)
			ilist_append(&p->prov_dest, 0);
		p->prov_dest[DIR_DOWN-1] = mount_olympus;

		p = p_loc(mount_olympus);
		while (ilist_len(p->prov_dest) < DIR_UP)
			ilist_append(&p->prov_dest, 0);
		p->prov_dest[DIR_UP-1] = map[2][1];
	}
}

