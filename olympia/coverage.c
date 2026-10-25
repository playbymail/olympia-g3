
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
