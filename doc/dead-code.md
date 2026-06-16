# Dead Code
Samples of code that was dead in the G3 sources.
Kept for history and possible revival.
(Even with Git, we can't resist the temptation.)

# c1.c - Equip Noble
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