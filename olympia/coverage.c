
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
