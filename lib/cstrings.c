// Copyright (c) 2026 Michael D Henderson. All rights reserved.

//
// Created by Michael Henderson on 1/26/26.
//


#include <assert.h>
#include <stddef.h>

#include "lists.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern void *my_malloc(unsigned size);
extern void *my_realloc(void *ptr, unsigned size);
extern int rnd(int low, int high);

#define FALSE (0)


/*
 *  Reallocing array handler for struct cstring *
 *
 *  Layout: allocate an array of (char **) with 2 hidden slots at the front.
 *    - base[0] stores length (as int via memcpy)
 *    - base[1] stores capacity in total slots (as int via memcpy)
 *    - User-visible list is &base[2], so iterations proceed from index 0.
 *
 *  Uses standard malloc/calloc/realloc/free.
 */

static inline char **
cstrings_base(cstrings_list l)
{
    return l ? (l - 2) : NULL;
}

static inline int
cstrings_get_len(char **base)
{
    int v = 0;
    memcpy(&v, &base[0], sizeof v);
    return v;
}

static inline void
cstrings_set_len(char **base, int v)
{
    memset(&base[0], 0, sizeof base[0]);
    memcpy(&base[0], &v, sizeof v);
}

static inline int
cstrings_get_cap(char **base)
{
    int v = 0;
    memcpy(&v, &base[1], sizeof v);
    return v;
}

static inline void
cstrings_set_cap(char **base, int v)
{
    memset(&base[1], 0, sizeof base[1]);
    memcpy(&base[1], &v, sizeof v);
}

static char **
cstrings_alloc_block(int cap_total_slots)
{
    assert(cap_total_slots >= 3);
    char **base = calloc((size_t)cap_total_slots, sizeof *base);
    if (!base)
    {
        fprintf(stderr, "cstrings_alloc_block: out of memory\n");
        exit(1);
    }
    cstrings_set_len(base, 0);
    cstrings_set_cap(base, cap_total_slots);
    return base;
}

static void
cstrings_ensure_capacity(cstrings_list *l, int min_len_needed)
{
    int min_total = min_len_needed + 2;

    if (*l == NULL)
    {
        int cap = ILIST_ALLOC;
        if (cap < 3)
            cap = 3;
        while (cap <= min_total)
            cap *= 2;
        char **base = cstrings_alloc_block(cap);
        *l = &base[2];
        return;
    }

    char **base = cstrings_base(*l);
    int cap = cstrings_get_cap(base);

    if (cap > min_total)
        return;

    size_t old_bytes = (size_t)cap * sizeof *base;
    while (cap <= min_total)
        cap *= 2;

    base = realloc(base, (size_t)cap * sizeof *base);
    if (!base)
    {
        fprintf(stderr, "cstrings_ensure_capacity: out of memory\n");
        exit(1);
    }

    memset((char *)base + old_bytes, 0, (size_t)cap * sizeof *base - old_bytes);
    cstrings_set_cap(base, cap);
    *l = &base[2];
}


void
cstrings_append(cstrings_list *l, char *n)
{
    int len = cstrings_len(*l);
    cstrings_ensure_capacity(l, len + 1);

    char **base = cstrings_base(*l);
    base[2 + len] = n;
    cstrings_set_len(base, len + 1);
}


void
cstrings_clear(cstrings_list *l)
{
    if (*l)
        cstrings_set_len(cstrings_base(*l), 0);
}


cstrings_list
cstrings_copy(cstrings_list l)
{
    if (!l)
        return NULL;

    char **base = cstrings_base(l);
    int len = cstrings_get_len(base);
    int cap = cstrings_get_cap(base);

    char **copy = cstrings_alloc_block(cap);
    cstrings_set_len(copy, len);
    memcpy(&copy[2], &base[2], (size_t)len * sizeof *base);

    return &copy[2];
}


void
cstrings_delete(cstrings_list *l, int i)
{
    assert(*l != NULL);
    char **base = cstrings_base(*l);
    int len = cstrings_get_len(base);
    assert(i >= 0 && i < len);

    memmove(&base[2 + i], &base[2 + i + 1], (size_t)(len - i - 1) * sizeof *base);
    cstrings_set_len(base, len - 1);
}


int
cstrings_len(cstrings_list l)
{
    char **base = cstrings_base(l);
    return base ? cstrings_get_len(base) : 0;
}


int
cstrings_lookup(cstrings_list l, char *n)
{
    if (l == NULL)
        return -1;

    int len = cstrings_len(l);
    int i;
    for (i = 0; i < len; i++)
        if (l[i] == n)
            return i;

    return -1;
}


void
cstrings_prepend(cstrings_list *l, char *n)
{
    int len = cstrings_len(*l);
    cstrings_ensure_capacity(l, len + 1);

    char **base = cstrings_base(*l);
    memmove(&base[3], &base[2], (size_t)len * sizeof *base);
    base[2] = n;
    cstrings_set_len(base, len + 1);
}


void
cstrings_reclaim(cstrings_list *l)
{
    if (*l)
        free(cstrings_base(*l));
    *l = NULL;
}


void
cstrings_rem_value(cstrings_list *l, char *n)
{
    int i;
    for (i = 0; i < cstrings_len(*l); i++)
        if ((*l)[i] == n)
        {
            cstrings_delete(l, i);
            i--;
        }
}


void
cstrings_scramble(cstrings_list l)
{
    cstrings_shuffle(l);
}


/*
 *  Knuth, The Art of Computer Programming, Vol. 2 (Addison Wesley).
 *  Essentially, to shuffle A[1]...A[N]:
 *  1) put I = 1;
 *  2) generate a random number R in the range I..N;
 *  3) if R is not I, swap A[R] and A[I];
 *  4) I <- I+1;
 *  5) if I is less than N go to step 2
 */

void
cstrings_shuffle(cstrings_list l)
{
    int len = cstrings_len(l) - 1;
    int i;
    for (i = 0; i < len; i++)
    {
        int r = rnd(i, len);
        if (r != i)
        {
            char *tmp = l[i];
            l[i] = l[r];
            l[r] = tmp;
        }
    }
}


void
cstrings_test(void)
{
    cstrings_list l = NULL;
    cstrings_list c = NULL;
    int i;

    setbuf(stdout, NULL);
    printf("cstrings_test: starting\n");

    printf("cstrings_test: len of empty list = %d\n", cstrings_len(l));
    assert(cstrings_len(l) == 0);

    enum { N = 100 };
    char *items[N];
    for (i = 0; i < N; i++)
        items[i] = (char *)malloc(1);

    for (i = 0; i < N; i++)
        cstrings_append(&l, items[i]);

    printf("cstrings_test: after append, len = %d\n", cstrings_len(l));
    assert(cstrings_len(l) == N);

    for (i = 0; i < N; i++)
        assert(l[i] == items[i]);

    c = cstrings_copy(l);
    assert(cstrings_len(c) == N);
    for (i = 0; i < N; i++)
    {
        assert(&c[i] != &l[i]);
        assert(c[i] == l[i]);
    }
    printf("cstrings_test: copy verified\n");

    cstrings_delete(&l, 50);
    assert(cstrings_len(l) == N - 1);
    printf("cstrings_test: after delete, len = %d\n", cstrings_len(l));

    cstrings_prepend(&l, items[50]);
    assert(cstrings_len(l) == N);
    assert(l[0] == items[50]);
    printf("cstrings_test: after prepend, len = %d\n", cstrings_len(l));

    assert(cstrings_lookup(l, items[50]) == 0);
    printf("cstrings_test: lookup verified\n");

    cstrings_clear(&l);
    assert(cstrings_len(l) == 0);
    printf("cstrings_test: after clear, len = %d\n", cstrings_len(l));

    cstrings_reclaim(&l);
    cstrings_reclaim(&c);
    assert(l == NULL);
    assert(c == NULL);

    for (i = 0; i < N; i++)
        free(items[i]);

    printf("cstrings_test: all tests passed\n");
}
