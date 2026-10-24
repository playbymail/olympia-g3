
#include	<stdio.h>
#include	"z.h"
#include	"oly.h"


/*
 *  Ultron coverage dump (issues #98 / #100).
 *
 *  coverage_path is set by main.c from the long-form "--coverage <path>"
 *  argument.  It is NULL by default, and then nothing is written -- the
 *  golden manifests hash everything under libdir, so the dump must be
 *  strictly opt-in and land wherever the caller points it.
 *
 *  The per-verb counters from do_command() are added by #98; until then
 *  the file carries only its header row.
 */

char *coverage_path = NULL;

void
write_coverage(void)
{
	FILE *fp;

	if (coverage_path == NULL)
		return;

	fp = fopen(coverage_path, "w");
	if (fp == NULL) {
		fprintf(stderr, "Can't write %s!\n", coverage_path);
		return;
	}

	fprintf(fp, "verb\trejected\tunimplemented\tok\tfail\n");

	fclose(fp);
}
