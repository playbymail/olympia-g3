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
 *  Reallocing array handler for struct entity_build *
 *
 *  Layout: allocate an array of (struct entity_build *) with 2 hidden slots at the front.
 *    - base[0] stores length (as int via memcpy)
 *    - base[1] stores capacity in total slots (as int via memcpy)
 *    - User-visible list is &base[2], so iterations proceed from index 0.
 *
 *  Uses standard malloc/calloc/realloc/free.
 */

static inline struct entity_build **
entity_builds_base(entity_builds_list l)
{
    return l ? (l - 2) : NULL;
}

static inline int
entity_builds_get_len(struct entity_build **base)
{
    int v = 0;
    memcpy(&v, &base[0], sizeof v);
    return v;
}

static inline void
entity_builds_set_len(struct entity_build **base, int v)
{
    memset(&base[0], 0, sizeof base[0]);
    memcpy(&base[0], &v, sizeof v);
}

static inline int
entity_builds_get_cap(struct entity_build **base)
{
    int v = 0;
    memcpy(&v, &base[1], sizeof v);
    return v;
}

static inline void
entity_builds_set_cap(struct entity_build **base, int v)
{
    memset(&base[1], 0, sizeof base[1]);
    memcpy(&base[1], &v, sizeof v);
}

static struct entity_build **
entity_builds_alloc_block(int cap_total_slots)
{
    assert(cap_total_slots >= 3);
    struct entity_build **base = calloc((size_t)cap_total_slots, sizeof *base);
    if (!base)
    {
        fprintf(stderr, "entity_builds_alloc_block: out of memory\n");
        exit(1);
    }
    entity_builds_set_len(base, 0);
    entity_builds_set_cap(base, cap_total_slots);
    return base;
}

static void
entity_builds_ensure_capacity(entity_builds_list *l, int min_len_needed)
{
    int min_total = min_len_needed + 2;

    if (*l == NULL)
    {
        int cap = ILIST_ALLOC;
        if (cap < 3)
            cap = 3;
        while (cap <= min_total)
            cap *= 2;
        struct entity_build **base = entity_builds_alloc_block(cap);
        *l = &base[2];
        return;
    }

    struct entity_build **base = entity_builds_base(*l);
    int cap = entity_builds_get_cap(base);

    if (cap > min_total)
        return;

    size_t old_bytes = (size_t)cap * sizeof *base;
    while (cap <= min_total)
        cap *= 2;

    base = realloc(base, (size_t)cap * sizeof *base);
    if (!base)
    {
        fprintf(stderr, "entity_builds_ensure_capacity: out of memory\n");
        exit(1);
    }

    memset((char *)base + old_bytes, 0, (size_t)cap * sizeof *base - old_bytes);
    entity_builds_set_cap(base, cap);
    *l = &base[2];
}


void
entity_builds_append(entity_builds_list *l, struct entity_build *n)
{
    int len = entity_builds_len(*l);
    entity_builds_ensure_capacity(l, len + 1);

    struct entity_build **base = entity_builds_base(*l);
    base[2 + len] = n;
    entity_builds_set_len(base, len + 1);
}


void
entity_builds_clear(entity_builds_list *l)
{
    if (*l)
        entity_builds_set_len(entity_builds_base(*l), 0);
}


entity_builds_list
entity_builds_copy(entity_builds_list l)
{
    if (!l)
        return NULL;

    struct entity_build **base = entity_builds_base(l);
    int len = entity_builds_get_len(base);
    int cap = entity_builds_get_cap(base);

    struct entity_build **copy = entity_builds_alloc_block(cap);
    entity_builds_set_len(copy, len);
    memcpy(&copy[2], &base[2], (size_t)len * sizeof *base);

    return &copy[2];
}


void
entity_builds_delete(entity_builds_list *l, int i)
{
    assert(*l != NULL);
    struct entity_build **base = entity_builds_base(*l);
    int len = entity_builds_get_len(base);
    assert(i >= 0 && i < len);

    memmove(&base[2 + i], &base[2 + i + 1], (size_t)(len - i - 1) * sizeof *base);
    entity_builds_set_len(base, len - 1);
}


int
entity_builds_len(entity_builds_list l)
{
    struct entity_build **base = entity_builds_base(l);
    return base ? entity_builds_get_len(base) : 0;
}


int
entity_builds_lookup(entity_builds_list l, struct entity_build *n)
{
    if (l == NULL)
        return -1;

    int len = entity_builds_len(l);
    int i;
    for (i = 0; i < len; i++)
        if (l[i] == n)
            return i;

    return -1;
}


void
entity_builds_prepend(entity_builds_list *l, struct entity_build *n)
{
    int len = entity_builds_len(*l);
    entity_builds_ensure_capacity(l, len + 1);

    struct entity_build **base = entity_builds_base(*l);
    memmove(&base[3], &base[2], (size_t)len * sizeof *base);
    base[2] = n;
    entity_builds_set_len(base, len + 1);
}


void
entity_builds_reclaim(entity_builds_list *l)
{
    if (*l)
        free(entity_builds_base(*l));
    *l = NULL;
}


void
entity_builds_rem_value(entity_builds_list *l, struct entity_build *n)
{
    int i;
    for (i = 0; i < entity_builds_len(*l); i++)
        if ((*l)[i] == n)
        {
            entity_builds_delete(l, i);
            i--;
        }
}


void
entity_builds_scramble(entity_builds_list l)
{
    entity_builds_shuffle(l);
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
entity_builds_shuffle(entity_builds_list l)
{
    int len = entity_builds_len(l) - 1;
    int i;
    for (i = 0; i < len; i++)
    {
        int r = rnd(i, len);
        if (r != i)
        {
            struct entity_build *tmp = l[i];
            l[i] = l[r];
            l[r] = tmp;
        }
    }
}


void
entity_builds_test(void)
{
    entity_builds_list l = NULL;
    entity_builds_list c = NULL;
    int i;

    setbuf(stdout, NULL);
    printf("entity_builds_test: starting\n");

    printf("entity_builds_test: len of empty list = %d\n", entity_builds_len(l));
    assert(entity_builds_len(l) == 0);

    enum { N = 100 };
    struct entity_build *items[N];
    for (i = 0; i < N; i++)
        items[i] = (struct entity_build *)malloc(1);

    for (i = 0; i < N; i++)
        entity_builds_append(&l, items[i]);

    printf("entity_builds_test: after append, len = %d\n", entity_builds_len(l));
    assert(entity_builds_len(l) == N);

    for (i = 0; i < N; i++)
        assert(l[i] == items[i]);

    c = entity_builds_copy(l);
    assert(entity_builds_len(c) == N);
    for (i = 0; i < N; i++)
    {
        assert(&c[i] != &l[i]);
        assert(c[i] == l[i]);
    }
    printf("entity_builds_test: copy verified\n");

    entity_builds_delete(&l, 50);
    assert(entity_builds_len(l) == N - 1);
    printf("entity_builds_test: after delete, len = %d\n", entity_builds_len(l));

    entity_builds_prepend(&l, items[50]);
    assert(entity_builds_len(l) == N);
    assert(l[0] == items[50]);
    printf("entity_builds_test: after prepend, len = %d\n", entity_builds_len(l));

    assert(entity_builds_lookup(l, items[50]) == 0);
    printf("entity_builds_test: lookup verified\n");

    entity_builds_clear(&l);
    assert(entity_builds_len(l) == 0);
    printf("entity_builds_test: after clear, len = %d\n", entity_builds_len(l));

    entity_builds_reclaim(&l);
    entity_builds_reclaim(&c);
    assert(l == NULL);
    assert(c == NULL);

    for (i = 0; i < N; i++)
        free(items[i]);

    printf("entity_builds_test: all tests passed\n");
}
