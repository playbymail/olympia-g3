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
 *  Reallocing array handler for struct skill_ent *
 *
 *  Layout: allocate an array of (struct skill_ent *) with 2 hidden slots at the front.
 *    - base[0] stores length (as int via memcpy)
 *    - base[1] stores capacity in total slots (as int via memcpy)
 *    - User-visible list is &base[2], so iterations proceed from index 0.
 *
 *  Uses standard malloc/calloc/realloc/free.
 */

static inline struct skill_ent **
skill_ents_base(skill_ents_list l)
{
    return l ? (l - 2) : NULL;
}

static inline int
skill_ents_get_len(struct skill_ent **base)
{
    int v = 0;
    memcpy(&v, &base[0], sizeof v);
    return v;
}

static inline void
skill_ents_set_len(struct skill_ent **base, int v)
{
    memset(&base[0], 0, sizeof base[0]);
    memcpy(&base[0], &v, sizeof v);
}

static inline int
skill_ents_get_cap(struct skill_ent **base)
{
    int v = 0;
    memcpy(&v, &base[1], sizeof v);
    return v;
}

static inline void
skill_ents_set_cap(struct skill_ent **base, int v)
{
    memset(&base[1], 0, sizeof base[1]);
    memcpy(&base[1], &v, sizeof v);
}

static struct skill_ent **
skill_ents_alloc_block(int cap_total_slots)
{
    assert(cap_total_slots >= 3);
    struct skill_ent **base = calloc((size_t)cap_total_slots, sizeof *base);
    if (!base)
    {
        fprintf(stderr, "skill_ents_alloc_block: out of memory\n");
        exit(1);
    }
    skill_ents_set_len(base, 0);
    skill_ents_set_cap(base, cap_total_slots);
    return base;
}

static void
skill_ents_ensure_capacity(skill_ents_list *l, int min_len_needed)
{
    int min_total = min_len_needed + 2;

    if (*l == NULL)
    {
        int cap = ILIST_ALLOC;
        if (cap < 3)
            cap = 3;
        while (cap <= min_total)
            cap *= 2;
        struct skill_ent **base = skill_ents_alloc_block(cap);
        *l = &base[2];
        return;
    }

    struct skill_ent **base = skill_ents_base(*l);
    int cap = skill_ents_get_cap(base);

    if (cap > min_total)
        return;

    size_t old_bytes = (size_t)cap * sizeof *base;
    while (cap <= min_total)
        cap *= 2;

    base = realloc(base, (size_t)cap * sizeof *base);
    if (!base)
    {
        fprintf(stderr, "skill_ents_ensure_capacity: out of memory\n");
        exit(1);
    }

    memset((char *)base + old_bytes, 0, (size_t)cap * sizeof *base - old_bytes);
    skill_ents_set_cap(base, cap);
    *l = &base[2];
}


void
skill_ents_append(skill_ents_list *l, struct skill_ent *n)
{
    int len = skill_ents_len(*l);
    skill_ents_ensure_capacity(l, len + 1);

    struct skill_ent **base = skill_ents_base(*l);
    base[2 + len] = n;
    skill_ents_set_len(base, len + 1);
}


void
skill_ents_clear(skill_ents_list *l)
{
    if (*l)
        skill_ents_set_len(skill_ents_base(*l), 0);
}


skill_ents_list
skill_ents_copy(skill_ents_list l)
{
    if (!l)
        return NULL;

    struct skill_ent **base = skill_ents_base(l);
    int len = skill_ents_get_len(base);
    int cap = skill_ents_get_cap(base);

    struct skill_ent **copy = skill_ents_alloc_block(cap);
    skill_ents_set_len(copy, len);
    memcpy(&copy[2], &base[2], (size_t)len * sizeof *base);

    return &copy[2];
}


void
skill_ents_delete(skill_ents_list *l, int i)
{
    assert(*l != NULL);
    struct skill_ent **base = skill_ents_base(*l);
    int len = skill_ents_get_len(base);
    assert(i >= 0 && i < len);

    memmove(&base[2 + i], &base[2 + i + 1], (size_t)(len - i - 1) * sizeof *base);
    skill_ents_set_len(base, len - 1);
}


int
skill_ents_len(skill_ents_list l)
{
    struct skill_ent **base = skill_ents_base(l);
    return base ? skill_ents_get_len(base) : 0;
}


int
skill_ents_lookup(skill_ents_list l, struct skill_ent *n)
{
    if (l == NULL)
        return -1;

    int len = skill_ents_len(l);
    int i;
    for (i = 0; i < len; i++)
        if (l[i] == n)
            return i;

    return -1;
}


void
skill_ents_prepend(skill_ents_list *l, struct skill_ent *n)
{
    int len = skill_ents_len(*l);
    skill_ents_ensure_capacity(l, len + 1);

    struct skill_ent **base = skill_ents_base(*l);
    memmove(&base[3], &base[2], (size_t)len * sizeof *base);
    base[2] = n;
    skill_ents_set_len(base, len + 1);
}


void
skill_ents_reclaim(skill_ents_list *l)
{
    if (*l)
        free(skill_ents_base(*l));
    *l = NULL;
}


void
skill_ents_rem_value(skill_ents_list *l, struct skill_ent *n)
{
    int i;
    for (i = 0; i < skill_ents_len(*l); i++)
        if ((*l)[i] == n)
        {
            skill_ents_delete(l, i);
            i--;
        }
}


void
skill_ents_scramble(skill_ents_list l)
{
    skill_ents_shuffle(l);
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
skill_ents_shuffle(skill_ents_list l)
{
    int len = skill_ents_len(l) - 1;
    int i;
    for (i = 0; i < len; i++)
    {
        int r = rnd(i, len);
        if (r != i)
        {
            struct skill_ent *tmp = l[i];
            l[i] = l[r];
            l[r] = tmp;
        }
    }
}


void
skill_ents_test(void)
{
    skill_ents_list l = NULL;
    skill_ents_list c = NULL;
    int i;

    setbuf(stdout, NULL);
    printf("skill_ents_test: starting\n");

    printf("skill_ents_test: len of empty list = %d\n", skill_ents_len(l));
    assert(skill_ents_len(l) == 0);

    enum { N = 100 };
    struct skill_ent *items[N];
    for (i = 0; i < N; i++)
        items[i] = (struct skill_ent *)malloc(1);

    for (i = 0; i < N; i++)
        skill_ents_append(&l, items[i]);

    printf("skill_ents_test: after append, len = %d\n", skill_ents_len(l));
    assert(skill_ents_len(l) == N);

    for (i = 0; i < N; i++)
        assert(l[i] == items[i]);

    c = skill_ents_copy(l);
    assert(skill_ents_len(c) == N);
    for (i = 0; i < N; i++)
    {
        assert(&c[i] != &l[i]);
        assert(c[i] == l[i]);
    }
    printf("skill_ents_test: copy verified\n");

    skill_ents_delete(&l, 50);
    assert(skill_ents_len(l) == N - 1);
    printf("skill_ents_test: after delete, len = %d\n", skill_ents_len(l));

    skill_ents_prepend(&l, items[50]);
    assert(skill_ents_len(l) == N);
    assert(l[0] == items[50]);
    printf("skill_ents_test: after prepend, len = %d\n", skill_ents_len(l));

    assert(skill_ents_lookup(l, items[50]) == 0);
    printf("skill_ents_test: lookup verified\n");

    skill_ents_clear(&l);
    assert(skill_ents_len(l) == 0);
    printf("skill_ents_test: after clear, len = %d\n", skill_ents_len(l));

    skill_ents_reclaim(&l);
    skill_ents_reclaim(&c);
    assert(l == NULL);
    assert(c == NULL);

    for (i = 0; i < N; i++)
        free(items[i]);

    printf("skill_ents_test: all tests passed\n");
}
