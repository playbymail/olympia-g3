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
 *  Reallocing array handler for struct req_ent *
 *
 *  Layout: allocate an array of (struct req_ent *) with 2 hidden slots at the front.
 *    - base[0] stores length (as int via memcpy)
 *    - base[1] stores capacity in total slots (as int via memcpy)
 *    - User-visible list is &base[2], so iterations proceed from index 0.
 *
 *  Uses standard malloc/calloc/realloc/free.
 */

static inline struct req_ent **
req_ents_base(req_ents_list l)
{
    return l ? (l - 2) : NULL;
}

static inline int
req_ents_get_len(struct req_ent **base)
{
    int v = 0;
    memcpy(&v, &base[0], sizeof v);
    return v;
}

static inline void
req_ents_set_len(struct req_ent **base, int v)
{
    memset(&base[0], 0, sizeof base[0]);
    memcpy(&base[0], &v, sizeof v);
}

static inline int
req_ents_get_cap(struct req_ent **base)
{
    int v = 0;
    memcpy(&v, &base[1], sizeof v);
    return v;
}

static inline void
req_ents_set_cap(struct req_ent **base, int v)
{
    memset(&base[1], 0, sizeof base[1]);
    memcpy(&base[1], &v, sizeof v);
}

static struct req_ent **
req_ents_alloc_block(int cap_total_slots)
{
    assert(cap_total_slots >= 3);
    struct req_ent **base = calloc((size_t)cap_total_slots, sizeof *base);
    if (!base)
    {
        fprintf(stderr, "req_ents_alloc_block: out of memory\n");
        exit(1);
    }
    req_ents_set_len(base, 0);
    req_ents_set_cap(base, cap_total_slots);
    return base;
}

static void
req_ents_ensure_capacity(req_ents_list *l, int min_len_needed)
{
    int min_total = min_len_needed + 2;

    if (*l == NULL)
    {
        int cap = ILIST_ALLOC;
        if (cap < 3)
            cap = 3;
        while (cap <= min_total)
            cap *= 2;
        struct req_ent **base = req_ents_alloc_block(cap);
        *l = &base[2];
        return;
    }

    struct req_ent **base = req_ents_base(*l);
    int cap = req_ents_get_cap(base);

    if (cap > min_total)
        return;

    size_t old_bytes = (size_t)cap * sizeof *base;
    while (cap <= min_total)
        cap *= 2;

    base = realloc(base, (size_t)cap * sizeof *base);
    if (!base)
    {
        fprintf(stderr, "req_ents_ensure_capacity: out of memory\n");
        exit(1);
    }

    memset((char *)base + old_bytes, 0, (size_t)cap * sizeof *base - old_bytes);
    req_ents_set_cap(base, cap);
    *l = &base[2];
}


void
req_ents_append(req_ents_list *l, struct req_ent *n)
{
    int len = req_ents_len(*l);
    req_ents_ensure_capacity(l, len + 1);

    struct req_ent **base = req_ents_base(*l);
    base[2 + len] = n;
    req_ents_set_len(base, len + 1);
}


void
req_ents_clear(req_ents_list *l)
{
    if (*l)
        req_ents_set_len(req_ents_base(*l), 0);
}


req_ents_list
req_ents_copy(req_ents_list l)
{
    if (!l)
        return NULL;

    struct req_ent **base = req_ents_base(l);
    int len = req_ents_get_len(base);
    int cap = req_ents_get_cap(base);

    struct req_ent **copy = req_ents_alloc_block(cap);
    req_ents_set_len(copy, len);
    memcpy(&copy[2], &base[2], (size_t)len * sizeof *base);

    return &copy[2];
}


void
req_ents_delete(req_ents_list *l, int i)
{
    assert(*l != NULL);
    struct req_ent **base = req_ents_base(*l);
    int len = req_ents_get_len(base);
    assert(i >= 0 && i < len);

    memmove(&base[2 + i], &base[2 + i + 1], (size_t)(len - i - 1) * sizeof *base);
    req_ents_set_len(base, len - 1);
}


int
req_ents_len(req_ents_list l)
{
    struct req_ent **base = req_ents_base(l);
    return base ? req_ents_get_len(base) : 0;
}


int
req_ents_lookup(req_ents_list l, struct req_ent *n)
{
    if (l == NULL)
        return -1;

    int len = req_ents_len(l);
    int i;
    for (i = 0; i < len; i++)
        if (l[i] == n)
            return i;

    return -1;
}


void
req_ents_prepend(req_ents_list *l, struct req_ent *n)
{
    int len = req_ents_len(*l);
    req_ents_ensure_capacity(l, len + 1);

    struct req_ent **base = req_ents_base(*l);
    memmove(&base[3], &base[2], (size_t)len * sizeof *base);
    base[2] = n;
    req_ents_set_len(base, len + 1);
}


void
req_ents_reclaim(req_ents_list *l)
{
    if (*l)
        free(req_ents_base(*l));
    *l = NULL;
}


void
req_ents_rem_value(req_ents_list *l, struct req_ent *n)
{
    int i;
    for (i = 0; i < req_ents_len(*l); i++)
        if ((*l)[i] == n)
        {
            req_ents_delete(l, i);
            i--;
        }
}


void
req_ents_scramble(req_ents_list l)
{
    req_ents_shuffle(l);
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
req_ents_shuffle(req_ents_list l)
{
    int len = req_ents_len(l) - 1;
    int i;
    for (i = 0; i < len; i++)
    {
        int r = rnd(i, len);
        if (r != i)
        {
            struct req_ent *tmp = l[i];
            l[i] = l[r];
            l[r] = tmp;
        }
    }
}


void
req_ents_test(void)
{
    req_ents_list l = NULL;
    req_ents_list c = NULL;
    int i;

    setbuf(stdout, NULL);
    printf("req_ents_test: starting\n");

    printf("req_ents_test: len of empty list = %d\n", req_ents_len(l));
    assert(req_ents_len(l) == 0);

    enum { N = 100 };
    struct req_ent *items[N];
    for (i = 0; i < N; i++)
        items[i] = (struct req_ent *)malloc(1);

    for (i = 0; i < N; i++)
        req_ents_append(&l, items[i]);

    printf("req_ents_test: after append, len = %d\n", req_ents_len(l));
    assert(req_ents_len(l) == N);

    for (i = 0; i < N; i++)
        assert(l[i] == items[i]);

    c = req_ents_copy(l);
    assert(req_ents_len(c) == N);
    for (i = 0; i < N; i++)
    {
        assert(&c[i] != &l[i]);
        assert(c[i] == l[i]);
    }
    printf("req_ents_test: copy verified\n");

    req_ents_delete(&l, 50);
    assert(req_ents_len(l) == N - 1);
    printf("req_ents_test: after delete, len = %d\n", req_ents_len(l));

    req_ents_prepend(&l, items[50]);
    assert(req_ents_len(l) == N);
    assert(l[0] == items[50]);
    printf("req_ents_test: after prepend, len = %d\n", req_ents_len(l));

    assert(req_ents_lookup(l, items[50]) == 0);
    printf("req_ents_test: lookup verified\n");

    req_ents_clear(&l);
    assert(req_ents_len(l) == 0);
    printf("req_ents_test: after clear, len = %d\n", req_ents_len(l));

    req_ents_reclaim(&l);
    req_ents_reclaim(&c);
    assert(l == NULL);
    assert(c == NULL);

    for (i = 0; i < N; i++)
        free(items[i]);

    printf("req_ents_test: all tests passed\n");
}
