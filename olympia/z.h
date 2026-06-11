/* BUGFIX (modernization): use varargs and forward declarations */
#include "legacy.h"
/* BUGFIX (modernization): update lists to use 64-bit pointers */
#include "../lib/lists.h"
/* BUGFIX (modernization): use an updated malloc/realloc/free */
#include "../lib/checked_alloc.h"

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
extern int rnd(int low, int high);

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
extern char *readlin();
extern char *readlin_ew();
extern char *eat_leading_trailing_whitespace(char *s);

extern int int_comp(void * a, void * b);
