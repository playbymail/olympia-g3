/*
 *  Basic magic
 */

#include	<stdio.h>
#include 	<stdlib.h>
#include	"z.h"
#include	"oly.h"
#include	"rng.h"


/*
 *  issue #25 (step 10): magic RNG stream (command core).
 *
 *  The unambiguous, player-cast spell draws across the magic subsystem --
 *  scrying (scry.c), religion gates (relig.c), necromancy eat-dead/skill
 *  transfer (necro.c), the meditation/aura + heal spells (basic.c, inherited
 *  from the skills step-9 deferral), the alchemy potion brew/use draws
 *  (alchem.c, also a skills-step-9 deferral), and the artifact-crafting command
 *  draws (art.c FORGE AURACULUM / USE orb / USE suffuse-ring -- the post-magic
 *  crafting follow-up) -- draw from a per-turn
 *  `magic_rng` stream keyed off the turn root, tag "magc", instead of the
 *  global rnd(). Like explore/skills/upkeep (and unlike combat/quest's fresh
 *  per-scenario sequential stream), this is ONE per-turn stream seeded once via
 *  the turn-guarded begin_magic(), with all draws being KEYED LEAVES (rng_keyed,
 *  which never advances a counter). The actor goes in the leaf key k1 -- not the
 *  map's literal "scenario key = actor" -- because the draws are scattered
 *  across six files (scry.c, relig.c, necro.c, basic.c, alchem.c, art.c) with no
 *  single per-actor chokepoint, and one actor may cast several spells in a turn.
 *  Carrying the actor in the leaf key gives identical per-(actor, context)
 *  addressability for free and is collision-free across spells (the
 *  explore/skills precedent). Every draw is command-only, so this migration is
 *  byte-neutral on both golden trees (no spell/USE/BREW order is issued on the
 *  bare-map or guard-pillage turns, and none fire at world-init -- verified
 *  empirically: 0 draws on the bare-map turn, both guard-pillage twins, and the
 *  -s/-a/-i world-init).
 *
 *  This is a DELIBERATE PARTIAL of the magic row (command core only). Deferred
 *  as named residuals (each would move a manifest or belongs to another system):
 *    - day.c curse_erode_day -- a turn-auto day-pick fired every turn via
 *      daily_events; migrating it moves the MAIN manifest (the economy/weather
 *      profile), so it was deferred from this byte-neutral slice. SINCE LANDED as
 *      endgame Unit B on the "caln" calendar stream (day.c begin_calendar/cal_day).
 *    - necro.c auto_undead -- autonomous summoned-undead behavior (reached only
 *      from npc.c's auto-behavior dispatch), not a player spell; an NPC residual.
 *    - necro undead summoning troop-count -- already on the npcs stream via
 *      do_cookie_npc (the npc migration); not touched here.
 *    - art.c artifact-crafting COMMAND draws (FORGE AURACULUM kind+weight, USE
 *      orb, USE suffuse-ring) landed here on magc (magc_forge/magc_orb/magc_ring,
 *      the crafting follow-up). The art.c shared-infra MINTERS stay deferred:
 *      new_orb + create_npc_token (reached only from quest.c loot) are quest
 *      residuals, and new_suffuse_ring (reached from buy.c trade_suffuse_ring,
 *      the per-turn economy restock that fires ~22-42x on the standard turn) is
 *      an economy residual -- migrating it would move the MAIN manifest. The
 *      flagged world-init mint risk did NOT materialize: 0 art.c draws at
 *      -s/-a/-i (verified empirically). add_token_unit_sup's rnd is dead (#if 0).
 *    - cloud.c -- region:cloud (step 12).
 *
 *  Hosted here (basic.c, the core-spell file); begin_magic() and the basic.c
 *  meditation/heal helpers (magc_med/magc_omen/magc_heal) are static, while
 *  magc_scry/magc_piety/magc_eat/magc_learn/magc_potion plus the crafting
 *  helpers magc_forge/magc_orb/magc_ring are exposed via proto.h so
 *  scry.c/relig.c/necro.c/alchem.c/art.c draw from the same stream (the
 *  begin_economy/skil_crit cross-file convention).
 */
#define	TAG_TURN	0x7475726eu	/* "turn" */
#define	TAG_MAGIC	0x6d616763u	/* "magc" */

/* magic leaf-draw purpose tags (private, like use.c's STAG_* / c1.c's XTAG_*) */
#define	MTAG_SCRY	0x73637279u	/* "scry" -- scry/locate/unbarrier gates       */
#define	MTAG_PIETY	0x70696574u	/* "piet" -- religion success gates            */
#define	MTAG_EATD	0x65617464u	/* "eatd" -- necro eat-dead destroy/sick gates */
#define	MTAG_LEARN	0x6c65726eu	/* "lern" -- necro skill-transfer per-skill    */
#define	MTAG_MED	0x6d656469u	/* "medi" -- meditation/adv-med gates          */
#define	MTAG_OMEN	0x6f6d656eu	/* "omen" -- hinder-meditation omen flavor     */
#define	MTAG_HEAL	0x6865616cu	/* "heal" -- Heal spell success gate           */
#define	MTAG_POTN	0x706f746eu	/* "potn" -- alchemy potion brew/use draws     */
#define	MTAG_FORG	0x666f7267u	/* "forg" -- forge-auraculum kind + weight     */
#define	MTAG_ORB	0x6f726220u	/* "orb " -- USE orb murky-image gate          */
#define	MTAG_RING	0x72696e67u	/* "ring" -- USE suffuse-ring suffuse gate     */

static rng_stream magic_rng;
static int magic_rng_turn = -1;		/* seed magic_rng once per turn */

/*
 *  Seed the per-turn magic stream once per turn. Self-seeded by every helper
 *  below (including the cross-file magc_scry/magc_piety/magc_eat/magc_learn/
 *  magc_potion), so the first spell draw of the turn cannot read an unseeded
 *  stream regardless of which spell fires first.
 */
static void
begin_magic(void)
{
	uint32_t m[4];
	rng_stream root, turn;

	if (magic_rng_turn == sysclock.turn)
		return;			/* already seeded this turn */

	rng_master_seed(m);
	root = rng_seed(m);
	turn = rng_stream_of(&root, sysclock.turn, TAG_TURN);
	magic_rng = rng_stream_of(&turn, 0, TAG_MAGIC);

	magic_rng_turn = sysclock.turn;
}

/* scry.c: LOCATE CHARACTER / REMOVE BARRIER success gate, keyed on (who, k2). */
int
magc_scry(int who, int k2)
{
	begin_magic();
	return rng_keyed(&magic_rng, who, k2, MTAG_SCRY, 1, 100);
}

/* relig.c: REVEAL VISION / RESURRECT / REMOVE BLESSING piety gate, keyed (who, k2). */
int
magc_piety(int who, int k2)
{
	begin_magic();
	return rng_keyed(&magic_rng, who, k2, MTAG_PIETY, 1, 100);
}

/*
 *  necro.c EAT DEAD: the 33% destroy (sub 0) and 25% sick (sub 1) gates, keyed
 *  on (who, body) with the sub folded into the leaf key (body*2 + sub) so each
 *  is an independent keyed leaf (the skills petty / weather day*16+slot precedent).
 */
int
magc_eat(int who, int body, int sub)
{
	begin_magic();
	return rng_keyed(&magic_rng, who, body * 2 + sub, MTAG_EATD, 1, 100);
}

/* necro.c get_some_skills: per-skill transfer check, keyed on (who, skill). */
int
magc_learn(int who, int skill)
{
	begin_magic();
	return rng_keyed(&magic_rng, who, skill, MTAG_LEARN, 1, 100);
}

/*
 *  alchem.c potion draws, keyed on (who, sub): new_potion kind (sub 0, 1..2),
 *  v_use_heal amount (sub 1, 0..3), v_use_slave gate (sub 2, 1..100). The range
 *  is passed in since the three sub-draws differ.
 */
int
magc_potion(int who, int sub, int low, int high)
{
	begin_magic();
	return rng_keyed(&magic_rng, who, sub, MTAG_POTN, low, high);
}

/* basic.c MEDITATE / advanced-meditation hinder gate, keyed on (who, sub). */
static int
magc_med(int who, int sub)
{
	begin_magic();
	return rng_keyed(&magic_rng, who, sub, MTAG_MED, 1, 100);
}

/* basic.c hinder-meditation omen flavor [1,4] switch, keyed on (who, other). */
static int
magc_omen(int who, int other)
{
	begin_magic();
	return rng_keyed(&magic_rng, who, other, MTAG_OMEN, 1, 4);
}

/* basic.c HEAL spell success gate, keyed on (who, target). */
static int
magc_heal(int who, int target)
{
	begin_magic();
	return rng_keyed(&magic_rng, who, target, MTAG_HEAL, 1, 100);
}

/*
 *  art.c FORGE AURACULUM (sk_forge_aura): the unnamed-ring kind (sub 0,
 *  switch(rnd(1,3))) and the auraculum weight (sub 1, rnd(1,3)), keyed on
 *  (who, sub) so each is an independent keyed leaf (the magc_eat precedent).
 */
int
magc_forge(int who, int sub)
{
	begin_magic();
	return rng_keyed(&magic_rng, who, sub, MTAG_FORG, 1, 3);
}

/* art.c USE orb (v_use_orb): the 1-in-3 murky-image failure gate, keyed (who). */
int
magc_orb(int who)
{
	begin_magic();
	return rng_keyed(&magic_rng, who, 0, MTAG_ORB, 1, 3);
}

/* art.c USE suffuse-ring (v_suffuse_ring): the 1-in-3 fizzle gate, keyed (who). */
int
magc_ring(int who)
{
	begin_magic();
	return rng_keyed(&magic_rng, who, 0, MTAG_RING, 1, 3);
}


int
v_meditate(struct command *c)
{

	wout(c->who, "Meditate for %s.", weeks(c->wait));
	return TRUE;
}


static int
hinder_med_chance(int who)
{
	struct char_magic *p;

	p = rp_magic(who);

	if (p == NULL || p->hinder_meditation < 1)
		return 0;

	switch (p->hinder_meditation)
	{
	case 1:		return 10;
	case 2:		return 25;
	case 3:		return 50;
	case 4:		return 75;
	case 5:		return 90;

	default:
		assert(FALSE);
	}
	return 0;
}


int
d_meditate(struct command *c)
{
	struct char_magic *p;
	int chance;
	int bonus;

	chance = hinder_med_chance(c->who);

	p = p_magic(c->who);
	p->hinder_meditation = 0;

	if (magc_med(c->who, 0) <= chance)	/* issue #25: magic stream */
	{
		wout(c->who, "Disturbing images and unquiet thoughts "
			"ruin the meditative trance.  Meditation fails.");
		return FALSE;
	}

	bonus = max(1, max_eff_aura(c->who) / 20);

	p->cur_aura += bonus;

	if (p->cur_aura >= max_eff_aura(c->who) + 1)
		p->cur_aura = max_eff_aura(c->who) + 1;

	wout(c->who, "Current aura is now %d.", p->cur_aura);
	return TRUE;
}


int
v_adv_med(struct command *c)
{

	wout(c->who, "Meditate for %s.", weeks(c->wait));
	return TRUE;
}


int
d_adv_med(struct command *c)
{
	struct char_magic *p;
	int chance;
	int m_a;
	int bonus;

	chance = hinder_med_chance(c->who);

	p = p_magic(c->who);
	p->hinder_meditation = 0;
	m_a = max_eff_aura(c->who);

	bonus = max(2, max_eff_aura(c->who) / 10);

	if (magc_med(c->who, 1) <= chance)	/* issue #25: magic stream */
	{
		wout(c->who, "Disturbing images and unquiet thoughts "
			"hamper the meditative trance.");
		bonus = 1;
	}

	p->cur_aura += bonus;

	if (p->cur_aura >= max_eff_aura(c->who) + 2)
		p->cur_aura = max_eff_aura(c->who) + 2;

	wout(c->who, "Current aura is now %d.", p->cur_aura);
	return TRUE;
}


int
v_hinder_med(struct command *c)
{
	int target = c->a;
	int aura;
	int where;

	if (c->b < 1)
		c->b = 1;
	if (c->b > 3)
		c->b = 3;
	aura = c->b;

	if (!check_aura(c->who, aura))
		return FALSE;

	where = reset_cast_where(c->who);
	c->d = where;

	if (!check_char_where(where, c->who, target))
		return FALSE;

	wout(c->who, "Attempt to hinder attempts at meditation by %s.",
				box_name(c->who));

	return TRUE;
}


static void
hinder_med_omen(int who, int other)
{

	switch (magc_omen(who, other))	/* issue #25: magic stream */
	{
	case 1:
		wout(who, "A disturbing image of %s appeared last "
				"night in a dream.", box_name(other));
		break;

	case 2:
		wout(who, "As a cloud drifts across the moon, it seems "
			"for an instant that it takes the shape of a "
			"ghoulish face, looking straight at you.");
		break;

	case 3:
		wout(who, "You are shocked out of your slumber in the "
			"middle of the night by cold fingers touching your "
			"neck, but when you glance about, there is no one "
			"to be seen.");
		break;

	case 4:
		break;

	default:
		assert(FALSE);
	}
}


int
d_hinder_med(struct command *c)
{
	int target = c->a;
	int aura = c->b;
	struct char_magic *p;
	int where = c->d;

	if (!charge_aura(c->who, aura))
		return FALSE;

	if (!check_char_where(where, c->who, target))
		return FALSE;

	wout(c->who, "Successfully cast %s on %s.",
				box_name(sk_hinder_med),
				box_name(target));

	p = p_magic(target);
	p->hinder_meditation += aura;

	if (p->hinder_meditation > 5)
		p->hinder_meditation = 5;

	hinder_med_omen(target, c->who);

	return TRUE;
}


int
v_heal(struct command *c)
{
	int target = c->a;
	int aura;
	int where;

	if (c->b < 1)
		c->b = 1;
	if (c->b > 3)
		c->b = 3;
	aura = c->b;

	if (!check_aura(c->who, aura))
		return FALSE;

	where = reset_cast_where(c->who);
	c->d = where;

	if (!check_char_where(where, c->who, target))
		return FALSE;

	if (!char_sick(target))
	{
		wout(c->who, "%s is not sick.", box_name(target));
		return FALSE;
	}

	return TRUE;
}


int
d_heal(struct command *c)
{
	int target = c->a;
	int aura = c->b;
	int chance;
	int where = c->d;

	if (kind(target) != T_char)
	{
		wout(c->who, "%s is no longer a character.",
					box_code(target));
		return FALSE;
	}

	if (!check_char_where(where, c->who, target))
		return FALSE;

	if (!char_sick(target))
	{
		wout(c->who, "%s is not sick.", box_name(target));
		return FALSE;
	}

	if (!charge_aura(c->who, aura))
		return FALSE;

	switch (aura)
	{
	case 1:
		chance = 30;
		break;

	case 2:
		chance = 15;
		break;

	case 3:
		chance = 5;
		break;

	default:
		assert(FALSE);
	}

	vector_clear();
	vector_add(c->who);
	vector_add(target);

	wout(VECT, "%s casts Heal on %s:",
			box_name(c->who), box_name(target));

	if (magc_heal(c->who, target) <= chance)	/* issue #25: magic stream */
	{
		wout(VECT, "Spell fails.");
		return FALSE;
	}

	p_char(target)->sick = FALSE;

	wout(VECT, "%s has been cured, and should now recover.",
				box_name(target));

	return TRUE;
}


int
v_reveal_mage(struct command *c)
{
	int target = c->a;
	int category = c->b;
	int aura;
	int where;

	if (c->c < 1)
		c->c = 1;
	aura = c->c;

	// by Cappinator:
	// Add a check that verifies of the given category is a valid skill/category id
  	if (!valid_box(category)) {
		wout(c->who, "%i is not a valid skill category.", category);
		return FALSE;
  	}

	if (!check_aura(c->who, aura))
		return FALSE;

	where = reset_cast_where(c->who);
	c->d = where;
	if (!check_char_where(where, c->who, target))
		return FALSE;

	if (skill_school(category) != category || !magic_skill(category))
	{
		wout(c->who, "%s is not a magical skill category.",
					box_code(category));
		if (!magic_skill(category))
			category = sk_basic;
		else
			category = skill_school(category);
		wout(c->who , "Assuming %s.", box_name(category));

		c->b = category;
	}

	wout(c->who, "Attempt to scry the magical abilities of %s within %s.",
				box_name(target), box_name(category));

	return TRUE;
}


int
d_reveal_mage(struct command *c)
{
	int target = c->a;
	int category = c->b;
	int aura = c->c;
	int has_detect;
	int where = c->d;
	char *source;

	if (!charge_aura(c->who, aura))
		return FALSE;

	if (!check_char_where(where, c->who, target))
		return FALSE;

	assert(valid_box(category));
	assert(skill_school(category) == category && magic_skill(category));

	has_detect = has_skill(target, sk_detect_abil);

	if (has_detect > exp_novice)
		source = box_name(c->who);
	else
		source = "Someone";

	if (aura <= char_abil_shroud(target))
	{
		wout(c->who, "The abilities of %s are shrouded from "
				"your scry.", box_name(target));

		if (has_detect)
			wout(target, "%s cast %s on us, but failed to learn "
				"anything.", source, box_name(sk_reveal_mage));

		if (has_detect > exp_teacher)
			wout(target, "They sought to learn what we "
					"know of %s.", box_name(category));

		return FALSE;
	}

	{
		int first = TRUE;
		struct skill_ent *e;

		loop_char_skill_known(target, e)
		{
			if (skill_school(e->skill) != category ||
			    e->skill == category)
				continue;

			if (first)
			{
				wout(c->who, "%s knows the following "
						"%s spells:",
						box_name(target),
						box_name(category));
				indent += 3;
				first = FALSE;
			}

			if (c->use_exp > exp_journeyman)
				list_skill_sup(c->who, e);
			else
				wout(c->who, "%s", box_name(e->skill));
		}
		next_char_skill_known;

		if (first)
			wout(c->who, "%s knowns no %s spells.",
					box_name(target), box_name(category));
		else
			indent -= 3;

	}

	if (has_detect)
	{
		wout(target, "%s successfully cast %s on us.",
			source, box_name(sk_reveal_mage));

		if (has_detect > exp_teacher)
			wout(target, "Our knowledge of %s was revealed.",
					box_name(category));
	}

	return TRUE;
}


int
v_view_aura(struct command *c)
{
	int aura;
	int where;

	if (c->a < 1)
		c->a = 1;
	aura = c->a;

	if (!check_aura(c->who, aura))
		return FALSE;

	where = reset_cast_where(c->who);
	c->d = where;

	wout(c->who, "Will scry the current aura ratings of other "
		"mages in %s.", box_name(where));

	return TRUE;
}


int
d_view_aura(struct command *c)
{
	int n;
	int level;
	int first = TRUE;
	int aura = c->a;
	int where = c->d;
	char *s;
	int has_detect;
	int learned;
	char *source;

	if (!is_loc_or_ship(where))
	{
		wout(c->who, "%s is no longer a valid location.",
				box_code(where));
		return FALSE;
	}

	if (!charge_aura(c->who, aura))
		return FALSE;

	loop_char_here(where, n)
	{
		if (is_magician(n))
		{
/*
 *  Does the viewed magician have Detect ability scry?
 */

			level = char_cur_aura(n);

			if (aura <= char_abil_shroud(n))
			{
				s = "???";
				learned = FALSE;
			}
			else
			{
				s = sout("%d", level);
				learned = TRUE;
			}

			wout(c->who, "%s, current aura: %s", box_name(n), s);
			first = FALSE;

			has_detect = has_skill(n, sk_detect_abil);

			if (has_detect > exp_novice)
				source = box_name(c->who);
			else
				source = "Someone";

			if (has_detect)
				wout(n, "%s cast View aura here.", source);

			if (has_detect > exp_journeyman)
			{
			    if (learned)
			       wout(n, "Our current aura rating was learned.");
			    else
			       wout(n, "Our current aura rating was "
							"not revealed.");
			}
		}
	}
	next_char_here;

	if (first)
	{
		wout(c->who, "No mages are seen here.");
		log_write(LOG_CODE, "d_view_aura: not a mage?\n");
	}

	return TRUE;
}


int
v_shroud_abil(struct command *c)
{
	int aura;

	if (c->a < 1)
		c->a = 1;
	aura = c->a;

	wout(c->who, "Attempt to create a magical shroud to conceal "
					"our abilities.");

	return TRUE;
}


int
d_shroud_abil(struct command *c)
{
	int aura = c->a;
	struct char_magic *p;

	if (!charge_aura(c->who, aura))
		return FALSE;

	p = p_magic(c->who);
	p->ability_shroud += aura;

	wout(c->who, "Now cloaked in an aura %s ability shroud.",
					nice_num(p->ability_shroud));

	return TRUE;
}


int
v_detect_abil(struct command *c)
{

	if (!check_aura(c->who, 1))
		return FALSE;

	wout(c->who, "Will practice ability scry detection.");
	return TRUE;
}


int
d_detect_abil(struct command *c)
{

	if (!charge_aura(c->who, 1))
		return FALSE;

	return TRUE;
}


int
v_dispel_abil(struct command *c)
{
	int target = c->a;
	int where;

	if (!check_aura(c->who, 3))
		return FALSE;

	where = reset_cast_where(c->who);
	c->d = where;

	if (!check_char_where(where, c->who, target))
		return FALSE;

	wout(c->who, "Attempt to dispel any ability shroud from %s.",
					box_name(target));

	return TRUE;
}


int
d_dispel_abil(struct command *c)
{
	int target = c->a;
	struct char_magic *p;
	int where = c->d;

	if (!check_char_where(where, c->who, target))
		return FALSE;

	p = rp_magic(target);

	if (p && p->ability_shroud > 0)
	{
		if (!charge_aura(c->who, 3))
			return FALSE;

		wout(c->who, "Dispeled an aura %s ability shroud from %s.",
						nice_num(p->ability_shroud),
						box_name(target));
		p->ability_shroud = 0;
		wout(target, "The magical ability shroud has dissipated.");
	}
	else
	{
		wout(c->who, "%s had no ability shroud.", box_name(target));
	}

	return TRUE;
}


int
v_quick_cast(struct command *c)
{
	int aura;

	if (c->a < 1)
		c->a = 1;
	aura = c->a;

	if (!check_aura(c->who, aura))
		return FALSE;

	wout(c->who, "Attempt to speed next spell cast.");

	return TRUE;
}


int
d_quick_cast(struct command *c)
{
	int aura = c->a;
	struct char_magic *p;

	if (!charge_aura(c->who, aura))
		return FALSE;

	p = p_magic(c->who);
	p->quick_cast += aura;

	wout(c->who, "Spell cast speedup now %d.", p->quick_cast);

	return TRUE;
}


int
v_save_quick(struct command *c)
{

	if (char_quick_cast(c->who) < 1)
	{
		wout(c->who, "No stored spell cast speedup.");
		return FALSE;
	}

	if (!check_aura(c->who, 3))
		return FALSE;

	wout(c->who, "Attempt to save speeded cast state.");
	return TRUE;
}


int
d_save_quick(struct command *c)
{
	int new;
	struct char_magic *p;
	struct item_magic *im;

	if (char_quick_cast(c->who) < 1)
	{
		wout(c->who, "No stored spell cast speedup.");
		return FALSE;
	}

	if (!charge_aura(c->who, 3))
		return FALSE;

	new = new_potion(c->who);

	if (new < 0)
	{
		wout(c->who, "Spell failed.");
		return FALSE;
	}

	p = p_magic(c->who);
	im = p_item_magic(new);

	im->use_key = use_quick_cast;
	im->quick_cast = p->quick_cast;

	p->quick_cast = 0;

	return TRUE;
}


int
v_use_quick_cast(struct command *c)
{
	int item = c->a;
	struct item_magic *im;

	assert(kind(item) == T_item);

	wout(c->who, "%s drinks the potion...", just_name(c->who));

	im = rp_item_magic(item);

	if (im == NULL || im->quick_cast < 1 || !is_magician(c->who))
	{
		wout(c->who, "Nothing happens.");
		destroy_unique_item(c->who, item);
		return FALSE;
	}

	p_magic(c->who)->quick_cast += im->quick_cast;

	wout(c->who, "Spell cast speedup now %d.", char_quick_cast(c->who));
	destroy_unique_item(c->who, item);

	return TRUE;
}


int
v_write_spell(struct command *c)
{
	int spell = c->a;
	int know;

	know = has_skill(c->who, spell);
	if (know < 1)
	{
		wout(c->who, "%s does not know %s.", box_name(c->who),
						box_code(spell));
		return FALSE;
	}

	if (!magic_skill(c->use_skill) && magic_skill(spell))
	{
		wout(c->who, "Magical skills may not be scribed with %s.",
					box_name(c->use_skill));
		return FALSE;
	}

	if (magic_skill(c->use_skill) &&
	    skill_school(spell) != skill_school(c->use_skill))
	{
		wout(c->who, "%s only allows %s spells to be scribed.",
					box_code(c->use_skill),
					box_name(skill_school(c->use_skill)));

		return FALSE;
	}

	if (magic_skill(c->use_skill) && !check_aura(c->who, 2))
		return FALSE;

	c->wait = max(7, learn_time(spell));

	wout(c->who, "Spend %s writing %s onto a scroll.",
				weeks(c->wait),
				box_name(spell));

	return TRUE;
}


int
new_scroll(int who)
{
	int new;
	struct item_magic *p;

	new = create_unique_item(who, sub_scroll);

	if (new < 0)
	{
		wout(who, "Scroll creation failed.");
		return FALSE;
	}

	set_name(new, "Scroll");

	p = p_item_magic(new);
	p->creator = who;
	p->region_created = province(who);
	p_item(new)->weight = 1;

	wout(who, "Produced %s.", box_name(new));

	return new;
}


int
d_write_spell(struct command *c)
{
	int spell = c->a;
	int new;
	struct item_magic *p;

	if (has_skill(c->who, spell) < 1)
	{
		wout(c->who, "%s does not know %s.",
				box_name(c->who), box_code(spell));
		return FALSE;
	}

	if (magic_skill(c->use_skill) && !charge_aura(c->who, 2))
		return FALSE;

	new = new_scroll(c->who);
	p = p_item_magic(new);
	ilist_append(&p->may_study, spell);

	return TRUE;
}


int
v_appear_common(struct command *c)
{
	int aura = c->a;
	struct char_magic *p;

	if (aura < 1)
		aura = 1;

	if (!charge_aura(c->who, aura))
		return FALSE;

	p = p_magic(c->who);
	if (p->hide_mage == 0)
		p->hide_mage = 1;
	p->hide_mage += aura;

	wout(c->who, "Will appear common until the end of turn %d.",
				sysclock.turn + p->hide_mage - 1);

	return TRUE;
}


int
v_tap_health(struct command *c)
{

	return TRUE;
}


int
d_tap_health(struct command *c)
{
	struct char_magic *pm;
	int amount = c->a;
	int health = char_health(c->who);

	if (amount > health / 5)
		amount = health / 5;

	pm = p_magic(c->who);
	pm->cur_aura += amount;

	limit_cur_aura(c->who);

	wout(c->who, "Current aura is now %d.", pm->cur_aura);
	add_char_damage(c->who, amount * 5, MATES);

	return TRUE;
}
