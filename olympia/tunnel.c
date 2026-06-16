
#include	<stdio.h>
#include	"z.h"
#include	"oly.h"
#include	"rng.h"


int tunnel_region = 0;
int under_region = 0;


/*
 *  issue #25 (worldgen, step 11): dungeon/subworld generation draws from a
 *  per-location SEQUENTIAL worldgen stream (tag "wgen") instead of the global
 *  rnd(). Unlike seed.c's keyed-leaf half of worldgen, a dungeon is an ordered
 *  recursive build (hundreds of draws where each shapes the next), so it cannot
 *  be expressed as keyed leaves -- it is the combat/quest model: begin_worldgen_loc()
 *  reseeds a fresh stream per location and wseq_rnd()/wseq_shuffle() draw from it
 *  in order. This is the largest draw set in the engine (~409,727 rnd()/build),
 *  so it fires only at world-init -- one subsystem, two draw models (the weather
 *  precedent). Each location is built exactly once, so the fresh per-location
 *  reseed never correlates across builds. The per-city build gate (create_tunnels)
 *  is a keyed leaf on seed.c's per-turn worldgen stream (wgen_gate), kept separate
 *  because create_tunnel_set re-seeds the same (turn, city) stream at entry.
 */
static rng_stream worldgen_seq;

#define	TAG_TURN	0x7475726eu	/* "turn" */
#define	TAG_WORLDGEN	0x7767656eu	/* "wgen" */

/* Fresh per-location reseed (the combat/quest begin_battle model). */
static void
begin_worldgen_loc(int where)
{
	uint32_t m[4];
	rng_stream root, turn;

	rng_master_seed(m);
	root = rng_seed(m);
	turn = rng_stream_of(&root, sysclock.turn, TAG_TURN);
	worldgen_seq = rng_stream_of(&turn, where, TAG_WORLDGEN);
}

static int
wseq_rnd(int low, int high)
{
	return rng_draw(&worldgen_seq, low, high);
}

static void
wseq_shuffle(ilist l)
{
	ilist_shuffle_rng(l, &worldgen_seq);
}


#define	SUB_SZ	10		/* SZ x SZ is size of Subworld */

static void
create_subworld(void)
{
	int r, c, clear, base;
	int map[SUB_SZ+1][SUB_SZ+1];
	int n;
	int north, east, south, west;
	struct entity_loc *p;

/*
 *  Create region wrapper
 */

	under_region = new_ent(T_loc, sub_region);
	set_name(under_region, "Subworld");

	begin_worldgen_loc(under_region);	/* issue #25: per-location wgen stream */

	fprintf(stderr, "INIT: creating %s\n", box_name(under_region));

/*
 *  Fill map[row,col] with locations.
 */

	clear = 0;
	for (base = 0; base < 400 - SUB_SZ - 1; base += 20)
	{
		n = 10000 + base * 100;
		if (bx[n] == NULL)
		{
			clear = 1;
			for (r = 0; clear && r <= SUB_SZ; r++)
				for (c = 0; clear && c <= SUB_SZ; c++)
				{
					n = 10000 + (base + r) * 100 + c;
					if (bx[n] != NULL)
						clear = 0;
				}
			break;
		}
	}
	for (r = 0; r <= SUB_SZ; r++)
		for (c = 0; c <= SUB_SZ; c++)
		{
			if (clear)
			{
				n = 10000 + (base + r) * 100 + c;
				alloc_box(n, T_loc, sub_forest);
			}
			else
			{
				n = new_ent(T_loc, sub_forest);
			}
			set_name(n, "Subworld");

			map[r][c] = n;
			set_where(n, under_region);

			if (wseq_rnd(1,3) == 1)
			{
				int new;

				new = new_ent(T_loc, sub_cave);
				set_where(new, map[r][c]);
				p_loc(new)->hidden = TRUE;
			}

			if (wseq_rnd(1,3) == 1)
			{
				int new;

				new = new_ent(T_loc, sub_rocky_hill);
				set_where(new, map[r][c]);
			}
		}

/*
 *  Set the NSEW exit routes for every map location
 */

	for (r = 0; r <= SUB_SZ; r++)
	{
		for (c = 0; c <= SUB_SZ; c++)
		{
			p = p_loc(map[r][c]);

			if (r == 0)
				north = 0;
			else
				north = map[r-1][c];

			if (r == SUB_SZ)
				south = 0;
			else
				south = map[r+1][c];

			if (c == SUB_SZ)
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
}



int
random_subworld_loc(void)
{
	ilist l = NULL;
	int i, s, has_city;
	int ret;

	loop_loc(i)
	{
		if (region(i) != under_region)
			continue;
		if (subkind(i) != sub_forest)
			continue;

		has_city = 0;
		loop_here(i, s)
		{
			if (kind(s) == T_loc && subkind(s) == sub_city)
				has_city = 1;
		}
		next_here;
		
		if (has_city)
			continue;

		ilist_append(&l, i);
	}
	next_loc;

	assert(ilist_len(l) > 0);

	ret = l[wseq_rnd(0,ilist_len(l)-1)];

	ilist_reclaim(&l);
	return ret;
}


#define		SZ		7	/* 5 x 5 */
#define		MAX_LEVELS	25

/*
 *  print_map is a dead debug helper whose signature uses the file-private
 *  SZ/MAX_LEVELS macros, so it cannot live in proto.h.  Declare it locally
 *  (kept non-static to avoid an unused-function warning) to satisfy
 *  -Wmissing-prototypes at its definition below.
 */
void print_map(int map[SZ+2][SZ+2][MAX_LEVELS], int l);


static int tun_total_locs;


void
print_map(int map[SZ+2][SZ+2][MAX_LEVELS], int l)
{
	int r, c;

	printf("level %d", l);

	for (r = 0; r < SZ+2; r++) {
		for (c = 0; c < SZ+2; c++) {
			if (map[r][c][l])
				printf("X");
			else
				printf("-");
		}
		printf("\n");
	}
	printf("\n");
}


void
fill_dir_exits(int where)
{
	struct entity_loc *p;

	p = p_loc(where);

	while (ilist_len(p->prov_dest) < 6)
		ilist_append(&p->prov_dest, 0);
}

static int
new_tunnel(void)
{
	int n;

	n = new_ent(T_loc, sub_tunnel);
	set_where(n, tunnel_region);
	tun_total_locs++;

	fill_dir_exits(n);

	return n;
}


static void
tun_links(int map[SZ+2][SZ+2][MAX_LEVELS], int r, int c, int l)
{

	if (map[r+1][c][l])
	{
		p_loc(map[r][c][l])->prov_dest[DIR_S-1] = map[r+1][c][l];
		p_loc(map[r+1][c][l])->prov_dest[DIR_N-1] = map[r][c][l];
	}

	if (map[r-1][c][l])
	{
		p_loc(map[r][c][l])->prov_dest[DIR_N-1] = map[r-1][c][l];
		p_loc(map[r-1][c][l])->prov_dest[DIR_S-1] = map[r][c][l];
	}

	if (map[r][c+1][l])
	{
		p_loc(map[r][c][l])->prov_dest[DIR_E-1] = map[r][c+1][l];
		p_loc(map[r][c+1][l])->prov_dest[DIR_W-1] = map[r][c][l];
	}

	if (map[r][c-1][l])
	{
		p_loc(map[r][c][l])->prov_dest[DIR_W-1] = map[r][c-1][l];
		p_loc(map[r][c-1][l])->prov_dest[DIR_E-1] = map[r][c][l];
	}
}


static int
filled_locs(int map[SZ+2][SZ+2][MAX_LEVELS], int l, int dir)
{
	int r, c;
	ilist sq = NULL;
	int square;

	for (r = 1; r <= SZ; r++)
		for (c = 1; c <= SZ; c++)
			if (map[r][c][l])
			{
				struct entity_loc *p;

				p = p_loc(map[r][c][l]);

				assert(ilist_len(p->prov_dest) >= 6);

				if (dir == 0 || p->prov_dest[dir-1] == 0)
					ilist_append(&sq, map[r][c][l]);
			}

	assert(ilist_len(sq) > 0);

	wseq_shuffle(sq);
	square = sq[0];

	ilist_reclaim(&sq);

	return square;
}


static int
fill_out_level(int map[SZ+2][SZ+2][MAX_LEVELS], int l)
{
	int r, c;
	int n;
	int sum;

	r = wseq_rnd(1, SZ);
	c = wseq_rnd(1, SZ);

	sum = 0;
	if (map[r+1][c][l])
		sum++;
	if (map[r-1][c][l])
		sum++;
	if (map[r][c+1][l])
		sum++;
	if (map[r][c-1][l])
		sum++;

	if (map[r][c][l] == 0 && sum == 1)
	{
		n = new_tunnel();
		map[r][c][l] = n;

		tun_links(map, r, c, l);

		return 1;
	}

	return 0;
}


static int
add_chamber(int map[SZ+2][SZ+2][MAX_LEVELS], int l)
{
	int dir = wseq_rnd(1,4);
	int new;
	int square;

	square = filled_locs(map, l, dir);

	new = new_ent(T_loc, sub_chamber);
	p_loc(new)->hidden = TRUE;
	p_subloc(new)->tunnel_level = (schar) l; 
	set_where(new, tunnel_region);
	tun_total_locs++;

	fill_dir_exits(new);

	p_loc(square)->prov_dest[dir-1] = new;
	p_loc(new)->prov_dest[exit_opposite[dir]-1] = square;

	fprintf(stderr, "tunnel chamber accessible from %s\n", box_code_less(square));

	return 0;
}


static int subworld_city;

int
create_tunnel_set(int city, int subworld_link)
{
	int map[SZ+2][SZ+2][MAX_LEVELS];
	int r, c, l;
	int n;
	int sewer;
	int level_size;
	int count;
	int nlevels;
	int ret = 0;
	int clev1, clev2, clev3;
	int square;
	char name_buffer[100];

	begin_worldgen_loc(city);	/* issue #25: per-location wgen stream */

	tun_total_locs = 0;

/*
 *  Start with clear map 
 */
	for (r = 0; r < SZ+2; r++)
		for (c = 0; c < SZ+2; c++)
			for (l = 0; l < MAX_LEVELS; l++)
				map[r][c][l] = 0;

/*
 *  Create first loc
 */

	l = 1;

	r = wseq_rnd(1, SZ);
	c = wseq_rnd(1, SZ);
	n = new_tunnel();
	map[r][c][l] = n;

/*
 *  Link this loc to a hidden sewer in the city
 */

	sewer = new_ent(T_loc, sub_sewer);
	p_loc(sewer)->hidden = TRUE;
	set_where(sewer, city);

	fill_dir_exits(sewer);

	p_loc(sewer)->prov_dest[DIR_DOWN-1] = n;
	p_loc(n)->prov_dest[DIR_UP-1] = sewer;

	level_size = wseq_rnd(3, 12);

	count = 0;
	while (level_size > 0 && count++ < 500)
		level_size -= fill_out_level(map, 0);

/*
 *  Drop a down from a random loc to the next level
 */

	if (safe_haven(city) || subworld_link)
		nlevels = 11;
	else
	{
		nlevels = wseq_rnd(2,5);
		// Make 50% of non-safe-haven sewers extra deep
		if (wseq_rnd(0, 1))
			nlevels += wseq_rnd(1,6);
	}

	clev1 = wseq_rnd(1,6);
	do {
		clev2 = wseq_rnd(1,6);
	} while (clev1 == clev2);
	clev3 = wseq_rnd(7, 10);

	do {
		do {
			r = wseq_rnd(1,SZ);
			c = wseq_rnd(1,SZ);
		}
		while (map[r][c][l] == 0);

		l++;

		n = new_tunnel();
		p_loc(n)->hidden = TRUE;
		map[r][c][l] = n;

		p_loc(map[r][c][l])->prov_dest[DIR_UP-1] = map[r][c][l-1];
		p_loc(map[r][c][l-1])->prov_dest[DIR_DOWN-1] = map[r][c][l];

		if (l > 5)
			level_size = wseq_rnd(1, 4);
		else
			level_size = wseq_rnd(3, 12);

		count = 0;
		while (level_size > 0 && count++ < 500)
			level_size -= fill_out_level(map, l);

		if (l == clev1 || l == clev2 || l == clev3)
			add_chamber(map, l);
	}
	while (l < nlevels);

	/*
	 * No longer just safe havens - any sewer that goes to 11
	 * can now connect to the underworld
	 */
	if (l > 10)
	{
#if 0
		ret = filled_locs(map, l, DIR_W);

		subworld_city = new_ent(T_loc, sub_city);
		set_where(subworld_city, random_subworld_loc());
#else
		/*
		 * What was that about?  22 levels down and up again?
		 * Get real.
		 * Just link to the underworld via a vertical sewer.
		 */
		square = filled_locs(map, l, 0);

		subworld_city = new_ent(T_loc, sub_city);
		set_where(subworld_city, random_subworld_loc());
		sprintf(name_buffer, "Under%s", display_name(city));
		name_buffer[5] = tolower(name_buffer[5]);
		set_name(subworld_city, name_buffer);

		sewer = new_ent(T_loc, sub_sewer);
		p_loc(sewer)->hidden = TRUE;
		set_where(sewer, subworld_city);

		fill_dir_exits(sewer);

		p_loc(sewer)->prov_dest[DIR_UP-1] = square;
		p_loc(square)->prov_dest[DIR_DOWN-1] = sewer;

		seed_city(subworld_city);
		printf("Sewers from %s reach subworld city %s\n",
				box_name(city), box_name(subworld_city));
#endif
	}

	if (subworld_link)
	{
		int square;

		printf("creating subworld link for city %s, link loc %s\n",
				box_code_less(subworld_city), box_code_less(subworld_link));

		assert(safe_haven(city) == FALSE);

		square = filled_locs(map, l, DIR_E);

		p_loc(square)->prov_dest[DIR_E-1] = subworld_link;
		p_loc(subworld_link)->prov_dest[DIR_W-1] = square;
	}

#if 0
	fprintf(stderr, "%s tunnels: %d levels, %d locs\n",
				box_name(city), nlevels+1, tun_total_locs);
#endif
	print_dot('.');

	return ret;
}


void
create_tunnels(void)
{
	int city;
	int sum = 0;
	int link;

	tunnel_region = new_ent(T_loc, sub_region);
	set_name(tunnel_region, "Undercity");

	create_subworld();

	fprintf(stderr, "INIT: creating %s\n", box_name(tunnel_region));

	loop_city(city)
	{
		if (greater_region(city) != 0)
			continue;

		if (region(city) == cloud_region)
			continue;

		if (safe_haven(city) || wgen_gate(city) == 1)
		{
			link = create_tunnel_set(city, 0);
			sum += tun_total_locs;

			if (link)
			{
				create_tunnel_set(subworld_city, link);
				sum += tun_total_locs;
			}
		}
	}
	next_city;

	fprintf(stderr, "\n%d total tunnel locs\n", sum);
}

