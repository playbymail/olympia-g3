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
 *  Reallocing array handler for struct tile *
 *
 *  Layout: allocate an array of (struct tile *) with 2 hidden slots at the front.
 *    - base[0] stores length (as int via memcpy)
 *    - base[1] stores capacity in total slots (as int via memcpy)
 *    - User-visible list is &base[2], so iterations proceed from index 0.
 *
 *  Uses standard malloc/calloc/realloc/free.
 */

static inline struct tile **
tiles_base(tiles_list l)
{
    return l ? (l - 2) : NULL;
}

static inline int
tiles_get_len(struct tile **base)
{
    int v = 0;
    memcpy(&v, &base[0], sizeof v);
    return v;
}

static inline void
tiles_set_len(struct tile **base, int v)
{
    memset(&base[0], 0, sizeof base[0]);
    memcpy(&base[0], &v, sizeof v);
}

static inline int
tiles_get_cap(struct tile **base)
{
    int v = 0;
    memcpy(&v, &base[1], sizeof v);
    return v;
}

static inline void
tiles_set_cap(struct tile **base, int v)
{
    memset(&base[1], 0, sizeof base[1]);
    memcpy(&base[1], &v, sizeof v);
}

static struct tile **
tiles_alloc_block(int cap_total_slots)
{
    assert(cap_total_slots >= 3);
    struct tile **base = calloc((size_t)cap_total_slots, sizeof *base);
    if (!base)
    {
        fprintf(stderr, "tiles_alloc_block: out of memory\n");
        exit(1);
    }
    tiles_set_len(base, 0);
    tiles_set_cap(base, cap_total_slots);
    return base;
}

static void
tiles_ensure_capacity(tiles_list *l, int min_len_needed)
{
    int min_total = min_len_needed + 2;

    if (*l == NULL)
    {
        int cap = ILIST_ALLOC;
        if (cap < 3)
            cap = 3;
        while (cap <= min_total)
            cap *= 2;
        struct tile **base = tiles_alloc_block(cap);
        *l = &base[2];
        return;
    }

    struct tile **base = tiles_base(*l);
    int cap = tiles_get_cap(base);

    if (cap > min_total)
        return;

    size_t old_bytes = (size_t)cap * sizeof *base;
    while (cap <= min_total)
        cap *= 2;

    base = realloc(base, (size_t)cap * sizeof *base);
    if (!base)
    {
        fprintf(stderr, "tiles_ensure_capacity: out of memory\n");
        exit(1);
    }

    memset((char *)base + old_bytes, 0, (size_t)cap * sizeof *base - old_bytes);
    tiles_set_cap(base, cap);
    *l = &base[2];
}


void
tiles_append(tiles_list *l, struct tile *n)
{
    int len = tiles_len(*l);
    tiles_ensure_capacity(l, len + 1);

    struct tile **base = tiles_base(*l);
    base[2 + len] = n;
    tiles_set_len(base, len + 1);
}


void
tiles_clear(tiles_list *l)
{
    if (*l)
        tiles_set_len(tiles_base(*l), 0);
}


tiles_list
tiles_copy(tiles_list l)
{
    if (!l)
        return NULL;

    struct tile **base = tiles_base(l);
    int len = tiles_get_len(base);
    int cap = tiles_get_cap(base);

    struct tile **copy = tiles_alloc_block(cap);
    tiles_set_len(copy, len);
    memcpy(&copy[2], &base[2], (size_t)len * sizeof *base);

    return &copy[2];
}


void
tiles_delete(tiles_list *l, int i)
{
    assert(*l != NULL);
    struct tile **base = tiles_base(*l);
    int len = tiles_get_len(base);
    assert(i >= 0 && i < len);

    memmove(&base[2 + i], &base[2 + i + 1], (size_t)(len - i - 1) * sizeof *base);
    tiles_set_len(base, len - 1);
}


int
tiles_len(tiles_list l)
{
    struct tile **base = tiles_base(l);
    return base ? tiles_get_len(base) : 0;
}


int
tiles_lookup(tiles_list l, struct tile *n)
{
    if (l == NULL)
        return -1;

    int len = tiles_len(l);
    int i;
    for (i = 0; i < len; i++)
        if (l[i] == n)
            return i;

    return -1;
}


void
tiles_prepend(tiles_list *l, struct tile *n)
{
    int len = tiles_len(*l);
    tiles_ensure_capacity(l, len + 1);

    struct tile **base = tiles_base(*l);
    memmove(&base[3], &base[2], (size_t)len * sizeof *base);
    base[2] = n;
    tiles_set_len(base, len + 1);
}


void
tiles_reclaim(tiles_list *l)
{
    if (*l)
        free(tiles_base(*l));
    *l = NULL;
}


void
tiles_rem_value(tiles_list *l, struct tile *n)
{
    int i;
    for (i = 0; i < tiles_len(*l); i++)
        if ((*l)[i] == n)
        {
            tiles_delete(l, i);
            i--;
        }
}


void
tiles_scramble(tiles_list l)
{
    tiles_shuffle(l);
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
tiles_shuffle(tiles_list l)
{
    int len = tiles_len(l) - 1;
    int i;
    for (i = 0; i < len; i++)
    {
        int r = rnd(i, len);
        if (r != i)
        {
            struct tile *tmp = l[i];
            l[i] = l[r];
            l[r] = tmp;
        }
    }
}


void
tiles_test(void)
{
    tiles_list l = NULL;
    tiles_list c = NULL;
    int i;

    setbuf(stdout, NULL);
    printf("tiles_test: starting\n");

    printf("tiles_test: len of empty list = %d\n", tiles_len(l));
    assert(tiles_len(l) == 0);

    enum { N = 100 };
    struct tile *items[N];
    for (i = 0; i < N; i++)
        items[i] = (struct tile *)malloc(1);

    for (i = 0; i < N; i++)
        tiles_append(&l, items[i]);

    printf("tiles_test: after append, len = %d\n", tiles_len(l));
    assert(tiles_len(l) == N);

    for (i = 0; i < N; i++)
        assert(l[i] == items[i]);

    c = tiles_copy(l);
    assert(tiles_len(c) == N);
    for (i = 0; i < N; i++)
    {
        assert(&c[i] != &l[i]);
        assert(c[i] == l[i]);
    }
    printf("tiles_test: copy verified\n");

    tiles_delete(&l, 50);
    assert(tiles_len(l) == N - 1);
    printf("tiles_test: after delete, len = %d\n", tiles_len(l));

    tiles_prepend(&l, items[50]);
    assert(tiles_len(l) == N);
    assert(l[0] == items[50]);
    printf("tiles_test: after prepend, len = %d\n", tiles_len(l));

    assert(tiles_lookup(l, items[50]) == 0);
    printf("tiles_test: lookup verified\n");

    tiles_clear(&l);
    assert(tiles_len(l) == 0);
    printf("tiles_test: after clear, len = %d\n", tiles_len(l));

    tiles_reclaim(&l);
    tiles_reclaim(&c);
    assert(l == NULL);
    assert(c == NULL);

    for (i = 0; i < N; i++)
        free(items[i]);

    printf("tiles_test: all tests passed\n");
}
