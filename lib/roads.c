// Copyright (c) 2026 Michael D Henderson. All rights reserved.

//
// Created by Michael Henderson on 1/25/26.
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
 *  Reallocing array handler for struct road *
 *
 *  Layout: allocate an array of (struct road *) with 2 hidden slots at the front.
 *    - base[0] stores length (as int via memcpy)
 *    - base[1] stores capacity in total slots (as int via memcpy)
 *    - User-visible list is &base[2], so iterations proceed from index 0.
 *
 *  Uses standard malloc/calloc/realloc/free.
 */

static inline struct road **
roads_base(roads_list l)
{
    return l ? (l - 2) : NULL;
}

static inline int
roads_get_len(struct road **base)
{
    int v = 0;
    memcpy(&v, &base[0], sizeof v);
    return v;
}

static inline void
roads_set_len(struct road **base, int v)
{
    memset(&base[0], 0, sizeof base[0]);
    memcpy(&base[0], &v, sizeof v);
}

static inline int
roads_get_cap(struct road **base)
{
    int v = 0;
    memcpy(&v, &base[1], sizeof v);
    return v;
}

static inline void
roads_set_cap(struct road **base, int v)
{
    memset(&base[1], 0, sizeof base[1]);
    memcpy(&base[1], &v, sizeof v);
}

static struct road **
roads_alloc_block(int cap_total_slots)
{
    assert(cap_total_slots >= 3);
    struct road **base = calloc((size_t)cap_total_slots, sizeof *base);
    if (!base)
    {
        fprintf(stderr, "roads_alloc_block: out of memory\n");
        exit(1);
    }
    roads_set_len(base, 0);
    roads_set_cap(base, cap_total_slots);
    return base;
}

static void
roads_ensure_capacity(roads_list *l, int min_len_needed)
{
    int min_total = min_len_needed + 2;

    if (*l == NULL)
    {
        int cap = ILIST_ALLOC;
        if (cap < 3)
            cap = 3;
        while (cap <= min_total)
            cap *= 2;
        struct road **base = roads_alloc_block(cap);
        *l = &base[2];
        return;
    }

    struct road **base = roads_base(*l);
    int cap = roads_get_cap(base);

    if (cap > min_total)
        return;

    size_t old_bytes = (size_t)cap * sizeof *base;
    while (cap <= min_total)
        cap *= 2;

    base = realloc(base, (size_t)cap * sizeof *base);
    if (!base)
    {
        fprintf(stderr, "roads_ensure_capacity: out of memory\n");
        exit(1);
    }

    memset((char *)base + old_bytes, 0, (size_t)cap * sizeof *base - old_bytes);
    roads_set_cap(base, cap);
    *l = &base[2];
}


void
roads_append(roads_list *l, struct road *n)
{
    int len = roads_len(*l);
    roads_ensure_capacity(l, len + 1);

    struct road **base = roads_base(*l);
    base[2 + len] = n;
    roads_set_len(base, len + 1);
}


void
roads_clear(roads_list *l)
{
    if (*l)
        roads_set_len(roads_base(*l), 0);
}


roads_list
roads_copy(roads_list l)
{
    if (!l)
        return NULL;

    struct road **base = roads_base(l);
    int len = roads_get_len(base);
    int cap = roads_get_cap(base);

    struct road **copy = roads_alloc_block(cap);
    roads_set_len(copy, len);
    memcpy(&copy[2], &base[2], (size_t)len * sizeof *base);

    return &copy[2];
}


void
roads_delete(roads_list *l, int i)
{
    assert(*l != NULL);
    struct road **base = roads_base(*l);
    int len = roads_get_len(base);
    assert(i >= 0 && i < len);

    memmove(&base[2 + i], &base[2 + i + 1], (size_t)(len - i - 1) * sizeof *base);
    roads_set_len(base, len - 1);
}


int
roads_len(roads_list l)
{
    struct road **base = roads_base(l);
    return base ? roads_get_len(base) : 0;
}


int
roads_lookup(roads_list l, struct road *n)
{
    if (l == NULL)
        return -1;

    int len = roads_len(l);
    int i;
    for (i = 0; i < len; i++)
        if (l[i] == n)
            return i;

    return -1;
}


void
roads_prepend(roads_list *l, struct road *n)
{
    int len = roads_len(*l);
    roads_ensure_capacity(l, len + 1);

    struct road **base = roads_base(*l);
    memmove(&base[3], &base[2], (size_t)len * sizeof *base);
    base[2] = n;
    roads_set_len(base, len + 1);
}


void
roads_reclaim(roads_list *l)
{
    if (*l)
        free(roads_base(*l));
    *l = NULL;
}


void
roads_rem_value(roads_list *l, struct road *n)
{
    int i;
    for (i = 0; i < roads_len(*l); i++)
        if ((*l)[i] == n)
        {
            roads_delete(l, i);
            i--;
        }
}


void
roads_scramble(roads_list l)
{
    roads_shuffle(l);
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
roads_shuffle(roads_list l)
{
    int len = roads_len(l) - 1;
    int i;
    for (i = 0; i < len; i++)
    {
        int r = rnd(i, len);
        if (r != i)
        {
            struct road *tmp = l[i];
            l[i] = l[r];
            l[r] = tmp;
        }
    }
}


void
roads_test(void)
{
    roads_list l = NULL;
    roads_list c = NULL;
    int i;

    setbuf(stdout, NULL);
    printf("roads_test: starting\n");

    printf("roads_test: len of empty list = %d\n", roads_len(l));
    assert(roads_len(l) == 0);

    enum { N = 100 };
    struct road *items[N];
    for (i = 0; i < N; i++)
        items[i] = (struct road *)malloc(1);

    for (i = 0; i < N; i++)
        roads_append(&l, items[i]);

    printf("roads_test: after append, len = %d\n", roads_len(l));
    assert(roads_len(l) == N);

    for (i = 0; i < N; i++)
        assert(l[i] == items[i]);

    c = roads_copy(l);
    assert(roads_len(c) == N);
    for (i = 0; i < N; i++)
    {
        assert(&c[i] != &l[i]);
        assert(c[i] == l[i]);
    }
    printf("roads_test: copy verified\n");

    roads_delete(&l, 50);
    assert(roads_len(l) == N - 1);
    printf("roads_test: after delete, len = %d\n", roads_len(l));

    roads_prepend(&l, items[50]);
    assert(roads_len(l) == N);
    assert(l[0] == items[50]);
    printf("roads_test: after prepend, len = %d\n", roads_len(l));

    assert(roads_lookup(l, items[50]) == 0);
    printf("roads_test: lookup verified\n");

    roads_clear(&l);
    assert(roads_len(l) == 0);
    printf("roads_test: after clear, len = %d\n", roads_len(l));

    roads_reclaim(&l);
    roads_reclaim(&c);
    assert(l == NULL);
    assert(c == NULL);

    for (i = 0; i < N; i++)
        free(items[i]);

    printf("roads_test: all tests passed\n");
}
