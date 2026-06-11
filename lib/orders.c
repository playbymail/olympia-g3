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
 *  Reallocing array handler for struct order_list *
 *
 *  Layout: allocate an array of (struct order_list *) with 2 hidden slots at the front.
 *    - base[0] stores length (as int via memcpy)
 *    - base[1] stores capacity in total slots (as int via memcpy)
 *    - User-visible list is &base[2], so iterations proceed from index 0.
 *
 *  Uses standard malloc/calloc/realloc/free.
 */

static inline struct order_list **
orders_base(orders_list l)
{
    return l ? (l - 2) : NULL;
}

static inline int
orders_get_len(struct order_list **base)
{
    int v = 0;
    memcpy(&v, &base[0], sizeof v);
    return v;
}

static inline void
orders_set_len(struct order_list **base, int v)
{
    memset(&base[0], 0, sizeof base[0]);
    memcpy(&base[0], &v, sizeof v);
}

static inline int
orders_get_cap(struct order_list **base)
{
    int v = 0;
    memcpy(&v, &base[1], sizeof v);
    return v;
}

static inline void
orders_set_cap(struct order_list **base, int v)
{
    memset(&base[1], 0, sizeof base[1]);
    memcpy(&base[1], &v, sizeof v);
}

static struct order_list **
orders_alloc_block(int cap_total_slots)
{
    assert(cap_total_slots >= 3);
    struct order_list **base = calloc((size_t)cap_total_slots, sizeof *base);
    if (!base)
    {
        fprintf(stderr, "orders_alloc_block: out of memory\n");
        exit(1);
    }
    orders_set_len(base, 0);
    orders_set_cap(base, cap_total_slots);
    return base;
}

static void
orders_ensure_capacity(orders_list *l, int min_len_needed)
{
    int min_total = min_len_needed + 2;

    if (*l == NULL)
    {
        int cap = ILIST_ALLOC;
        if (cap < 3)
            cap = 3;
        while (cap <= min_total)
            cap *= 2;
        struct order_list **base = orders_alloc_block(cap);
        *l = &base[2];
        return;
    }

    struct order_list **base = orders_base(*l);
    int cap = orders_get_cap(base);

    if (cap > min_total)
        return;

    size_t old_bytes = (size_t)cap * sizeof *base;
    while (cap <= min_total)
        cap *= 2;

    base = realloc(base, (size_t)cap * sizeof *base);
    if (!base)
    {
        fprintf(stderr, "orders_ensure_capacity: out of memory\n");
        exit(1);
    }

    memset((char *)base + old_bytes, 0, (size_t)cap * sizeof *base - old_bytes);
    orders_set_cap(base, cap);
    *l = &base[2];
}


void
orders_append(orders_list *l, struct order_list *n)
{
    int len = orders_len(*l);
    orders_ensure_capacity(l, len + 1);

    struct order_list **base = orders_base(*l);
    base[2 + len] = n;
    orders_set_len(base, len + 1);
}


void
orders_clear(orders_list *l)
{
    if (*l)
        orders_set_len(orders_base(*l), 0);
}


orders_list
orders_copy(orders_list l)
{
    if (!l)
        return NULL;

    struct order_list **base = orders_base(l);
    int len = orders_get_len(base);
    int cap = orders_get_cap(base);

    struct order_list **copy = orders_alloc_block(cap);
    orders_set_len(copy, len);
    memcpy(&copy[2], &base[2], (size_t)len * sizeof *base);

    return &copy[2];
}


void
orders_delete(orders_list *l, int i)
{
    assert(*l != NULL);
    struct order_list **base = orders_base(*l);
    int len = orders_get_len(base);
    assert(i >= 0 && i < len);

    memmove(&base[2 + i], &base[2 + i + 1], (size_t)(len - i - 1) * sizeof *base);
    orders_set_len(base, len - 1);
}


int
orders_len(orders_list l)
{
    struct order_list **base = orders_base(l);
    return base ? orders_get_len(base) : 0;
}


int
orders_lookup(orders_list l, struct order_list *n)
{
    if (l == NULL)
        return -1;

    int len = orders_len(l);
    int i;
    for (i = 0; i < len; i++)
        if (l[i] == n)
            return i;

    return -1;
}


void
orders_prepend(orders_list *l, struct order_list *n)
{
    int len = orders_len(*l);
    orders_ensure_capacity(l, len + 1);

    struct order_list **base = orders_base(*l);
    memmove(&base[3], &base[2], (size_t)len * sizeof *base);
    base[2] = n;
    orders_set_len(base, len + 1);
}


void
orders_reclaim(orders_list *l)
{
    if (*l)
        free(orders_base(*l));
    *l = NULL;
}


void
orders_rem_value(orders_list *l, struct order_list *n)
{
    int i;
    for (i = 0; i < orders_len(*l); i++)
        if ((*l)[i] == n)
        {
            orders_delete(l, i);
            i--;
        }
}


void
orders_scramble(orders_list l)
{
    orders_shuffle(l);
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
orders_shuffle(orders_list l)
{
    int len = orders_len(l) - 1;
    int i;
    for (i = 0; i < len; i++)
    {
        int r = rnd(i, len);
        if (r != i)
        {
            struct order_list *tmp = l[i];
            l[i] = l[r];
            l[r] = tmp;
        }
    }
}


void
orders_test(void)
{
    orders_list l = NULL;
    orders_list c = NULL;
    int i;

    setbuf(stdout, NULL);
    printf("orders_test: starting\n");

    printf("orders_test: len of empty list = %d\n", orders_len(l));
    assert(orders_len(l) == 0);

    enum { N = 100 };
    struct order_list *items[N];
    for (i = 0; i < N; i++)
        items[i] = (struct order_list *)malloc(1);

    for (i = 0; i < N; i++)
        orders_append(&l, items[i]);

    printf("orders_test: after append, len = %d\n", orders_len(l));
    assert(orders_len(l) == N);

    for (i = 0; i < N; i++)
        assert(l[i] == items[i]);

    c = orders_copy(l);
    assert(orders_len(c) == N);
    for (i = 0; i < N; i++)
    {
        assert(&c[i] != &l[i]);
        assert(c[i] == l[i]);
    }
    printf("orders_test: copy verified\n");

    orders_delete(&l, 50);
    assert(orders_len(l) == N - 1);
    printf("orders_test: after delete, len = %d\n", orders_len(l));

    orders_prepend(&l, items[50]);
    assert(orders_len(l) == N);
    assert(l[0] == items[50]);
    printf("orders_test: after prepend, len = %d\n", orders_len(l));

    assert(orders_lookup(l, items[50]) == 0);
    printf("orders_test: lookup verified\n");

    orders_clear(&l);
    assert(orders_len(l) == 0);
    printf("orders_test: after clear, len = %d\n", orders_len(l));

    orders_reclaim(&l);
    orders_reclaim(&c);
    assert(l == NULL);
    assert(c == NULL);

    for (i = 0; i < N; i++)
        free(items[i]);

    printf("orders_test: all tests passed\n");
}
