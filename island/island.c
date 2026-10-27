/*
 * Add a randomly generated island to the map supplied as stdin.
 * The map is assumed to be one suitable for use by mapgen.
 * A border 2 squares wide is preserved around the edge of the
 * map, but this can be changed with the -b parameter.
 * Existing land masses will have a 3 square continental shelf
 * maintained; this can be changed with the -c parameter.
 * The size of the island can be specified with the -s
 * parameter, but if this is not given then a random size
 * will be chosen using the sum of two poisson distributions
 * with mean 100 each, for a slightly normalised distribution
 * with mean 200.
 * The input map must be square; a simple way to start a new
 * map is to start with a file containing the target size of
 * water characters ("." is nicely visible) and feeding it
 * through a pipeline of this executable, repeated the number
 * of times you want islands.
 * For example:
 *   island < empty_map | island | island | island | island
 */

#include <stdio.h>
#include <string.h>
#include <getopt.h>
#include <stdlib.h>

/*
 *  Shared MD5 RNG (lib/rnd.c) — rnd()/load_seed()/save_seed() used here.
 */
#include "../lib/rnd.h"

#define MAX_MAP			120
#define LINE_MAX		200
#define DISTANCE_CAP		9

typedef struct
{
	int x, y;
} location;

typedef struct
{
	char symbol;
	int min, max;
	int target_prob, prob;
} terrain;

/*
 *  WARNING: these terrain glyphs ('p' plain, 'f' forest, 'm' mountain,
 *  'd' desert, 's' swamp) are the map's shared vocabulary — mapgen reads the
 *  very same symbols (see the case labels in mapgen/mapgen.c) when it turns a
 *  map into locations.  The same applies to the OCEAN glyphs: the author may
 *  seed the starting map with any glyph mapgen treats as ocean —
 *  ';' ',' ':' '.' '~' ' ' '"' '\'' (the ';' ':' '~' '"' variants become sea
 *  lanes in mapgen; sea lanes are assigned later, but the glyph is still ocean).
 *  The input classifier in main() must recognize that whole set as water, or
 *  island will mistake an author's ocean for land.  '_' is NOT part of this
 *  vocabulary: it is island's private continental-shelf marker, used only in
 *  the `working` scratch grid and never printed (see make_shelf).
 *  Any change to these characters must be coordinated with mapgen or the two
 *  programs will disagree about what the map means.
 */
terrain terrains[] =
{
	{ 'p', 12, 30, 30, 0 },
	{ 'f',  6, 14, 30, 0 },
	{ 'm',  6, 10, 20, 0 },
	{ 'd', 15, 30, 10, 0 },
	{ 's',  1,  3, 10, 0 }
};

static void make_shelf(
	char working[][MAX_MAP],
	int y_size,
	int x_size,
	int shelf)
{
	/*
	 *  Mark water ('~') within `shelf` squares of a land square as '_', the
	 *  continental-shelf exclusion marker, so new-island placement keeps clear
	 *  of existing land.  '_' is INTERNAL scratch state: it is written only into
	 *  the `working` classification grid (never the output `map`), and is read
	 *  back implicitly by the distance-from-land pass, which only propagates
	 *  through '~' cells -- a '_' cell gets distance 0 and is never chosen as an
	 *  island seed.  It is therefore never printed and never reaches mapgen.
	 *
	 *  "Within `shelf` squares" counts north/south/east/west steps through any
	 *  square on the map.  One breadth-first pass from every land square marks
	 *  the same squares the old per-square recursion did, which took 4^shelf
	 *  calls per land square and `shelf` stack frames (#307).
	 */
	static int steps[MAX_MAP][MAX_MAP];
	static location queue[MAX_MAP * MAX_MAP];
	static const int dy[4] = { -1, 1, 0, 0 };
	static const int dx[4] = { 0, 0, -1, 1 };
	int head = 0, tail = 0;
	int x, y, k, ny, nx;

	for (y = 0; y < y_size; y++)
		for (x = 0; x < x_size; x++)
			if (working[y][x] == 'p')
			{
				steps[y][x] = 0;
				queue[tail].y = y;
				queue[tail].x = x;
				tail++;
			}
			else
				steps[y][x] = -1;

	while (head < tail)
	{
		y = queue[head].y;
		x = queue[head].x;
		head++;
		if (steps[y][x] >= shelf)
			continue;
		for (k = 0; k < 4; k++)
		{
			ny = y + dy[k];
			nx = x + dx[k];
			if (ny < 0 || ny >= y_size || nx < 0 || nx >= x_size || steps[ny][nx] >= 0)
				continue;
			steps[ny][nx] = steps[y][x] + 1;
			if (working[ny][nx] == '~')
				working[ny][nx] = '_';
			queue[tail].y = ny;
			queue[tail].x = nx;
			tail++;
		}
	}

	return;
}

static void extend_distance(
	char distance[][MAX_MAP],
	int y,
	int x,
	int y_size,
	int x_size)
{
	if (y > 0 && distance[y - 1][x] > distance[y][x] + 1)
	{
		distance[y - 1][x] = distance[y][x] + 1;
		extend_distance(distance, y - 1, x, y_size, x_size);
	}
	if (y < y_size - 1 && distance[y + 1][x] > distance[y][x] + 1)
	{
		distance[y + 1][x] = distance[y][x] + 1;
		extend_distance(distance, y + 1, x, y_size, x_size);
	}
	if (x > 0 && distance[y][x - 1] > distance[y][x] + 1)
	{
		distance[y][x - 1] = distance[y][x] + 1;
		extend_distance(distance, y, x - 1, y_size, x_size);
	}
	if (x < x_size - 1 && distance[y][x + 1] > distance[y][x] + 1)
	{
		distance[y][x + 1] = distance[y][x] + 1;
		extend_distance(distance, y, x + 1, y_size, x_size);
	}

	return;
}

static int gcd(int a, int b)
{
	int temp;

	while (b)
	{
		temp = b;
		b = a % b;
		a = temp;
	}

	return a;
}

static int lcm(int a, int b)
{
	return a * b / gcd(a, b);
}

int main(int argc, char *argv[])
{
	char map[MAX_MAP][MAX_MAP];
	char working[MAX_MAP][MAX_MAP];
	char distance[MAX_MAP][MAX_MAP];
	int ids[MAX_MAP][MAX_MAP];
	char buffer[LINE_MAX];
	location *island;
	FILE *fp;
	int opt, x_size, y_size, x, y, max, count, d, island_size, i;
	int GCD, LCM, o, terr, temp, size, cluster_end, id;
	int target_size = 0;
	int border = 2;
	int shelf = 3;

	opterr = 0;
	while ((opt = getopt(argc, argv, "b:c:s:")) != -1)
		switch (opt)
		{
			case 'b':
				border = atoi(optarg);
				break;
			case 'c':
				shelf = atoi(optarg);
				break;
			case 's':
				target_size = atoi(optarg);
				break;
			default:
				/* A fixed name, not argv[0]: the line is the same however island is run (#300) */
				fprintf(stderr, "Usage: island-g3 -b border_width -c continental_shelf_width -s size\n");
				exit(1);
		}

	if (border < 0)
		border = 0;

	if (shelf < 0)
		shelf = 0;

	x_size = y_size = 0;

	/* Read the starting map from stdin */
	while (fgets(buffer, LINE_MAX, stdin))
	{
		/*
		 *  Each row of map[] holds MAX_MAP - 1 characters and a NUL, and there
		 *  are MAX_MAP rows.  Reject a bigger map before sscanf() writes past
		 *  them; that includes a skipped row, and a line fgets() split (#299).
		 */
		if (strcspn(buffer, "\r\n") > MAX_MAP - 1)
		{
			fprintf(stderr, "Map row longer than %d characters!\n", MAX_MAP - 1);
			exit(1);
		}
		if (y_size == MAX_MAP && strcspn(buffer, "\r\n") > 0)
		{
			fprintf(stderr, "Map taller than %d rows!\n", MAX_MAP);
			exit(1);
		}
		/* Only a match counts: a line starting with NUL gives EOF (#303) */
		if (sscanf(buffer, "%[^\r\n]", map[y_size]) == 1)
		{
			if (!x_size)
				x_size = (int) strlen(map[y_size]);	/* map row len fits 32 bits */
			if (strlen(map[y_size]) == x_size)
				y_size++;
		}
	}

	/* No rows: nothing to place an island in (#295) */
	if (y_size == 0)
	{
		fprintf(stderr, "No map on stdin!\n");
		exit(1);
	}

	/*
	 *  load_seed() reports a missing randseed with printf(), which would put
	 *  the message in the map on stdout.  Report it on stderr instead and
	 *  run, as load_seed() does, from the all-zero seed (#298).
	 */
	fp = fopen("randseed", "rb");
	if (fp)
	{
		fclose(fp);
		load_seed("randseed");
	}
	else
		fprintf(stderr, "randseed could not be opened.\n");

	/* Divide the map into available (water) and unavailable (land) space. */
	/*
	 *  Water is any glyph mapgen treats as ocean -- the author may seed the
	 *  initial map with any of them (sea-lane variants included; sea lanes are
	 *  assigned later, but the glyph is still ocean to mapgen).  This set MUST
	 *  match mapgen's ocean cases (see the coordination note above terrains[]):
	 *    ';' ','  ':' '.'  '~' ' '  '"' '\''
	 *  The original map glyph is preserved verbatim in the output; `working` is
	 *  only a scratch classification for island placement.
	 */
	for (y = 0; y < y_size; y++)
		for (x = 0; x < x_size; x++)
		{
			switch (map[y][x])
			{
				case ';':
				case ',':
				case ':':
				case '.':
				case '~':
				case ' ':
				case '"':
				case '\'':
					working[y][x] = '~';
					break;
				default:
					working[y][x] = 'p';
					break;
			}
			ids[y][x] = 0;
		}
	/* exclude any square within shelf of a land square */
	make_shelf(working, y_size, x_size, shelf);
	/* exclude border squares around each edge */
	/* A border wider than the map stops at its edge (#302) */
	for (y = 0; y < y_size; y++)
		for (x = 0; x < border && x < x_size; x++)
		{
			if (working[y][x] == '~')
				working[y][x] = '_';
			if (working[y][x_size - x - 1] == '~')
				working[y][x_size - x - 1] = '_';
		}
	for (x = 0; x < x_size; x++)
		for (y = 0; y < border && y < y_size; y++)
		{
			if (working[y][x] == '~')
				working[y][x] = '_';
			if (working[y_size - y - 1][x] == '~')
				working[y_size - y - 1][x] = '_';
		}
	/* Calculate distance from land */
	for (y = 0; y < y_size; y++)
		for (x = 0; x < x_size; x++)
		{
			if (working[y][x] == '~')
				distance[y][x] = DISTANCE_CAP;
			else
				distance[y][x] = 0;
		}
	for (y = 0; y < y_size; y++)
		for (x = 0; x < x_size; x++)
			extend_distance(distance, y, x, y_size, x_size);

	/*
	 *  No water left outside the shelf and border: every square has distance
	 *  0, and the start-square draw below would pick from all of them, land
	 *  included.  Stop before any draw, so randseed is not rewritten (#305).
	 */
	for (y = 0, max = 0; y < y_size; y++)
		for (x = 0; x < x_size; x++)
			if (distance[y][x] > max)
				max = distance[y][x];
	if (max == 0)
	{
		fprintf(stderr, "No room for an island!\n");
		exit(1);
	}

	if (target_size < 1)
	{
		/* Decide how big to make the island */
		/* Count from 0: any size below 1 means random (#294) */
		target_size = 0;
		for (i = 0; i < 2; i++)
			while (rnd(0, 99))
				target_size++;
	}
	island = malloc((size_t)(target_size + 1) * sizeof(*island));
	if (!island) {
		fprintf(stderr, "Unable to allocate memory for island data!\n");
		exit(1);
	}
	/* select a square to start the new island */
	max = 0;
	count = 0;
	island_size = 0;
	for (y = 0; y < y_size; y++)
		for (x = 0; x < x_size; x++)
		{
			if (distance[y][x] > max)
			{
				max = distance[y][x];
				count = 1;
			}
			else if (distance[y][x] == max)
			{
				count++;
			}
		}
	d = rnd(1, count);
	for (y = 0; d > 0 && y < y_size; y++)
		for (x = 0; d > 0 && x < x_size; x++)
			if (distance[y][x] == max)
			{
				d--;
				if (!d)
				{
					island[0].x = x;
					island[0].y = y;
					island_size = 1;
					working[y][x] = 'o';
					map[y][x] = 'o';
					ids[y][x] = 0;
				}
			}
	while (island_size < target_size)
	{
		/* Find all the possible expansions */
		/* Count multiple access paths multiple times to */
		/* make the island more likely to fill interior space */
		count = 0;
		for (i = 0; i < island_size; i++)
		{
			if (island[i].x > 0 && working[island[i].y][island[i].x - 1] == '~')
				count++;
			if (island[i].x < x_size - 1 && working[island[i].y][island[i].x + 1] == '~')
				count++;
			if (island[i].y > 0 && working[island[i].y - 1][island[i].x] == '~')
				count++;
			if (island[i].y < y_size - 1 && working[island[i].y + 1][island[i].x] == '~')
				count++;
		}
		if (count < 1)
		{
			fprintf(stderr, "Not enough room to expand island!\n");
			break;
		}
		d = rnd(0, count - 1);
		for (i = 0; i < island_size; i++)
		{
			if (island[i].x > 0 && working[island[i].y][island[i].x - 1] == '~')
				if (!d--)
				{
					island[island_size].x = island[i].x - 1;
					island[island_size].y = island[i].y;
				}
			if (island[i].x < x_size - 1 && working[island[i].y][island[i].x + 1] == '~')
				if (!d--)
				{
					island[island_size].x = island[i].x + 1;
					island[island_size].y = island[i].y;
				}
			if (island[i].y > 0 && working[island[i].y - 1][island[i].x] == '~')
				if (!d--)
				{
					island[island_size].x = island[i].x;
					island[island_size].y = island[i].y - 1;
				}
			if (island[i].y < y_size - 1 && working[island[i].y + 1][island[i].x] == '~')
				if (!d--)
				{
					island[island_size].x = island[i].x;
					island[island_size].y = island[i].y + 1;
				}
		}
		working[island[island_size].y][island[island_size].x] = 'o';
		map[island[island_size].y][island[island_size].x] = 'o';
		ids[island[island_size].y][island[island_size].x] = island_size;
		island_size++;
	}

	/* Calculate terrain ratios */
	/* Use GCD and LCM to render these down to integer ratios */
	for (i = 0; i < sizeof(terrains) / sizeof(terrains[0]); i++)
	{
		terrains[i].prob = terrains[i].min + terrains[i].max;
		GCD = gcd(terrains[i].target_prob, terrains[i].prob);
		terrains[i].target_prob /= GCD;
		terrains[i].prob /= GCD;
	}
	for (i = 0, LCM = 1; i < sizeof(terrains) / sizeof(terrains[0]); i++)
		LCM = lcm(LCM, terrains[i].prob);
	for (i = 0, count = 0; i < sizeof(terrains) / sizeof(terrains[0]); i++)
	{
		terrains[i].target_prob *= LCM / terrains[i].prob;
		count += terrains[i].target_prob;
	}

	o = island_size;
	size = 0;
	while (o > 0)
	{
		/* pick a random square on the island */
		cluster_end = o;
		o--;
		d = rnd(0, o);
		/* Move that square to the end of the list */
		temp = island[d].x;
		island[d].x = island[o].x;
		island[o].x = temp;
		temp = island[d].y;
		island[d].y = island[o].y;
		island[o].y = temp;
		ids[island[o].y][island[o].x] = o;
		ids[island[d].y][island[d].x] = d;
		if (size < 1)
		{
			/* Pick a random terrain type */
			d = rnd(1, count);
			for (terr = 0; d > terrains[terr].target_prob; terr++)
				d -= terrains[terr].target_prob;
			/* Determine how big this cluster should be */
			size = rnd(terrains[terr].min, terrains[terr].max);
		}
		/* set the first square to this terrain type */
		map[island[o].y][island[o].x] = terrains[terr].symbol;
		working[island[o].y][island[o].x] = terrains[terr].symbol;
		size--;
		if (size > o)
			size = o;
		while (size > 0)
		{
			for (i = o, opt = 0; i < cluster_end; i++)
			{
				if (island[i].y > 0 && working[island[i].y - 1][island[i].x] == 'o')
					opt++;
				if (island[i].y < y_size - 1 && working[island[i].y + 1][island[i].x] == 'o')
					opt++;
				if (island[i].x > 0 && working[island[i].y][island[i].x - 1] == 'o')
					opt++;
				if (island[i].x < x_size - 1 && working[island[i].y][island[i].x + 1] == 'o')
					opt++;
			}
			if (opt < 1)
				break;
			d = rnd(0, opt - 1);
			for (i = o; i < cluster_end; i++)
			{
				if (island[i].y > 0 && working[island[i].y - 1][island[i].x] == 'o')
					if (!d--)
					{
						id = ids[island[i].y - 1][island[i].x];
						break;
					}
				if (island[i].y < y_size - 1 && working[island[i].y + 1][island[i].x] == 'o')
					if (!d--)
					{
						id = ids[island[i].y + 1][island[i].x];
						break;
					}
				if (island[i].x > 0 && working[island[i].y][island[i].x - 1] == 'o')
					if (!d--)
					{
						id = ids[island[i].y][island[i].x - 1];
						break;
					}
				if (island[i].x < x_size - 1 && working[island[i].y][island[i].x + 1] == 'o')
					if (!d--)
					{
						id = ids[island[i].y][island[i].x + 1];
						break;
					}
			}
			o--;
			size--;
			temp = island[id].x;
			island[id].x = island[o].x;
			island[o].x = temp;
			temp = island[id].y;
			island[id].y = island[o].y;
			island[o].y = temp;
			map[island[o].y][island[o].x] = terrains[terr].symbol;
			working[island[o].y][island[o].x] = terrains[terr].symbol;
			ids[island[o].y][island[o].x] = o;
			ids[island[id].y][island[id].x] = id;
		}
	}

	save_seed("randseed");

	fprintf(stderr, "Added island of %d provinces.\n", island_size);

	/* Print the map with the added island */
	for (y = 0; y < y_size; y++)
		printf("%s\n", map[y]);

	return 0;
}

