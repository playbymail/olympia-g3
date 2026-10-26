
#include	<stdio.h>
#include	<string.h>
#include	"z.h"
#include	"oly.h"


/*
 *  Ultron coverage dump (issues #98 / #100).
 *
 *  coverage_path is set by main.c from the long-form "--coverage <path>"
 *  argument.  It is NULL by default, and then nothing is counted or
 *  written -- the golden manifests hash everything under libdir, so the
 *  dump must be strictly opt-in and land wherever the caller points it.
 *
 *  do_command() reports each command it dispatches with coverage_count().
 *  Only turn-runner commands count: immediate mode (-i, olyscript-g3)
 *  skips check_allow(), so its commands say nothing about the player
 *  order path Ultron exercises.  The outcome is taken at start time;
 *  finish/interrupt outcomes are not counted.
 *
 *  write_coverage() emits one row per cmd_tbl verb, sorted by name and
 *  including verbs that never fired, so the dump shows what a turn did
 *  NOT exercise.  Unrecognized commands have no verb and are counted on
 *  cmd_tbl[0] (the "" placeholder), written as "(unrecognized)".
 */

char *coverage_path = NULL;

static int (*cov_counts)[COV_MAX] = NULL;
static int cov_ncmds = 0;


static int
cov_num_cmds(void)
{
	int n = 0;

	while (cmd_tbl[n].name)
		n++;

	return n;
}


void
coverage_count(int cmd, int outcome)
{

	if (coverage_path == NULL || immediate)
		return;

	if (cov_counts == NULL)
	{
		cov_ncmds = cov_num_cmds();
		cov_counts = my_malloc(sizeof(*cov_counts) * (size_t) cov_ncmds);
	}

	if (cmd < 0 || cmd >= cov_ncmds)
		cmd = 0;

	assert(outcome >= 0 && outcome < COV_MAX);
	cov_counts[cmd][outcome]++;
}


static int
cov_name_comp(const void *a, const void *b)
{
	const int *x = a;
	const int *y = b;

	return strcmp(cmd_tbl[*x].name, cmd_tbl[*y].name);
}


void
write_coverage(void)
{
	FILE *fp;
	int *order;
	int n, i, cmd;

	if (coverage_path == NULL)
		return;

	fp = fopen(coverage_path, "w");
	if (fp == NULL) {
		fprintf(stderr, "Can't write %s!\n", coverage_path);
		return;
	}

	fprintf(fp, "verb\trejected\tunimplemented\tok\tfail\n");

	n = cov_num_cmds();
	order = my_malloc(sizeof(*order) * (size_t) n);
	for (i = 0; i < n; i++)
		order[i] = i;

	/* cmd_tbl names are unique, so this is a total order */
	safe_qsort(order, (size_t) n, sizeof(*order), cov_name_comp);

	for (i = 0; i < n; i++)
	{
		cmd = order[i];

		fprintf(fp, "%s\t%d\t%d\t%d\t%d\n",
			cmd == 0 ? "(unrecognized)" : cmd_tbl[cmd].name,
			cov_counts ? cov_counts[cmd][COV_REJECTED] : 0,
			cov_counts ? cov_counts[cmd][COV_UNIMPL] : 0,
			cov_counts ? cov_counts[cmd][COV_OK] : 0,
			cov_counts ? cov_counts[cmd][COV_FAIL] : 0);
	}

	my_free(order);
	fclose(fp);
}


/*
 *  Ultron use coverage dump (issue #181).
 *
 *  The verb dump counts every USE as one "use" row, whatever it
 *  dispatched.  use_coverage_path ("--use-coverage <path>") turns on a
 *  second dump, counted inside v_use() and v_use_item(): one row per
 *  use_tbl skill, one per item use key, and one "(invalid)" row for a
 *  target that is neither (not a box, not a usable skill or item, or a
 *  skill school).
 *
 *  UCOV_CHECKS counts a failed shared check (skill not known, school not
 *  known, magic in a safe haven, unmet requirements; for items: not held,
 *  safe haven), so it can't fill a skill's own fail cell.  Like the verb
 *  dump, outcomes are taken at start time, and immediate mode is skipped.
 *  Every USE the verb dump counts as ok or fail lands in exactly one row
 *  here.
 */

char *use_coverage_path = NULL;

static int (*ucov_skills)[UCOV_MAX] = NULL;	/* by use_tbl entry */
static int ucov_items[USE_KEY_MAX + 1][UCOV_MAX];	/* by use key; 0 = invalid */
static int ucov_nents = 0;

static char *use_key_names[USE_KEY_MAX + 1] = {
	"(invalid)",
	"death_potion",
	"heal_potion",
	"slave_potion",
	"palantir",
	"proj_cast",
	"quick_cast",
	"drum",
	"faery_stone",
	"orb",
	"barbarian_kill",
	"savage_kill",
	"corpse_kill",
	"orc_kill",
	"skeleton_kill",
	"bta_skull",
};


static int
ucov_num_ents(void)
{
	int n = 1;

	while (use_tbl_skill(n))
		n++;

	return n;
}


/*
 *  ent is a use_tbl index; ent <= 0 (no use_tbl entry) counts as invalid.
 */

void
use_coverage_skill(int ent, int outcome)
{

	if (use_coverage_path == NULL || immediate)
		return;

	assert(outcome >= 0 && outcome < UCOV_MAX);

	if (ucov_skills == NULL)
	{
		ucov_nents = ucov_num_ents();
		ucov_skills = my_malloc(sizeof(*ucov_skills) * (size_t) ucov_nents);
	}

	if (ent <= 0 || ent >= ucov_nents)
		ucov_items[0][outcome]++;
	else
		ucov_skills[ent][outcome]++;
}


/*
 *  key is an item use key; key 0 (not a usable item) counts as invalid.
 */

void
use_coverage_item(int key, int outcome)
{

	if (use_coverage_path == NULL || immediate)
		return;

	assert(outcome >= 0 && outcome < UCOV_MAX);

	if (key < 0 || key > USE_KEY_MAX)
		key = 0;

	ucov_items[key][outcome]++;
}


static int
ucov_skill_comp(const void *a, const void *b)
{
	const int *x = a;
	const int *y = b;

	return use_tbl_skill(*x) - use_tbl_skill(*y);
}


static void
ucov_row(FILE *fp, char *kind, int key, char *name, int *n)
{

	fprintf(fp, "%s\t%d\t%s\t%d\t%d\t%d\n", kind, key, name,
		n ? n[UCOV_CHECKS] : 0,
		n ? n[UCOV_OK] : 0,
		n ? n[UCOV_FAIL] : 0);
}


void
write_use_coverage(void)
{
	FILE *fp;
	int *order;
	int n, i, ent, sk;

	if (use_coverage_path == NULL)
		return;

	fp = fopen(use_coverage_path, "w");
	if (fp == NULL) {
		fprintf(stderr, "Can't write %s!\n", use_coverage_path);
		return;
	}

	fprintf(fp, "kind\tkey\tname\tchecks\tok\tfail\n");

	ucov_row(fp, "invalid", 0, use_key_names[0], ucov_items[0]);

	n = ucov_num_ents() - 1;
	order = my_malloc(sizeof(*order) * (size_t) (n > 0 ? n : 1));
	for (i = 0; i < n; i++)
		order[i] = i + 1;

	/* use_tbl skills are unique, so this is a total order */
	safe_qsort(order, (size_t) n, sizeof(*order), ucov_skill_comp);

	for (i = 0; i < n; i++)
	{
		ent = order[i];
		sk = use_tbl_skill(ent);

		ucov_row(fp, "skill", sk,
			kind(sk) == T_skill ? just_name(sk) : "",
			ucov_skills ? ucov_skills[ent] : NULL);
	}

	for (i = 1; i <= USE_KEY_MAX; i++)
		ucov_row(fp, "item", i, use_key_names[i], ucov_items[i]);

	my_free(order);
	fclose(fp);
}


/*
 *  Ultron phase coverage dump (issue #227).
 *
 *  The verb and use dumps only see commands.  A turn also runs work
 *  that no command starts: the day-0 NPC setup, day-1 trade matching,
 *  daily_events() and post_month().  phase_coverage_path
 *  ("--phase-coverage <path>") turns on a third dump with one row per
 *  thing such a routine can do, in turn execution order.
 *
 *  phase_ran() counts each call of a routine, on its first row.
 *  phase_acted() counts each time a routine did one of its things to an
 *  entity: healed a unit, collected a tax, spawned an NPC.  A routine
 *  that is called but finds nothing to do shows ran > 0, acted 0.
 *  Like the other dumps it counts only, draws nothing, and skips
 *  immediate mode.
 */

char *phase_coverage_path = NULL;

static struct {
	char *phase;
	char *routine;
	char *event;
} ph_rows[PH_MAX] = {
	[PH_SAVAGE_SPAWN] =	{ "day0", "init_savage_attacks", "spawn" },
	[PH_HADES_SPAWN] =	{ "day0", "auto_hades", "spawn" },
	[PH_HADES_UNIT] =	{ "day0", "auto_hades", "unit" },
	[PH_NPC_UNSWORN] =	{ "day0", "queue_npc_orders", "unsworn" },
	[PH_NPC_UNDEAD] =	{ "day0", "queue_npc_orders", "undead" },
	[PH_NPC_SAVAGE] =	{ "day0", "queue_npc_orders", "savage" },
	[PH_NPC_MOB] =		{ "day0", "queue_npc_orders", "mob" },
	[PH_NPC_BANDIT] =	{ "day0", "queue_npc_orders", "bandit" },
	[PH_NPC_TOKEN] =	{ "day0", "queue_npc_orders", "token" },
	[PH_GARR_GUARD] =	{ "day0", "ping_garrisons", "guard" },
	[PH_TOKEN_MELT] =	{ "day0", "check_token_units", "melt" },
	[PH_TOKEN_ADD] =	{ "day0", "check_token_units", "add" },
	[PH_STOP_INTERRUPT] =	{ "day0", "process_interrupted_units", "interrupt" },
	[PH_STOP_IDLE] =	{ "day0", "process_interrupted_units", "idle" },
	[PH_TRADE_MATCH] =	{ "day1", "match_all_trades", "trade" },
	[PH_GARR_PAY] =		{ "daily", "default_garrison_pay", "pay" },
	[PH_COAST_DAMAGE] =	{ "daily", "ship_coastal_damage", "damage" },
	[PH_COAST_OMEN] =	{ "daily", "ship_coastal_damage", "omen" },
	[PH_LOC_MINE] =		{ "daily", "random_loc_damage", "mine" },
	[PH_LOC_INN] =		{ "daily", "random_loc_damage", "inn" },
	[PH_OCEAN_PLUNGE] =	{ "daily", "check_ocean_chars", "plunge" },
	[PH_HEAL_HEAL] =	{ "daily", "heal_characters", "heal" },
	[PH_HEAL_SICKEN] =	{ "daily", "heal_characters", "sicken" },
	[PH_HEAL_RECOVER] =	{ "daily", "heal_characters", "recover" },
	[PH_PRISONER_ESCAPE] =	{ "daily", "weekly_prisoner_escape_check", "escape" },
	[PH_CURSE_ERODE] =	{ "daily", "noncreator_curse_erode", "erode" },
	[PH_RING_AURA] =	{ "daily", "increment_stone_ring_aura", "aura" },
	[PH_DOGS_BARK] =	{ "daily", "dogs_bark_at_hidden_chars", "bark" },
	[PH_WEATHER_STORM] =	{ "daily", "natural_weather", "storm" },
	[PH_FAERY_SPAWN] =	{ "daily", "auto_faery", "spawn" },
	[PH_FAERY_UNIT] =	{ "daily", "auto_faery", "unit" },
	[PH_SPECIAL_OPEN] =	{ "month", "special_locs_open", "open" },
	[PH_SPECIAL_CLOSE] =	{ "month", "special_locs_close", "close" },
	[PH_CITY_GOLD] =	{ "month", "move_city_gold", "move" },
	[PH_GARR_TAX] =		{ "month", "garrison_gold", "tax" },
	[PH_GARR_CASTLE] =	{ "month", "garrison_gold", "castle" },
	[PH_GARR_OWNER] =	{ "month", "garrison_gold", "owner" },
	[PH_TAXES] =		{ "month", "collect_taxes", "collect" },
	[PH_CLAIM] =		{ "month", "add_claim_gold", "grant" },
	[PH_NP] =		{ "month", "add_noble_points", "point" },
	[PH_UNFORMED] =		{ "month", "add_unformed", "mint" },
	[PH_AURA] =		{ "month", "increment_current_aura", "aura" },
	[PH_ABILITY_SHROUD] =	{ "month", "decrement_ability_shroud", "decrement" },
	[PH_REGION_SHROUD] =	{ "month", "decrement_region_shroud", "decrement" },
	[PH_MED_HINDER] =	{ "month", "decrement_meditation_hinder", "decrement" },
	[PH_BARRIER_DEC] =	{ "month", "decrement_loc_barrier", "decrement" },
	[PH_BARRIER_GONE] =	{ "month", "decrement_loc_barrier", "dissipate" },
	[PH_LOY_DECAY] =	{ "month", "loyalty_decay", "decay" },
	[PH_LOY_RELEASE] =	{ "month", "loyalty_decay", "release" },
	[PH_LOY_DESERT] =	{ "month", "loyalty_decay", "desert" },
	[PH_PILLAGE] =		{ "month", "pillage_decay", "decay" },
	[PH_RELIC_DECAY] =	{ "month", "relic_decay", "decay" },
	[PH_RELIC_VANISH] =	{ "month", "relic_decay", "vanish" },
	[PH_HIDE_MAGE] =	{ "month", "hide_mage_decay", "decrement" },
	[PH_INN_INCOME] =	{ "month", "inn_income", "income" },
	[PH_INN_TRAVELLER] =	{ "month", "inn_income", "traveller" },
	[PH_TEMPLE] =		{ "month", "temple_income", "offering" },
	[PH_MAINT_PAID] =	{ "month", "charge_maint_costs", "paid" },
	[PH_MAINT_STARVE] =	{ "month", "charge_maint_costs", "starve" },
	[PH_ANIMAL] =		{ "month", "animal_deaths", "death" },
	[PH_GHOST] =		{ "month", "ghost_warrior_decay", "evaporate" },
	[PH_CORPSE] =		{ "month", "corpse_decay", "decompose" },
	[PH_BODY] =		{ "month", "dead_body_rot", "rot" },
	[PH_STORM_WEAKEN] =	{ "month", "storm_decay", "weaken" },
	[PH_STORM_GONE] =	{ "month", "storm_decay", "dissipate" },
	[PH_STORM_MOVE] =	{ "month", "storm_move", "move" },
	[PH_MINE_DEC] =		{ "month", "collapsed_mine_decay", "decrement" },
	[PH_MINE_CLEAR] =	{ "month", "collapsed_mine_decay", "clear" },
	[PH_PRODUCTION] =	{ "month", "post_production", "run" },
	[PH_AUTO_DROP] =	{ "month", "auto_drop", "drop" },
	[PH_LINK_DEC] =		{ "month", "link_decay", "decrement" },
	[PH_LINK_OPEN] =	{ "month", "link_decay", "open" },
	[PH_QUEST] =		{ "month", "quest_decay", "decrement" },
	[PH_RANKS] =		{ "month", "determine_noble_ranks", "rank" },
};

static int ph_ran[PH_MAX];
static int ph_acted[PH_MAX];


/*
 *  row is the routine's first row.  check_token_units runs twice a
 *  turn (day 0 and month end), so its ran counts both.
 */

void
phase_ran(int row)
{

	if (phase_coverage_path == NULL || immediate)
		return;

	assert(row >= 0 && row < PH_MAX);
	ph_ran[row]++;
}


void
phase_acted(int row)
{

	if (phase_coverage_path == NULL || immediate)
		return;

	assert(row >= 0 && row < PH_MAX);
	ph_acted[row]++;
}


void
write_phase_coverage(void)
{
	FILE *fp;
	int i, first;

	if (phase_coverage_path == NULL)
		return;

	fp = fopen(phase_coverage_path, "w");
	if (fp == NULL) {
		fprintf(stderr, "Can't write %s!\n", phase_coverage_path);
		return;
	}

	fprintf(fp, "phase\troutine\tevent\tran\tacted\n");

	first = 0;
	for (i = 0; i < PH_MAX; i++)
	{
		assert(ph_rows[i].routine != NULL);

		if (strcmp(ph_rows[i].routine, ph_rows[first].routine) != 0)
			first = i;

		fprintf(fp, "%s\t%s\t%s\t%d\t%d\n",
			ph_rows[i].phase, ph_rows[i].routine, ph_rows[i].event,
			ph_ran[first], ph_acted[i]);
	}

	fclose(fp);
}
