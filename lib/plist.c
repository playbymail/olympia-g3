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
 *  Reallocing array handler for plist
 *
 *  Layout: allocate an array of (void *) with 2 hidden slots at the front.
 *    - base[0] stores length (as int via memcpy)
 *    - base[1] stores capacity in total slots (as int via memcpy)
 *    - User-visible list is &base[2], so iterations proceed from index 0.
 *
 *  Uses standard malloc/calloc/realloc/free.
 */

static inline void **
plist_base(plist l)
{
    return l ? (l - 2) : NULL;
}

static inline int
plist_get_len(void **base)
{
    int v = 0;
    memcpy(&v, &base[0], sizeof v);
    return v;
}

static inline void
plist_set_len(void **base, int v)
{
    memset(&base[0], 0, sizeof base[0]);
    memcpy(&base[0], &v, sizeof v);
}

static inline int
plist_get_cap(void **base)
{
    int v = 0;
    memcpy(&v, &base[1], sizeof v);
    return v;
}

static inline void
plist_set_cap(void **base, int v)
{
    memset(&base[1], 0, sizeof base[1]);
    memcpy(&base[1], &v, sizeof v);
}

static void **
plist_alloc_block(int cap_total_slots)
{
    assert(cap_total_slots >= 3);
    void **base = calloc((size_t)cap_total_slots, sizeof *base);
    if (!base)
    {
        fprintf(stderr, "plist_alloc_block: out of memory\n");
        exit(1);
    }
    plist_set_len(base, 0);
    plist_set_cap(base, cap_total_slots);
    return base;
}

static void
plist_ensure_capacity(plist *l, int min_len_needed)
{
    int min_total = min_len_needed + 2;

    if (*l == NULL)
    {
        int cap = ILIST_ALLOC;
        if (cap < 3)
            cap = 3;
        while (cap <= min_total)
            cap *= 2;
        void **base = plist_alloc_block(cap);
        *l = &base[2];
        return;
    }

    void **base = plist_base(*l);
    int cap = plist_get_cap(base);

    if (cap > min_total)
        return;

    size_t old_bytes = (size_t)cap * sizeof *base;
    while (cap <= min_total)
        cap *= 2;

    base = realloc(base, (size_t)cap * sizeof *base);
    if (!base)
    {
        fprintf(stderr, "plist_ensure_capacity: out of memory\n");
        exit(1);
    }

    memset((char *)base + old_bytes, 0, (size_t)cap * sizeof *base - old_bytes);
    plist_set_cap(base, cap);
    *l = &base[2];
}


void
plist_append(plist *l, void *n)
{
    int len = plist_len(*l);
    plist_ensure_capacity(l, len + 1);

    void **base = plist_base(*l);
    base[2 + len] = n;
    plist_set_len(base, len + 1);
}


void
plist_clear(plist *l)
{
    if (*l)
        plist_set_len(plist_base(*l), 0);
}


plist
plist_copy(plist l)
{
    if (!l)
        return NULL;

    void **base = plist_base(l);
    int len = plist_get_len(base);
    int cap = plist_get_cap(base);

    void **copy = plist_alloc_block(cap);
    plist_set_len(copy, len);
    memcpy(&copy[2], &base[2], (size_t)len * sizeof *base);

    return &copy[2];
}


void
plist_delete(plist *l, int i)
{
    assert(*l != NULL);
    void **base = plist_base(*l);
    int len = plist_get_len(base);
    assert(i >= 0 && i < len);

    memmove(&base[2 + i], &base[2 + i + 1], (size_t)(len - i - 1) * sizeof *base);
    plist_set_len(base, len - 1);
}


int
plist_len(plist l)
{
    void **base = plist_base(l);
    return base ? plist_get_len(base) : 0;
}


int
plist_lookup(plist l, void *n)
{
    if (l == NULL)
        return -1;

    int len = plist_len(l);
    int i;
    for (i = 0; i < len; i++)
        if (l[i] == n)
            return i;

    return -1;
}


void
plist_prepend(plist *l, void *n)
{
    int len = plist_len(*l);
    plist_ensure_capacity(l, len + 1);

    void **base = plist_base(*l);
    memmove(&base[3], &base[2], (size_t)len * sizeof *base);
    base[2] = n;
    plist_set_len(base, len + 1);
}


void
plist_reclaim(plist *l)
{
    if (*l)
        free(plist_base(*l));
    *l = NULL;
}


void
plist_rem_value(plist *l, void *n)
{
    int i;
    for (i = 0; i < plist_len(*l); i++)
        if ((*l)[i] == n)
        {
            plist_delete(l, i);
            i--;
        }
}


void
plist_scramble(plist l)
{
    plist_shuffle(l);
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
plist_shuffle(plist l)
{
    int len = plist_len(l) - 1;
    int i;
    for (i = 0; i < len; i++)
    {
        int r = rnd(i, len);
        if (r != i)
        {
            void *tmp = l[i];
            l[i] = l[r];
            l[r] = tmp;
        }
    }
}


void
plist_test(void)
{
    plist l = NULL;
    plist c = NULL;
    int i;

    setbuf(stdout, NULL);
    printf("plist_test: starting\n");

    printf("plist_test: len of empty list = %d\n", plist_len(l));
    assert(plist_len(l) == 0);

    enum { N = 100 };
    void *items[N];
    for (i = 0; i < N; i++)
        items[i] = (void *)malloc(1);

    for (i = 0; i < N; i++)
        plist_append(&l, items[i]);

    printf("plist_test: after append, len = %d\n", plist_len(l));
    assert(plist_len(l) == N);

    for (i = 0; i < N; i++)
        assert(l[i] == items[i]);

    c = plist_copy(l);
    assert(plist_len(c) == N);
    for (i = 0; i < N; i++)
    {
        assert(&c[i] != &l[i]);
        assert(c[i] == l[i]);
    }
    printf("plist_test: copy verified\n");

    plist_delete(&l, 50);
    assert(plist_len(l) == N - 1);
    printf("plist_test: after delete, len = %d\n", plist_len(l));

    plist_prepend(&l, items[50]);
    assert(plist_len(l) == N);
    assert(l[0] == items[50]);
    printf("plist_test: after prepend, len = %d\n", plist_len(l));

    assert(plist_lookup(l, items[50]) == 0);
    printf("plist_test: lookup verified\n");

    plist_clear(&l);
    assert(plist_len(l) == 0);
    printf("plist_test: after clear, len = %d\n", plist_len(l));

    plist_reclaim(&l);
    plist_reclaim(&c);
    assert(l == NULL);
    assert(c == NULL);

    for (i = 0; i < N; i++)
        free(items[i]);

    printf("plist_test: all tests passed\n");
}
