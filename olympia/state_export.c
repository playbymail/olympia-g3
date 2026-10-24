
#include	<stdio.h>
#include	"z.h"
#include	"oly.h"


/*
 *  Ultron state export (issue #104).
 *
 *  state_export_path is set by main.c from the long-form
 *  "--state-export <path>" argument.  It is NULL by default, and then
 *  nothing is written.  When set, write_state_export() writes a JSON
 *  snapshot of what each regular player faction can act on, for the
 *  out-of-process Ultron brain to pick orders from.
 *
 *  main() calls it after save_db(), so nothing it touches can reach the
 *  saved database.  It only reads, and draws no random numbers.  Every
 *  list is written in entity-id order, so the export is deterministic.
 *
 *  The format is the contract (doc/ultron-harness-architecture.md):
 *
 *	{ "turn": N, "factions": [ {
 *		"id", "name",
 *		"units": [ { "id", "name", "where", "stacked_under",
 *			"items": [ { "id", "name", "qty" } ],
 *			"skills": [ { "id", "name" } ] } ],
 *		"locations": [ { "id", "name", "kind", "subkind", "depth",
 *			"province",
 *			"exits": [ { "direction", "destination", "distance",
 *				"road", "impassable", "hidden" } ],
 *			"here": [ { "id", "name", "faction" } ] } ] } ] }
 *
 *  "where" is the unit's immediate location or ship (subloc()), and
 *  "stacked_under" is 0 for a unit that leads its own stack.  Exits are
 *  the ones the faction can see from that location, taken as its
 *  lowest-numbered unit there sees them; exits hidden from that unit are
 *  left out, and "hidden" marks a known hidden destination.
 */

char *state_export_path = NULL;


/*
 *  Write s as a JSON string.  Names are 8-bit, so bytes outside
 *  printable ASCII are written as \u00XX (read as Latin-1), which
 *  keeps the file valid UTF-8 whatever the database holds.
 */

static void
json_str(FILE *fp, char *s)
{
	unsigned char *p;

	fputc('"', fp);

	for (p = (unsigned char *) s; p && *p; p++)
	{
		if (*p == '"' || *p == '\\')
			fprintf(fp, "\\%c", *p);
		else if (*p < 0x20 || *p >= 0x7f)
			fprintf(fp, "\\u%04x", *p);
		else
			fputc(*p, fp);
	}

	fputc('"', fp);
}


static void
sort_ids(ilist l)
{

	safe_qsort(l, (size_t) ilist_len(l), sizeof(int), int_comp);
}


static void
export_unit(FILE *fp, int who)
{
	struct item_ent *e;
	struct skill_ent *s;
	ilist items = NULL;
	ilist skills = NULL;
	int i;

	fprintf(fp, "{\"id\": %d, \"name\": ", who);
	json_str(fp, name(who));
	fprintf(fp, ", \"where\": %d, \"stacked_under\": %d",
		subloc(who), stack_parent(who));

	loop_inv(who, e)
	{
		ilist_append(&items, e->item);
	}
	next_inv;

	sort_ids(items);

	fprintf(fp, ",\n      \"items\": [");
	for (i = 0; i < ilist_len(items); i++)
	{
		fprintf(fp, "%s{\"id\": %d, \"name\": ", i ? ", " : "",
			items[i]);
		json_str(fp, name(items[i]));
		fprintf(fp, ", \"qty\": %d}", has_item(who, items[i]));
	}
	fprintf(fp, "]");

	loop_char_skill_known(who, s)
	{
		ilist_append(&skills, s->skill);
	}
	next_char_skill_known;

	sort_ids(skills);

	fprintf(fp, ",\n      \"skills\": [");
	for (i = 0; i < ilist_len(skills); i++)
	{
		fprintf(fp, "%s{\"id\": %d, \"name\": ", i ? ", " : "",
			skills[i]);
		json_str(fp, name(skills[i]));
		fprintf(fp, "}");
	}
	fprintf(fp, "]}");

	ilist_reclaim(&items);
	ilist_reclaim(&skills);
}


static void
export_location(FILE *fp, int where, int viewer)
{
	exit_views_list l;
	ilist here = NULL;
	int i, n, c;

	fprintf(fp, "{\"id\": %d, \"name\": ", where);
	json_str(fp, name(where));
	fprintf(fp, ", \"kind\": ");
	json_str(fp, kind_s[kind(where)]);
	fprintf(fp, ", \"subkind\": ");
	json_str(fp, subkind_s[subkind(where)]);
	fprintf(fp, ", \"depth\": ");
	json_str(fp, kind(where) == T_loc ? loc_depth_s[loc_depth(where)] : "");
	fprintf(fp, ", \"province\": %d", province(where));

	fprintf(fp, ",\n      \"exits\": [");
	n = 0;
	if (kind(where) == T_loc)
	{
		l = exits_from_loc(viewer, where);

		for (i = 0; i < exit_views_len(l); i++)
		{
			if (l[i]->hidden)
				continue;

			fprintf(fp, "%s{\"direction\": ", n++ ? ", " : "");
			json_str(fp, l[i]->road ? "road" :
					full_dir_s[l[i]->direction]);
			fprintf(fp, ", \"destination\": %d, \"distance\": %d, "
				"\"road\": %d, \"impassable\": %d, "
				"\"hidden\": %d}",
				l[i]->destination, l[i]->distance,
				l[i]->road, l[i]->impassable,
				l[i]->dest_hidden ? 1 : 0);
		}
	}
	fprintf(fp, "]");

	all_char_here(where, &here);
	sort_ids(here);

	fprintf(fp, ",\n      \"here\": [");
	for (i = 0; i < ilist_len(here); i++)
	{
		c = here[i];

		fprintf(fp, "%s{\"id\": %d, \"name\": ", i ? ", " : "", c);
		json_str(fp, name(c));
		fprintf(fp, ", \"faction\": %d}", player(c));
	}
	fprintf(fp, "]}");

	ilist_reclaim(&here);
}


static void
export_faction(FILE *fp, int pl)
{
	ilist units = NULL;
	ilist wheres = NULL;
	ilist viewers = NULL;
	int i, j, who, where;

	loop_units(pl, who)
	{
		ilist_append(&units, who);
	}
	next_unit;

	sort_ids(units);

	fprintf(fp, "{\"id\": %d, \"name\": ", pl);
	json_str(fp, name(pl));

	fprintf(fp, ",\n   \"units\": [");
	for (i = 0; i < ilist_len(units); i++)
	{
		fprintf(fp, "%s\n     ", i ? "," : "");
		export_unit(fp, units[i]);
	}
	fprintf(fp, "]");

/*
 *  The faction's locations, each with the lowest-numbered unit
 *  there as the viewer whose exits are reported.  units is sorted,
 *  so the first unit found at a location is that unit.
 */

	for (i = 0; i < ilist_len(units); i++)
	{
		where = subloc(units[i]);
		if (where > 0 && ilist_lookup(wheres, where) < 0)
			ilist_append(&wheres, where);
	}

	sort_ids(wheres);

	for (i = 0; i < ilist_len(wheres); i++)
		for (j = 0; j < ilist_len(units); j++)
			if (subloc(units[j]) == wheres[i])
			{
				ilist_append(&viewers, units[j]);
				break;
			}

	fprintf(fp, ",\n   \"locations\": [");
	for (i = 0; i < ilist_len(wheres); i++)
	{
		fprintf(fp, "%s\n     ", i ? "," : "");
		export_location(fp, wheres[i], viewers[i]);
	}
	fprintf(fp, "]}");

	ilist_reclaim(&units);
	ilist_reclaim(&wheres);
	ilist_reclaim(&viewers);
}


void
write_state_export(void)
{
	FILE *fp;
	ilist factions = NULL;
	int pl, i;

	if (state_export_path == NULL)
		return;

	fp = fopen(state_export_path, "w");
	if (fp == NULL) {
		fprintf(stderr, "Can't write %s!\n", state_export_path);
		return;
	}

	loop_pl_regular(pl)
	{
		ilist_append(&factions, pl);
	}
	next_pl_regular;

	sort_ids(factions);

	fprintf(fp, "{\"turn\": %d, \"factions\": [", sysclock.turn);
	for (i = 0; i < ilist_len(factions); i++)
	{
		fprintf(fp, "%s\n  ", i ? "," : "");
		export_faction(fp, factions[i]);
	}
	fprintf(fp, "]}\n");

	ilist_reclaim(&factions);
	fclose(fp);
}
