# Dead Code
Samples of code that was dead in the G3 sources.
Kept for history and possible revival.
(Even with Git, we can't resist the temptation.)

> **Removed from source in issue #25 Unit F (mint).** The samples below were all
> dead (`#if 0`, commented out, or uncalled statics). The #25 exit gate audits
> the engine sources for *any* `rnd(` call site (`tests/rng/check.sh`), and that
> grep is pure text — it cannot skip `#if 0` or comments — so the dead `rnd()`
> sites had to be physically deleted for the gate to read zero. They are archived
> here instead. The four added by Unit F (Okay Entity Code, Add Token Unit,
> Swap Region Locs, Random Body Here) join the five that predate it (Equip Noble,
> Tunnels to Hades, Trade Expire Jitter, Nearby Grave, Free Artifact).

## Equip Noble
From `c1.c`.

```c++
#if 0
/*
 *  Some micromodeling nonsense to randomly equip a new noble
 *  with a few items or skills
 */

static void
equip_new_noble(int who, int new)
{
	int where = subloc(who);
	int n;
	int qty;

	if (rnd(1,4) == 1)	/* appropriate region skill */
	{
		if (is_port_city(where) && rnd(1,5) < 5)
		{
			n = sk_shipcraft;
		}
		else if (has_ocean_access(where) && rnd(1,2) == 1)
		{
			n = sk_shipcraft;
		}
		else
		{
			switch (rnd(1,4))
			{
			case 1:
			case 2:
				n = sk_combat;
				break;

			case 3:
				n = sk_construction;
				break;

			case 4:
				n = sk_stealth;
				break;

			default:
				assert(FALSE);
			}
		}

		set_skill(new, n, SKILL_know);
		wout(who, "%s knows %s.", just_name(new), box_name(n));
	}

	if (rnd(1,5) == 1)	/* a possession */
	{
		qty = 1;

		switch (rnd(1,5))
		{
		case 1:		/* gold */
			qty = rnd(50, 550);
			n = item_gold;
			break;

		case 2:
			n = item_riding_horse;
			break;

		case 3:
			n = item_longsword;
			break;

		case 4:
			n = item_longbow;
			break;

		case 5:
			n = item_warmount;
			break;

		default:
			assert(FALSE);
		}

		gen_item(new, n, qty);
		wout(who, "%s has %s.", just_name(new), just_name_qty(n, qty));
	}
}
#endif

static void
form_new_noble(int who, char *name, int new)
{
	struct entity_char *p;
	struct entity_char *op;

	assert(kind(new) == T_unform);

	change_box_kind(new, T_char);

	p = p_char(new);
	op = p_char(who);

	p->behind = op->behind;
	p->fresh_hire = TRUE;
	p->health = 100;

	p_char(new)->attack = 80;
	p_char(new)->defense = 80;
	p_char(new)->break_point = 50;

	set_name(new, name);

	set_where(new, subloc(who));
	set_lord(new, player(who), LOY_contract, 500);

	join_stack(new, who);

#if 0
	equip_new_noble(who, new);
#endif
}
```

## Tunnels to Hades
From `tunnel.c`, around line 505, just before `any sewer that goes to 11`.

```c++
/*
	if (l == 5 && rnd(1,2) == 1)
	{
		int hades;

		hades = random_hades_loc();
		square = filled_locs(map, l, 0);

		p_loc(square)->hidden = TRUE;
		p_loc(square)->prov_dest[DIR_DOWN-1] = hades;
		fill_dir_exits(hades);
		p_loc(hades)->prov_dest[DIR_UP-1] = square;
		printf("(hades from sewer at %s)\n",
			box_code_less(square));
	}
*/
```

## Trade Expire Jitter
From `buy.c`, in `d_find_buy()` (around line 1547).
A commented-out random jitter on a city trade's expiry, left inline:

```c++
	tt->expire = t->expire; /*  + rnd(2,5); */
```

## Nearby Grave
From `u.c`.

```c++
#if 0
static int
nearby_grave(int where)
{
	struct entity_loc *p;
	int i;
	static ilist l = NULL;

	where = province(where);
	p = rp_loc(where);

	if (p && p->near_grave)
		return p->near_grave;

	log(LOG_CODE, "%s has no nearby grave", box_name(where));

	ilist_clear(&l);
	loop_subkind(sub_graveyard, i)
	{
		ilist_append(&l, i);
	}
	next_subkind;

	assert(ilist_len(l) > 0);

	ilist_scramble(l);

	return l[rnd(0, ilist_len(l)-1)];
}
#endif
```

## Free Artifact
From `quest.c`.

```c++
#if 0
/*
 *  Find an artifact in our region held by a subloc monster
 *  which is not only-defeatable by another artifact.
 */

static int
free_artifact(int where)
{
	int reg = region(where);
	int i;
	int owner;
	ilist l = NULL;
	int ret;

	loop_item(i)
	{
		if (subkind(i) != sub_artifact)
			continue;

		owner = item_unique(i);
		assert(owner);

		if (region(owner) != reg)
			continue;

		if (!is_npc(owner) ||
		    npc_program(owner) != PROG_subloc_monster)
			continue;

		if (only_defeatable(owner))
			continue;

		ilist_append(&l, i);
	}
	next_item;

	if (ilist_len(l) == 0)
		return 0;

	ret = l[rnd(0,ilist_len(l)-1)];

	ilist_reclaim(&l);

	return ret;
}
#endif
```

Its only caller is also dead — a `#if 0` block in `make_subloc_monster()`
(`quest.c`, around line 597) that would have given the monster a free artifact:

```c++
#if 0
	if (rnd(1,6) == 1)
	{
		int item;

/*
 *  Temporarily set only_vulnerable for ourselves so we don't
 *  have a circular problem.  free_artifact() will take care of
 *  skipping over other only_vulnerable's.
 */
		p_misc(monster)->only_vulnerable = 1;
		item = free_artifact(monster);

		if (item)
			rp_misc(monster)->only_vulnerable = item;
		else
			rp_misc(monster)->only_vulnerable = 0;
	}
#endif
```

## Random Body Here
From `necro.c`.

```c++
static int
random_body_here(int where)
{
	struct item_ent *e;
	static ilist l = NULL;

	ilist_clear(&l);

	loop_inv(where, e)
	{
		if (subkind(e->item) == sub_dead_body &&
		    sysclock.turn > p_char(e->item)->death_time.turn)
		{
			ilist_append(&l, e->item);
		}
	}
	next_inv;

	if (ilist_len(l) == 0)
		return 0;

	ilist_scramble(l);

	return l[0];
}
```

Uncalled static. Its `ilist_scramble()` was the necromancer half of the
indirect global-`rnd()` draws Unit F swept up; the function had no live caller,
so it was deleted rather than migrated.

## Okay Entity Code
From `code.c`, a `#if 0` helper inside the entity-id allocator (`rnd_alloc_num`)
that skipped visually ambiguous box codes (`o`/`0`/`l`/`1`/`i`). The allocator's
two `#if 0` scan-with-`okay_entity_code` loops and the failure `fprintf` went
with it when the allocator moved onto the `mint` stream.

```c++
#if 0
static int
okay_entity_code(int n)
{
	char *s, *p;

	s = box_code_less(n);

	for (p = s; *p; p++)
		if (*p == 'o' || *p == '0' ||
		    *p == 'l' || *p == '1' || *p == 'i')
		return FALSE;

	return TRUE;
}
#endif
```

## Add Token Unit
From `art.c`, a `#if 0` line in `add_token_unit()` that would have stocked a new
token-summoned unit with `rnd(3,15)` of its native item.

```c++
#if 0
	gen_item(new, item_token_ni(item), rnd(3,15));
#endif
```

## Swap Region Locs
From `faery.c`, an entire `#if 0` function (`swap_region_locs`) — region
"weirdness" that randomly swapped two province locations' exits. Its only caller
was itself a `#if 0` block in `day.c`'s `post_month()`. Both were deleted in
Unit F (the function's `ilist_scramble()` was one of the indirect global-`rnd()`
draws, but unreachable).

```c++
#if 0
void
swap_region_locs(int reg)
{
	ilist l = NULL;
	int i;
	int j;
	int who;
	int skip;

	loop_loc(i)
	{
		if (region(i) != reg)
			continue;
		if (loc_depth(i) != LOC_province)
			continue;

		skip = FALSE;
		loop_char_here(i, who)
		{
			if (char_moving(who) && player(who) == sub_pl_regular)
				skip = TRUE;
		}
		next_char_here;

		if (skip)
			continue;

		ilist_append(&l, i);
	}
	next_loc;

	if (ilist_len(l) < 2)
	{
		fprintf(stderr, "can't find two swappable locs for %s\n", box_name(reg));
		ilist_reclaim(&l);
		return;
	}

	ilist_scramble(l);

	/* ... swap the prov_dest exits of l[0] and l[1] across the region ... */
}
#endif
```