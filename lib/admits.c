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
 *  Reallocing array handler for struct admit *
 *
 *  Layout: allocate an array of (struct admit *) with 2 hidden slots at the front.
 *    - base[0] stores length (as int via memcpy)
 *    - base[1] stores capacity in total slots (as int via memcpy)
 *    - User-visible list is &base[2], so iterations proceed from index 0.
 *
 *  Uses standard malloc/calloc/realloc/free.
 */

static inline struct admit **
admits_base(admits_list l)
{
    return l ? (l - 2) : NULL;
}

static inline int
admits_get_len(struct admit **base)
{
    int v = 0;
    memcpy(&v, &base[0], sizeof v);
    return v;
}

static inline void
admits_set_len(struct admit **base, int v)
{
    memset(&base[0], 0, sizeof base[0]);
    memcpy(&base[0], &v, sizeof v);
}

static inline int
admits_get_cap(struct admit **base)
{
    int v = 0;
    memcpy(&v, &base[1], sizeof v);
    return v;
}

static inline void
admits_set_cap(struct admit **base, int v)
{
    memset(&base[1], 0, sizeof base[1]);
    memcpy(&base[1], &v, sizeof v);
}

static struct admit **
admits_alloc_block(int cap_total_slots)
{
    assert(cap_total_slots >= 3);
    struct admit **base = calloc((size_t)cap_total_slots, sizeof *base);
    if (!base)
    {
        fprintf(stderr, "admits_alloc_block: out of memory\n");
        exit(1);
    }
    admits_set_len(base, 0);
    admits_set_cap(base, cap_total_slots);
    return base;
}

static void
admits_ensure_capacity(admits_list *l, int min_len_needed)
{
    int min_total = min_len_needed + 2;

    if (*l == NULL)
    {
        int cap = ILIST_ALLOC;
        if (cap < 3)
            cap = 3;
        while (cap <= min_total)
            cap *= 2;
        struct admit **base = admits_alloc_block(cap);
        *l = &base[2];
        return;
    }

    struct admit **base = admits_base(*l);
    int cap = admits_get_cap(base);

    if (cap > min_total)
        return;

    size_t old_bytes = (size_t)cap * sizeof *base;
    while (cap <= min_total)
        cap *= 2;

    base = realloc(base, (size_t)cap * sizeof *base);
    if (!base)
    {
        fprintf(stderr, "admits_ensure_capacity: out of memory\n");
        exit(1);
    }

    memset((char *)base + old_bytes, 0, (size_t)cap * sizeof *base - old_bytes);
    admits_set_cap(base, cap);
    *l = &base[2];
}


void
admits_append(admits_list *l, struct admit *n)
{
    int len = admits_len(*l);
    admits_ensure_capacity(l, len + 1);

    struct admit **base = admits_base(*l);
    base[2 + len] = n;
    admits_set_len(base, len + 1);
}


void
admits_clear(admits_list *l)
{
    if (*l)
        admits_set_len(admits_base(*l), 0);
}


admits_list
admits_copy(admits_list l)
{
    if (!l)
        return NULL;

    struct admit **base = admits_base(l);
    int len = admits_get_len(base);
    int cap = admits_get_cap(base);

    struct admit **copy = admits_alloc_block(cap);
    admits_set_len(copy, len);
    memcpy(&copy[2], &base[2], (size_t)len * sizeof *base);

    return &copy[2];
}


void
admits_delete(admits_list *l, int i)
{
    assert(*l != NULL);
    struct admit **base = admits_base(*l);
    int len = admits_get_len(base);
    assert(i >= 0 && i < len);

    memmove(&base[2 + i], &base[2 + i + 1], (size_t)(len - i - 1) * sizeof *base);
    admits_set_len(base, len - 1);
}


int
admits_len(admits_list l)
{
    struct admit **base = admits_base(l);
    return base ? admits_get_len(base) : 0;
}


int
admits_lookup(admits_list l, struct admit *n)
{
    if (l == NULL)
        return -1;

    int len = admits_len(l);
    int i;
    for (i = 0; i < len; i++)
        if (l[i] == n)
            return i;

    return -1;
}


void
admits_prepend(admits_list *l, struct admit *n)
{
    int len = admits_len(*l);
    admits_ensure_capacity(l, len + 1);

    struct admit **base = admits_base(*l);
    memmove(&base[3], &base[2], (size_t)len * sizeof *base);
    base[2] = n;
    admits_set_len(base, len + 1);
}


void
admits_reclaim(admits_list *l)
{
    if (*l)
        free(admits_base(*l));
    *l = NULL;
}


void
admits_rem_value(admits_list *l, struct admit *n)
{
    int i;
    for (i = 0; i < admits_len(*l); i++)
        if ((*l)[i] == n)
        {
            admits_delete(l, i);
            i--;
        }
}


void
admits_scramble(admits_list l)
{
    admits_shuffle(l);
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
admits_shuffle(admits_list l)
{
    int len = admits_len(l) - 1;
    int i;
    for (i = 0; i < len; i++)
    {
        int r = rnd(i, len);
        if (r != i)
        {
            struct admit *tmp = l[i];
            l[i] = l[r];
            l[r] = tmp;
        }
    }
}


void
admits_test(void)
{
    admits_list l = NULL;
    admits_list c = NULL;
    int i;

    setbuf(stdout, NULL);
    printf("admits_test: starting\n");

    printf("admits_test: len of empty list = %d\n", admits_len(l));
    assert(admits_len(l) == 0);

    enum { N = 100 };
    struct admit *items[N];
    for (i = 0; i < N; i++)
        items[i] = (struct admit *)malloc(1);

    for (i = 0; i < N; i++)
        admits_append(&l, items[i]);

    printf("admits_test: after append, len = %d\n", admits_len(l));
    assert(admits_len(l) == N);

    for (i = 0; i < N; i++)
        assert(l[i] == items[i]);

    c = admits_copy(l);
    assert(admits_len(c) == N);
    for (i = 0; i < N; i++)
    {
        assert(&c[i] != &l[i]);
        assert(c[i] == l[i]);
    }
    printf("admits_test: copy verified\n");

    admits_delete(&l, 50);
    assert(admits_len(l) == N - 1);
    printf("admits_test: after delete, len = %d\n", admits_len(l));

    admits_prepend(&l, items[50]);
    assert(admits_len(l) == N);
    assert(l[0] == items[50]);
    printf("admits_test: after prepend, len = %d\n", admits_len(l));

    assert(admits_lookup(l, items[50]) == 0);
    printf("admits_test: lookup verified\n");

    admits_clear(&l);
    assert(admits_len(l) == 0);
    printf("admits_test: after clear, len = %d\n", admits_len(l));

    admits_reclaim(&l);
    admits_reclaim(&c);
    assert(l == NULL);
    assert(c == NULL);

    for (i = 0; i < N; i++)
        free(items[i]);

    printf("admits_test: all tests passed\n");
}
