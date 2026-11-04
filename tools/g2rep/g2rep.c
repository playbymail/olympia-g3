#define	_POSIX_C_SOURCE	200809L	/* getopt(), optind -- glibc hides them under -std=c11 (#336) */

/*
 *  g2rep -- render an Olympia report file as text or HTML.
 *
 *  A C11 port of the original g2rep (rep.c, from playbymail/olympia-tag-v0,
 *  g3/g2rep/rep.c; AGPL-3.0). The engine shells out to it to format player
 *  reports (send_rep(), -M), order confirmations (eat()) and HTML reports
 *  (setup_html_dir(), g2rep -h). Output must stay byte-identical to the
 *  original for well-formed input: tests/g2rep pins it against output
 *  produced by the original program. See tools/g2rep/README.md.
 *
 *  Input lines are written by bottom_out() in olympia/sout.c:
 *
 *	box-num:html:unit-num:indent::text
 *	box-num:html:unit-num:indent:day:text
 *	box-num:html:unit-num:indent/second-indent:day:text
 *	box-num:html:unit-num:indent/second-indent::text
 *
 *  Only the box-1 lines (the include section) are printed; an "#include N"
 *  line there prints every box-N line in its place.
 *
 *  Differences from the original, none of which change the output for input
 *  the engine writes:
 *	- an indent outside 0..150 is clamped (the original indexed outside
 *	  its 150-column space buffer);
 *	- a unit field longer than the 100-byte buffer is truncated (the
 *	  original overflowed it);
 *	- dehtml() stops at the end of a line that ends just after a '}'
 *	  with no newline (the original read past the terminator).
 */

#include	<stdio.h>
#include	<stdlib.h>
#include	<string.h>
#include	<unistd.h>

#define		iswhite(c)	((c) == ' ' || (c) == '\t')
#define		LEN		4096
#define		TRUE		1
#define		FALSE		0
#define		UNIT_LEN	100
#define		SPACES_LEN	150


static int indent;
static char unit[UNIT_LEN];
static int second_indent;
static int day;
static int html;

static int show_html = 1;


static void
output(char *s)
{
	char *p;

	for (p = s; *p; p++)
		if (*p == '~')
			*p = ' ';

	if (day >= 0)
		printf("%2d: %s%s\n", day, unit, s);
	else
		printf("%s%s\n", unit, s);
}


/*
 *  Word wrapper
 */

static char cur[LEN];
static int wrap_pos;
static int wrap_output;


/*
 *  The leading blanks for an n-column indent.
 */

static const char *
pad(int n)
{
	static char spaces[SPACES_LEN + 1];

	if (spaces[0] == '\0')
	{
		memset(spaces, ' ', SPACES_LEN);
		spaces[SPACES_LEN] = '\0';
	}

	if (n < 0)
		n = 0;
	if (n > SPACES_LEN)
		n = SPACES_LEN;

	return &spaces[SPACES_LEN - n];
}


/*
 *  To use:
 *	wrap_start();
 *	wrap(s, ...)			as many as needed
 *	wrap_done();
 */

static void
wrap_start(void)
{

	strcpy(cur, pad(indent));
	wrap_output = FALSE;
}


static void
wrap_done_sup(void)
{

	output(cur);
	strcpy(cur, pad(indent));
	wrap_output = TRUE;
}


static int
cur_has_something(void)
{
	char *p;

	for (p = cur; *p && iswhite(*p); p++)
		;

	if (*p)
		return TRUE;
	return FALSE;
}


static void
wrap_done(void)
{

	if (cur_has_something() || !wrap_output)
		wrap_done_sup();
}


static char *
word_split(char *s, int pos)
{
	int len;

	len = (int) strlen(s);
	if (pos >= len)
		return (&s[len]);

	while (pos > 0 && s[pos] != ' ')
		pos--;

	if (pos <= 0)
		return (NULL);

	s[pos] = '\0';

	return (&s[pos + 1]);
}


static void
wrap_append(char *s, const char *t)
{
	size_t slen;

	if (strcmp(t, "\"") != 0)
	{
		slen = strlen(s);

		if (slen > 0 && s[slen - 1] != ' ' && s[slen - 1] != '"')
		{
			strcat(s, " ");
			slen++;
		}

		if (slen > 1 &&
		    (s[slen - 2] == '.' || s[slen - 2] == ':' ||
		     s[slen - 2] == '?' || s[slen - 2] == '!'))
			strcat(s, " ");
	}

	strcat(s, t);
}


static void
wrap(char *s)
{
	char *t;
	int len;

	len = (int) strlen(cur);

	if ((int) strlen(s) + len < wrap_pos)
		wrap_append(cur, s);
	else
	{
		t = word_split(s, wrap_pos - len);
		if (t == NULL && cur_has_something())
		{
			wrap_done_sup();
			wrap(s);
		}
		else
		{
			wrap_append(cur, s);
			wrap_done_sup();
			if (t)
				wrap(t);
		}
	}
}


/*
 *  Parse the line's prefix into the globals and return the text.
 */

static char *
strip_stuff(char *s)
{
	char *p;

/*
 *  Pull off box number
 */

	while (*s && *s != ':')
		s++;
	if (*s == ':')
		s++;

/*
 *  Pull off html style tag
 */

	html = atoi(s);

	while (*s && *s != ':')
		s++;
	if (*s == ':')
		s++;

/*
 *  Pull off unit string, leaving room for ": " and the terminator
 */

	for (p = unit; *s && *s != ':'; s++)
		if (p < &unit[UNIT_LEN - 3])
			*p++ = *s;

	if (p > unit)
	{
		*p++ = ':';
		*p++ = ' ';
	}
	*p = '\0';

	if (*s == ':')
		s++;

/*
 *  Now get indentation:  %d or %d/%d
 */

	indent = atoi(s);

	while (*s && *s != ':' && *s != '/')
		s++;

	if (*s == '/')
	{
		s++;
		second_indent = atoi(s);
		while (*s && *s != ':')
			s++;
	}
	else
		second_indent = 0;

	if (*s == ':')
		s++;

/*
 *  Now get day, if any
 */

	if (*s == ':')
		day = -1;
	else
		day = atoi(s);

	while (*s && *s != ':')
		s++;

	if (*s == ':')
		s++;

	return s;
}


/*
 *   regular text { html text | non html text } regular text
 */

#define	LEFT	1
#define	RIGHT	2

static char *
dehtml(char *s)
{
	static char buf[LEN];
	char *bufp;
	char *p;
	int state = 0;

	bufp = buf;
	p = s;

	while (*p)
	{
		if (*p == '{')
		{
			state = LEFT;
			p++;
		}

		if (state == LEFT && *p == '|')
		{
			state = RIGHT;
			p++;
		}

		if (state && *p == '}')
		{
			state = 0;
			p++;
		}

		if (*p == '\0')
			break;

		if (state == 0 ||
		    (state == LEFT && show_html == 2) ||
		    (state == RIGHT && show_html == 1))
			*bufp++ = *p;
		p++;
	}

	*bufp = '\0';

	return buf;
}


static void
out_line(char *s)
{
	char *p;

	if (html != 0 && html != show_html)
		return;

	s = dehtml(s);

	for (p = s; *p && *p != '\n'; p++)
		;
	*p = '\0';

	if (html)
		wrap_pos = LEN;
	else if (day >= 0)
		wrap_pos = 72 - (int) strlen(unit);	/* left margin has 2d: on it */
	else
		wrap_pos = 76 - (int) strlen(unit);

	wrap_start();
	indent += second_indent;
	wrap(s);
	wrap_done();
	indent -= second_indent;
}


static void
print_by_num(FILE *fp, int num)
{
	char buf[LEN];
	long l;

	l = ftell(fp);
	rewind(fp);

	while (fgets(buf, LEN, fp) != NULL)
	{
		if (atoi(buf) == num)
			out_line(strip_stuff(buf));
	}

	fseek(fp, l, SEEK_SET);
}


static void
out_line_include(FILE *fp, char *s)
{

	if (strncmp(s, "#include ", 9) == 0)
		print_by_num(fp, atoi(&s[9]));
	else
		out_line(s);
}


static void
parse_includes(FILE *fp)
{
	char buf[LEN];

	while (fgets(buf, LEN, fp) != NULL)
	{
		if (atoi(buf) == 1)
			out_line_include(fp, strip_stuff(buf));
	}
}


int
main(int argc, char **argv)
{
	FILE *fp;
	int c;

	/*
	 *  The original counted unknown options but never acted on the
	 *  count; getopt() reports them, and the operand check below
	 *  decides the exit status.
	 */
	while ((c = getopt(argc, argv, "h")) != -1)
	{
		switch (c)
		{
		case 'h':
			show_html = 2;
			break;

		default:
			break;
		}
	}

	if (optind != argc - 1)
	{
		fprintf(stderr, "usage: %s [-h] report-file\n", argv[0]);
		exit(1);
	}

	fp = fopen(argv[optind], "r");
	if (fp == NULL)
	{
		fprintf(stderr, "can't read %s: ", argv[optind]);
		perror("");
		exit(1);
	}

	parse_includes(fp);
	fclose(fp);

	exit(0);
}
