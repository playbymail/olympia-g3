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
 *  Reallocing array handler for struct effect *
 *
 *  Layout: allocate an array of (struct effect *) with 2 hidden slots at the front.
 *    - base[0] stores length (as int via memcpy)
 *    - base[1] stores capacity in total slots (as int via memcpy)
 *    - User-visible list is &base[2], so iterations proceed from index 0.
 *
 *  Uses standard malloc/calloc/realloc/free.
 */

static inline struct effect **
effects_base(effects_list l)
{
    return l ? (l - 2) : NULL;
}

static inline int
effects_get_len(struct effect **base)
{
    int v = 0;
    memcpy(&v, &base[0], sizeof v);
    return v;
}

static inline void
effects_set_len(struct effect **base, int v)
{
    memset(&base[0], 0, sizeof base[0]);
    memcpy(&base[0], &v, sizeof v);
}

static inline int
effects_get_cap(struct effect **base)
{
    int v = 0;
    memcpy(&v, &base[1], sizeof v);
    return v;
}

static inline void
effects_set_cap(struct effect **base, int v)
{
    memset(&base[1], 0, sizeof base[1]);
    memcpy(&base[1], &v, sizeof v);
}

static struct effect **
effects_alloc_block(int cap_total_slots)
{
    assert(cap_total_slots >= 3);
    struct effect **base = calloc((size_t)cap_total_slots, sizeof *base);
    if (!base)
    {
        fprintf(stderr, "effects_alloc_block: out of memory\n");
        exit(1);
    }
    effects_set_len(base, 0);
    effects_set_cap(base, cap_total_slots);
    return base;
}

static void
effects_ensure_capacity(effects_list *l, int min_len_needed)
{
    int min_total = min_len_needed + 2;

    if (*l == NULL)
    {
        int cap = ILIST_ALLOC;
        if (cap < 3)
            cap = 3;
        while (cap <= min_total)
            cap *= 2;
        struct effect **base = effects_alloc_block(cap);
        *l = &base[2];
        return;
    }

    struct effect **base = effects_base(*l);
    int cap = effects_get_cap(base);

    if (cap > min_total)
        return;

    size_t old_bytes = (size_t)cap * sizeof *base;
    while (cap <= min_total)
        cap *= 2;

    base = realloc(base, (size_t)cap * sizeof *base);
    if (!base)
    {
        fprintf(stderr, "effects_ensure_capacity: out of memory\n");
        exit(1);
    }

    memset((char *)base + old_bytes, 0, (size_t)cap * sizeof *base - old_bytes);
    effects_set_cap(base, cap);
    *l = &base[2];
}


void
effects_append(effects_list *l, struct effect *n)
{
    int len = effects_len(*l);
    effects_ensure_capacity(l, len + 1);

    struct effect **base = effects_base(*l);
    base[2 + len] = n;
    effects_set_len(base, len + 1);
}


void
effects_clear(effects_list *l)
{
    if (*l)
        effects_set_len(effects_base(*l), 0);
}


effects_list
effects_copy(effects_list l)
{
    if (!l)
        return NULL;

    struct effect **base = effects_base(l);
    int len = effects_get_len(base);
    int cap = effects_get_cap(base);

    struct effect **copy = effects_alloc_block(cap);
    effects_set_len(copy, len);
    memcpy(&copy[2], &base[2], (size_t)len * sizeof *base);

    return &copy[2];
}


void
effects_delete(effects_list *l, int i)
{
    assert(*l != NULL);
    struct effect **base = effects_base(*l);
    int len = effects_get_len(base);
    assert(i >= 0 && i < len);

    memmove(&base[2 + i], &base[2 + i + 1], (size_t)(len - i - 1) * sizeof *base);
    effects_set_len(base, len - 1);
}


int
effects_len(effects_list l)
{
    struct effect **base = effects_base(l);
    return base ? effects_get_len(base) : 0;
}


int
effects_lookup(effects_list l, struct effect *n)
{
    if (l == NULL)
        return -1;

    int len = effects_len(l);
    int i;
    for (i = 0; i < len; i++)
        if (l[i] == n)
            return i;

    return -1;
}


void
effects_prepend(effects_list *l, struct effect *n)
{
    int len = effects_len(*l);
    effects_ensure_capacity(l, len + 1);

    struct effect **base = effects_base(*l);
    memmove(&base[3], &base[2], (size_t)len * sizeof *base);
    base[2] = n;
    effects_set_len(base, len + 1);
}


void
effects_reclaim(effects_list *l)
{
    if (*l)
        free(effects_base(*l));
    *l = NULL;
}


void
effects_rem_value(effects_list *l, struct effect *n)
{
    int i;
    for (i = 0; i < effects_len(*l); i++)
        if ((*l)[i] == n)
        {
            effects_delete(l, i);
            i--;
        }
}


void
effects_scramble(effects_list l)
{
    effects_shuffle(l);
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
effects_shuffle(effects_list l)
{
    int len = effects_len(l) - 1;
    int i;
    for (i = 0; i < len; i++)
    {
        int r = rnd(i, len);
        if (r != i)
        {
            struct effect *tmp = l[i];
            l[i] = l[r];
            l[r] = tmp;
        }
    }
}


void
effects_test(void)
{
    effects_list l = NULL;
    effects_list c = NULL;
    int i;

    setbuf(stdout, NULL);
    printf("effects_test: starting\n");

    printf("effects_test: len of empty list = %d\n", effects_len(l));
    assert(effects_len(l) == 0);

    enum { N = 100 };
    struct effect *items[N];
    for (i = 0; i < N; i++)
        items[i] = (struct effect *)malloc(1);

    for (i = 0; i < N; i++)
        effects_append(&l, items[i]);

    printf("effects_test: after append, len = %d\n", effects_len(l));
    assert(effects_len(l) == N);

    for (i = 0; i < N; i++)
        assert(l[i] == items[i]);

    c = effects_copy(l);
    assert(effects_len(c) == N);
    for (i = 0; i < N; i++)
    {
        assert(&c[i] != &l[i]);
        assert(c[i] == l[i]);
    }
    printf("effects_test: copy verified\n");

    effects_delete(&l, 50);
    assert(effects_len(l) == N - 1);
    printf("effects_test: after delete, len = %d\n", effects_len(l));

    effects_prepend(&l, items[50]);
    assert(effects_len(l) == N);
    assert(l[0] == items[50]);
    printf("effects_test: after prepend, len = %d\n", effects_len(l));

    assert(effects_lookup(l, items[50]) == 0);
    printf("effects_test: lookup verified\n");

    effects_clear(&l);
    assert(effects_len(l) == 0);
    printf("effects_test: after clear, len = %d\n", effects_len(l));

    effects_reclaim(&l);
    effects_reclaim(&c);
    assert(l == NULL);
    assert(c == NULL);

    for (i = 0; i < N; i++)
        free(items[i]);

    printf("effects_test: all tests passed\n");
}
