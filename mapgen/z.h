/*
 *  Real libc prototypes (Phase 4 modernization).  Included first, above the
 *  engine's abs()/char-class shadow macros below, so the system declarations
 *  are seen before the macros redefine those names.  Gives 64-bit-correct
 *  prototypes for the libc functions the map generator calls implicitly.
 */
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <fcntl.h>

#include "../lib/checked_alloc.h"	/* shared my_malloc/my_realloc/my_free seam */
#include "../lib/rnd.h"		/* shared MD5 RNG (lib/rnd.c) */

#define	TRUE	1
#define	FALSE	0

#define		LEN		2048	/* generic string max length */

#define	abs(n)		((n) < 0 ? ((n) * -1) : (n))

#define	isalpha(c)	(((c)>='a' && (c)<='z') || ((c)>='A' && (c)<='Z'))
#define	isdigit(c)	((c) >= '0' && (c) <= '9')
#define	iswhite(c)	((c) == ' ' || (c) == '\t')

#if 1
#define	tolower(c)	(lower_array[c])
extern char lower_array[];
#else
#define	tolower(c)	(((c) >= 'A' && (c) <= 'Z') ? ((c) - 'A' + 'a') : (c))
#endif

#define	toupper(c)	(((c) >= 'a' && (c) <= 'z') ? ((c) - 'a' + 'A') : (c))

extern char *str_save(char *);

extern char *getlin(FILE *);
extern char *getlin_ew(FILE *);
extern int i_strncmp(char *s, char *t, int n);
extern int i_strcmp(char *s, char *t);
extern int fuzzy_strcmp(char *, char *);

/*
 *  Assertion verifier
 */

extern void asfail(char *file, int line, char *cond);

#ifdef __STDC__
#define	assert(p)	if(!(p)) asfail(__FILE__, __LINE__, #p);
#else
#define	assert(p)	if(!(p)) asfail(__FILE__, __LINE__, "p");
#endif


extern int readfile(char *path);
extern char *readlin(void);
extern char *readlin_ew(void);
extern char *eat_leading_trailing_whitespace(char *s);

/* z.c functions that don't reach mapgen's proto.h */
extern void closefile(char *path);
extern void copy_fp(FILE *a, FILE *b);
extern void init_lower(void);
extern void lcase(char *s);
extern void test_random(void);

extern int int_comp(void * a, void * b);
