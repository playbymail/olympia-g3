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
 *  Reallocing array handler for struct fight *
 *
 *  Layout: allocate an array of (struct fight *) with 2 hidden slots at the front.
 *    - base[0] stores length (as int via memcpy)
 *    - base[1] stores capacity in total slots (as int via memcpy)
 *    - User-visible list is &base[2], so iterations proceed from index 0.
 *
 *  Uses standard malloc/calloc/realloc/free.
 */

static inline struct fight **
fights_base(fights_list l)
{
    return l ? (l - 2) : NULL;
}

static inline int
fights_get_len(struct fight **base)
{
    int v = 0;
    memcpy(&v, &base[0], sizeof v);
    return v;
}

static inline void
fights_set_len(struct fight **base, int v)
{
    memset(&base[0], 0, sizeof base[0]);
    memcpy(&base[0], &v, sizeof v);
}

static inline int
fights_get_cap(struct fight **base)
{
    int v = 0;
    memcpy(&v, &base[1], sizeof v);
    return v;
}

static inline void
fights_set_cap(struct fight **base, int v)
{
    memset(&base[1], 0, sizeof base[1]);
    memcpy(&base[1], &v, sizeof v);
}

static struct fight **
fights_alloc_block(int cap_total_slots)
{
    assert(cap_total_slots >= 3);
    struct fight **base = calloc((size_t)cap_total_slots, sizeof *base);
    if (!base)
    {
        fprintf(stderr, "fights_alloc_block: out of memory\n");
        exit(1);
    }
    fights_set_len(base, 0);
    fights_set_cap(base, cap_total_slots);
    return base;
}

static void
fights_ensure_capacity(fights_list *l, int min_len_needed)
{
    int min_total = min_len_needed + 2;

    if (*l == NULL)
    {
        int cap = ILIST_ALLOC;
        if (cap < 3)
            cap = 3;
        while (cap <= min_total)
            cap *= 2;
        struct fight **base = fights_alloc_block(cap);
        *l = &base[2];
        return;
    }

    struct fight **base = fights_base(*l);
    int cap = fights_get_cap(base);

    if (cap > min_total)
        return;

    size_t old_bytes = (size_t)cap * sizeof *base;
    while (cap <= min_total)
        cap *= 2;

    base = realloc(base, (size_t)cap * sizeof *base);
    if (!base)
    {
        fprintf(stderr, "fights_ensure_capacity: out of memory\n");
        exit(1);
    }

    memset((char *)base + old_bytes, 0, (size_t)cap * sizeof *base - old_bytes);
    fights_set_cap(base, cap);
    *l = &base[2];
}


void
fights_append(fights_list *l, struct fight *n)
{
    int len = fights_len(*l);
    fights_ensure_capacity(l, len + 1);

    struct fight **base = fights_base(*l);
    base[2 + len] = n;
    fights_set_len(base, len + 1);
}


void
fights_clear(fights_list *l)
{
    if (*l)
        fights_set_len(fights_base(*l), 0);
}


fights_list
fights_copy(fights_list l)
{
    if (!l)
        return NULL;

    struct fight **base = fights_base(l);
    int len = fights_get_len(base);
    int cap = fights_get_cap(base);

    struct fight **copy = fights_alloc_block(cap);
    fights_set_len(copy, len);
    memcpy(&copy[2], &base[2], (size_t)len * sizeof *base);

    return &copy[2];
}


void
fights_delete(fights_list *l, int i)
{
    assert(*l != NULL);
    struct fight **base = fights_base(*l);
    int len = fights_get_len(base);
    assert(i >= 0 && i < len);

    memmove(&base[2 + i], &base[2 + i + 1], (size_t)(len - i - 1) * sizeof *base);
    fights_set_len(base, len - 1);
}


int
fights_len(fights_list l)
{
    struct fight **base = fights_base(l);
    return base ? fights_get_len(base) : 0;
}


int
fights_lookup(fights_list l, struct fight *n)
{
    if (l == NULL)
        return -1;

    int len = fights_len(l);
    int i;
    for (i = 0; i < len; i++)
        if (l[i] == n)
            return i;

    return -1;
}


void
fights_prepend(fights_list *l, struct fight *n)
{
    int len = fights_len(*l);
    fights_ensure_capacity(l, len + 1);

    struct fight **base = fights_base(*l);
    memmove(&base[3], &base[2], (size_t)len * sizeof *base);
    base[2] = n;
    fights_set_len(base, len + 1);
}


void
fights_reclaim(fights_list *l)
{
    if (*l)
        free(fights_base(*l));
    *l = NULL;
}


void
fights_rem_value(fights_list *l, struct fight *n)
{
    int i;
    for (i = 0; i < fights_len(*l); i++)
        if ((*l)[i] == n)
        {
            fights_delete(l, i);
            i--;
        }
}


void
fights_scramble(fights_list l)
{
    fights_shuffle(l);
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
fights_shuffle(fights_list l)
{
    int len = fights_len(l) - 1;
    int i;
    for (i = 0; i < len; i++)
    {
        int r = rnd(i, len);
        if (r != i)
        {
            struct fight *tmp = l[i];
            l[i] = l[r];
            l[r] = tmp;
        }
    }
}


void
fights_test(void)
{
    fights_list l = NULL;
    fights_list c = NULL;
    int i;

    setbuf(stdout, NULL);
    printf("fights_test: starting\n");

    printf("fights_test: len of empty list = %d\n", fights_len(l));
    assert(fights_len(l) == 0);

    enum { N = 100 };
    struct fight *items[N];
    for (i = 0; i < N; i++)
        items[i] = (struct fight *)malloc(1);

    for (i = 0; i < N; i++)
        fights_append(&l, items[i]);

    printf("fights_test: after append, len = %d\n", fights_len(l));
    assert(fights_len(l) == N);

    for (i = 0; i < N; i++)
        assert(l[i] == items[i]);

    c = fights_copy(l);
    assert(fights_len(c) == N);
    for (i = 0; i < N; i++)
    {
        assert(&c[i] != &l[i]);
        assert(c[i] == l[i]);
    }
    printf("fights_test: copy verified\n");

    fights_delete(&l, 50);
    assert(fights_len(l) == N - 1);
    printf("fights_test: after delete, len = %d\n", fights_len(l));

    fights_prepend(&l, items[50]);
    assert(fights_len(l) == N);
    assert(l[0] == items[50]);
    printf("fights_test: after prepend, len = %d\n", fights_len(l));

    assert(fights_lookup(l, items[50]) == 0);
    printf("fights_test: lookup verified\n");

    fights_clear(&l);
    assert(fights_len(l) == 0);
    printf("fights_test: after clear, len = %d\n", fights_len(l));

    fights_reclaim(&l);
    fights_reclaim(&c);
    assert(l == NULL);
    assert(c == NULL);

    for (i = 0; i < N; i++)
        free(items[i]);

    printf("fights_test: all tests passed\n");
}
