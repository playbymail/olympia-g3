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
 *  Reallocing array handler for struct trade *
 *
 *  Layout: allocate an array of (struct trade *) with 2 hidden slots at the front.
 *    - base[0] stores length (as int via memcpy)
 *    - base[1] stores capacity in total slots (as int via memcpy)
 *    - User-visible list is &base[2], so iterations proceed from index 0.
 *
 *  Uses standard malloc/calloc/realloc/free.
 */

static inline struct trade **
trades_base(trades_list l)
{
    return l ? (l - 2) : NULL;
}

static inline int
trades_get_len(struct trade **base)
{
    int v = 0;
    memcpy(&v, &base[0], sizeof v);
    return v;
}

static inline void
trades_set_len(struct trade **base, int v)
{
    memset(&base[0], 0, sizeof base[0]);
    memcpy(&base[0], &v, sizeof v);
}

static inline int
trades_get_cap(struct trade **base)
{
    int v = 0;
    memcpy(&v, &base[1], sizeof v);
    return v;
}

static inline void
trades_set_cap(struct trade **base, int v)
{
    memset(&base[1], 0, sizeof base[1]);
    memcpy(&base[1], &v, sizeof v);
}

static struct trade **
trades_alloc_block(int cap_total_slots)
{
    assert(cap_total_slots >= 3);
    struct trade **base = calloc((size_t)cap_total_slots, sizeof *base);
    if (!base)
    {
        fprintf(stderr, "trades_alloc_block: out of memory\n");
        exit(1);
    }
    trades_set_len(base, 0);
    trades_set_cap(base, cap_total_slots);
    return base;
}

static void
trades_ensure_capacity(trades_list *l, int min_len_needed)
{
    int min_total = min_len_needed + 2;

    if (*l == NULL)
    {
        int cap = ILIST_ALLOC;
        if (cap < 3)
            cap = 3;
        while (cap <= min_total)
            cap *= 2;
        struct trade **base = trades_alloc_block(cap);
        *l = &base[2];
        return;
    }

    struct trade **base = trades_base(*l);
    int cap = trades_get_cap(base);

    if (cap > min_total)
        return;

    size_t old_bytes = (size_t)cap * sizeof *base;
    while (cap <= min_total)
        cap *= 2;

    base = realloc(base, (size_t)cap * sizeof *base);
    if (!base)
    {
        fprintf(stderr, "trades_ensure_capacity: out of memory\n");
        exit(1);
    }

    memset((char *)base + old_bytes, 0, (size_t)cap * sizeof *base - old_bytes);
    trades_set_cap(base, cap);
    *l = &base[2];
}


void
trades_append(trades_list *l, struct trade *n)
{
    int len = trades_len(*l);
    trades_ensure_capacity(l, len + 1);

    struct trade **base = trades_base(*l);
    base[2 + len] = n;
    trades_set_len(base, len + 1);
}


void
trades_clear(trades_list *l)
{
    if (*l)
        trades_set_len(trades_base(*l), 0);
}


trades_list
trades_copy(trades_list l)
{
    if (!l)
        return NULL;

    struct trade **base = trades_base(l);
    int len = trades_get_len(base);
    int cap = trades_get_cap(base);

    struct trade **copy = trades_alloc_block(cap);
    trades_set_len(copy, len);
    memcpy(&copy[2], &base[2], (size_t)len * sizeof *base);

    return &copy[2];
}


void
trades_delete(trades_list *l, int i)
{
    assert(*l != NULL);
    struct trade **base = trades_base(*l);
    int len = trades_get_len(base);
    assert(i >= 0 && i < len);

    memmove(&base[2 + i], &base[2 + i + 1], (size_t)(len - i - 1) * sizeof *base);
    trades_set_len(base, len - 1);
}


int
trades_len(trades_list l)
{
    struct trade **base = trades_base(l);
    return base ? trades_get_len(base) : 0;
}


int
trades_lookup(trades_list l, struct trade *n)
{
    if (l == NULL)
        return -1;

    int len = trades_len(l);
    int i;
    for (i = 0; i < len; i++)
        if (l[i] == n)
            return i;

    return -1;
}


void
trades_prepend(trades_list *l, struct trade *n)
{
    int len = trades_len(*l);
    trades_ensure_capacity(l, len + 1);

    struct trade **base = trades_base(*l);
    memmove(&base[3], &base[2], (size_t)len * sizeof *base);
    base[2] = n;
    trades_set_len(base, len + 1);
}


void
trades_reclaim(trades_list *l)
{
    if (*l)
        free(trades_base(*l));
    *l = NULL;
}


void
trades_rem_value(trades_list *l, struct trade *n)
{
    int i;
    for (i = 0; i < trades_len(*l); i++)
        if ((*l)[i] == n)
        {
            trades_delete(l, i);
            i--;
        }
}


void
trades_scramble(trades_list l)
{
    trades_shuffle(l);
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
trades_shuffle(trades_list l)
{
    int len = trades_len(l) - 1;
    int i;
    for (i = 0; i < len; i++)
    {
        int r = rnd(i, len);
        if (r != i)
        {
            struct trade *tmp = l[i];
            l[i] = l[r];
            l[r] = tmp;
        }
    }
}


void
trades_test(void)
{
    trades_list l = NULL;
    trades_list c = NULL;
    int i;

    setbuf(stdout, NULL);
    printf("trades_test: starting\n");

    printf("trades_test: len of empty list = %d\n", trades_len(l));
    assert(trades_len(l) == 0);

    enum { N = 100 };
    struct trade *items[N];
    for (i = 0; i < N; i++)
        items[i] = (struct trade *)malloc(1);

    for (i = 0; i < N; i++)
        trades_append(&l, items[i]);

    printf("trades_test: after append, len = %d\n", trades_len(l));
    assert(trades_len(l) == N);

    for (i = 0; i < N; i++)
        assert(l[i] == items[i]);

    c = trades_copy(l);
    assert(trades_len(c) == N);
    for (i = 0; i < N; i++)
    {
        assert(&c[i] != &l[i]);
        assert(c[i] == l[i]);
    }
    printf("trades_test: copy verified\n");

    trades_delete(&l, 50);
    assert(trades_len(l) == N - 1);
    printf("trades_test: after delete, len = %d\n", trades_len(l));

    trades_prepend(&l, items[50]);
    assert(trades_len(l) == N);
    assert(l[0] == items[50]);
    printf("trades_test: after prepend, len = %d\n", trades_len(l));

    assert(trades_lookup(l, items[50]) == 0);
    printf("trades_test: lookup verified\n");

    trades_clear(&l);
    assert(trades_len(l) == 0);
    printf("trades_test: after clear, len = %d\n", trades_len(l));

    trades_reclaim(&l);
    trades_reclaim(&c);
    assert(l == NULL);
    assert(c == NULL);

    for (i = 0; i < N; i++)
        free(items[i]);

    printf("trades_test: all tests passed\n");
}
