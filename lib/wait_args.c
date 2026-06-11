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
 *  Reallocing array handler for struct wait_arg *
 *
 *  Layout: allocate an array of (struct wait_arg *) with 2 hidden slots at the front.
 *    - base[0] stores length (as int via memcpy)
 *    - base[1] stores capacity in total slots (as int via memcpy)
 *    - User-visible list is &base[2], so iterations proceed from index 0.
 *
 *  Uses standard malloc/calloc/realloc/free.
 */

static inline struct wait_arg **
wait_args_base(wait_args_list l)
{
    return l ? (l - 2) : NULL;
}

static inline int
wait_args_get_len(struct wait_arg **base)
{
    int v = 0;
    memcpy(&v, &base[0], sizeof v);
    return v;
}

static inline void
wait_args_set_len(struct wait_arg **base, int v)
{
    memset(&base[0], 0, sizeof base[0]);
    memcpy(&base[0], &v, sizeof v);
}

static inline int
wait_args_get_cap(struct wait_arg **base)
{
    int v = 0;
    memcpy(&v, &base[1], sizeof v);
    return v;
}

static inline void
wait_args_set_cap(struct wait_arg **base, int v)
{
    memset(&base[1], 0, sizeof base[1]);
    memcpy(&base[1], &v, sizeof v);
}

static struct wait_arg **
wait_args_alloc_block(int cap_total_slots)
{
    assert(cap_total_slots >= 3);
    struct wait_arg **base = calloc((size_t)cap_total_slots, sizeof *base);
    if (!base)
    {
        fprintf(stderr, "wait_args_alloc_block: out of memory\n");
        exit(1);
    }
    wait_args_set_len(base, 0);
    wait_args_set_cap(base, cap_total_slots);
    return base;
}

static void
wait_args_ensure_capacity(wait_args_list *l, int min_len_needed)
{
    int min_total = min_len_needed + 2;

    if (*l == NULL)
    {
        int cap = ILIST_ALLOC;
        if (cap < 3)
            cap = 3;
        while (cap <= min_total)
            cap *= 2;
        struct wait_arg **base = wait_args_alloc_block(cap);
        *l = &base[2];
        return;
    }

    struct wait_arg **base = wait_args_base(*l);
    int cap = wait_args_get_cap(base);

    if (cap > min_total)
        return;

    size_t old_bytes = (size_t)cap * sizeof *base;
    while (cap <= min_total)
        cap *= 2;

    base = realloc(base, (size_t)cap * sizeof *base);
    if (!base)
    {
        fprintf(stderr, "wait_args_ensure_capacity: out of memory\n");
        exit(1);
    }

    memset((char *)base + old_bytes, 0, (size_t)cap * sizeof *base - old_bytes);
    wait_args_set_cap(base, cap);
    *l = &base[2];
}


void
wait_args_append(wait_args_list *l, struct wait_arg *n)
{
    int len = wait_args_len(*l);
    wait_args_ensure_capacity(l, len + 1);

    struct wait_arg **base = wait_args_base(*l);
    base[2 + len] = n;
    wait_args_set_len(base, len + 1);
}


void
wait_args_clear(wait_args_list *l)
{
    if (*l)
        wait_args_set_len(wait_args_base(*l), 0);
}


wait_args_list
wait_args_copy(wait_args_list l)
{
    if (!l)
        return NULL;

    struct wait_arg **base = wait_args_base(l);
    int len = wait_args_get_len(base);
    int cap = wait_args_get_cap(base);

    struct wait_arg **copy = wait_args_alloc_block(cap);
    wait_args_set_len(copy, len);
    memcpy(&copy[2], &base[2], (size_t)len * sizeof *base);

    return &copy[2];
}


void
wait_args_delete(wait_args_list *l, int i)
{
    assert(*l != NULL);
    struct wait_arg **base = wait_args_base(*l);
    int len = wait_args_get_len(base);
    assert(i >= 0 && i < len);

    memmove(&base[2 + i], &base[2 + i + 1], (size_t)(len - i - 1) * sizeof *base);
    wait_args_set_len(base, len - 1);
}


int
wait_args_len(wait_args_list l)
{
    struct wait_arg **base = wait_args_base(l);
    return base ? wait_args_get_len(base) : 0;
}


int
wait_args_lookup(wait_args_list l, struct wait_arg *n)
{
    if (l == NULL)
        return -1;

    int len = wait_args_len(l);
    int i;
    for (i = 0; i < len; i++)
        if (l[i] == n)
            return i;

    return -1;
}


void
wait_args_prepend(wait_args_list *l, struct wait_arg *n)
{
    int len = wait_args_len(*l);
    wait_args_ensure_capacity(l, len + 1);

    struct wait_arg **base = wait_args_base(*l);
    memmove(&base[3], &base[2], (size_t)len * sizeof *base);
    base[2] = n;
    wait_args_set_len(base, len + 1);
}


void
wait_args_reclaim(wait_args_list *l)
{
    if (*l)
        free(wait_args_base(*l));
    *l = NULL;
}


void
wait_args_rem_value(wait_args_list *l, struct wait_arg *n)
{
    int i;
    for (i = 0; i < wait_args_len(*l); i++)
        if ((*l)[i] == n)
        {
            wait_args_delete(l, i);
            i--;
        }
}


void
wait_args_scramble(wait_args_list l)
{
    wait_args_shuffle(l);
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
wait_args_shuffle(wait_args_list l)
{
    int len = wait_args_len(l) - 1;
    int i;
    for (i = 0; i < len; i++)
    {
        int r = rnd(i, len);
        if (r != i)
        {
            struct wait_arg *tmp = l[i];
            l[i] = l[r];
            l[r] = tmp;
        }
    }
}


void
wait_args_test(void)
{
    wait_args_list l = NULL;
    wait_args_list c = NULL;
    int i;

    setbuf(stdout, NULL);
    printf("wait_args_test: starting\n");

    printf("wait_args_test: len of empty list = %d\n", wait_args_len(l));
    assert(wait_args_len(l) == 0);

    enum { N = 100 };
    struct wait_arg *items[N];
    for (i = 0; i < N; i++)
        items[i] = (struct wait_arg *)malloc(1);

    for (i = 0; i < N; i++)
        wait_args_append(&l, items[i]);

    printf("wait_args_test: after append, len = %d\n", wait_args_len(l));
    assert(wait_args_len(l) == N);

    for (i = 0; i < N; i++)
        assert(l[i] == items[i]);

    c = wait_args_copy(l);
    assert(wait_args_len(c) == N);
    for (i = 0; i < N; i++)
    {
        assert(&c[i] != &l[i]);
        assert(c[i] == l[i]);
    }
    printf("wait_args_test: copy verified\n");

    wait_args_delete(&l, 50);
    assert(wait_args_len(l) == N - 1);
    printf("wait_args_test: after delete, len = %d\n", wait_args_len(l));

    wait_args_prepend(&l, items[50]);
    assert(wait_args_len(l) == N);
    assert(l[0] == items[50]);
    printf("wait_args_test: after prepend, len = %d\n", wait_args_len(l));

    assert(wait_args_lookup(l, items[50]) == 0);
    printf("wait_args_test: lookup verified\n");

    wait_args_clear(&l);
    assert(wait_args_len(l) == 0);
    printf("wait_args_test: after clear, len = %d\n", wait_args_len(l));

    wait_args_reclaim(&l);
    wait_args_reclaim(&c);
    assert(l == NULL);
    assert(c == NULL);

    for (i = 0; i < N; i++)
        free(items[i]);

    printf("wait_args_test: all tests passed\n");
}
