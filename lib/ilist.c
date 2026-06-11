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

extern void* my_malloc(unsigned size);
extern void* my_realloc(void* ptr, unsigned size);
extern int rnd(int low, int high);

#define FALSE (0)


/*
 *  Reallocing array handler for int
 *
 *  Layout: allocate an array of (int) with 2 hidden slots at the front.
 *    - base[0] stores length (as int via memcpy)
 *    - base[1] stores capacity in total slots (as int via memcpy)
 *    - User-visible list is &base[2], so iterations proceed from index 0.
 *
 *  Uses standard malloc/calloc/realloc/free.
 */

static inline int*
ilist_base(ilist l)
{
    return l ? (l - 2) : NULL;
}

static inline int
ilist_get_len(int* base)
{
    int v = 0;
    memcpy(&v, &base[0], sizeof v);
    return v;
}

static inline void
ilist_set_len(int* base, int v)
{
    memset(&base[0], 0, sizeof base[0]);
    memcpy(&base[0], &v, sizeof v);
}

static inline int
ilist_get_cap(int* base)
{
    int v = 0;
    memcpy(&v, &base[1], sizeof v);
    return v;
}

static inline void
ilist_set_cap(int* base, int v)
{
    memset(&base[1], 0, sizeof base[1]);
    memcpy(&base[1], &v, sizeof v);
}

static int*
ilist_alloc_block(int cap_total_slots)
{
    assert(cap_total_slots >= 3);
    int* base = calloc((size_t)cap_total_slots, sizeof *base);
    if (!base)
    {
        fprintf(stderr, "ilist_alloc_block: out of memory\n");
        exit(1);
    }
    ilist_set_len(base, 0);
    ilist_set_cap(base, cap_total_slots);
    return base;
}

static void
ilist_ensure_capacity(ilist* l, int min_len_needed)
{
    int min_total = min_len_needed + 2;

    if (*l == NULL)
    {
        int cap = ILIST_ALLOC;
        if (cap < 3)
            cap = 3;
        while (cap <= min_total)
            cap *= 2;
        int* base = ilist_alloc_block(cap);
        *l = &base[2];
        return;
    }

    int* base = ilist_base(*l);
    int cap = ilist_get_cap(base);

    if (cap > min_total)
        return;

    size_t old_bytes = (size_t)cap * sizeof *base;
    while (cap <= min_total)
        cap *= 2;

    base = realloc(base, (size_t)cap * sizeof *base);
    if (!base)
    {
        fprintf(stderr, "ilist_ensure_capacity: out of memory\n");
        exit(1);
    }

    memset((char *)base + old_bytes, 0, (size_t)cap * sizeof *base - old_bytes);
    ilist_set_cap(base, cap);
    *l = &base[2];
}


// append without duplication
void
ilist_add(ilist *l, int n)
{
    if (ilist_lookup(*l, n) == -1)
    {
        ilist_append(l, n);
    }
};


void
ilist_append(ilist* l, int n)
{
    int len = ilist_len(*l);
    ilist_ensure_capacity(l, len + 1);

    int* base = ilist_base(*l);
    base[2 + len] = n;
    ilist_set_len(base, len + 1);
}


void
ilist_clear(ilist* l)
{
    if (*l)
        ilist_set_len(ilist_base(*l), 0);
}


ilist
ilist_copy(ilist l)
{
    if (!l)
        return NULL;

    int* base = ilist_base(l);
    int len = ilist_get_len(base);
    int cap = ilist_get_cap(base);

    int* copy = ilist_alloc_block(cap);
    ilist_set_len(copy, len);
    memcpy(&copy[2], &base[2], (size_t)len * sizeof *base);

    return &copy[2];
}


void
ilist_delete(ilist* l, int i)
{
    assert(*l != NULL);
    int* base = ilist_base(*l);
    int len = ilist_get_len(base);
    assert(i >= 0 && i < len);

    memmove(&base[2 + i], &base[2 + i + 1], (size_t)(len - i - 1) * sizeof *base);
    ilist_set_len(base, len - 1);
}


int
ilist_len(ilist l)
{
    int* base = ilist_base(l);
    return base ? ilist_get_len(base) : 0;
}


int
ilist_lookup(ilist l, int n)
{
    if (l == NULL)
        return -1;

    int len = ilist_len(l);
    int i;
    for (i = 0; i < len; i++)
        if (l[i] == n)
            return i;

    return -1;
}


void
ilist_prepend(ilist* l, int n)
{
    int len = ilist_len(*l);
    ilist_ensure_capacity(l, len + 1);

    int* base = ilist_base(*l);
    memmove(&base[3], &base[2], (size_t)len * sizeof *base);
    base[2] = n;
    ilist_set_len(base, len + 1);
}


void
ilist_reclaim(ilist* l)
{
    if (*l)
        free(ilist_base(*l));
    *l = NULL;
}


void
ilist_rem_value(ilist* l, int n)
{
    int i;
    for (i = ilist_len(*l) - 1; i >= 0; i--)
        if ((*l)[i] == n)
            ilist_delete(l, i);
}


void
ilist_rem_value_uniq(ilist* l, int n)
{
    int i;
    for (i = ilist_len(*l) - 1; i >= 0; i--)
        if ((*l)[i] == n)
        {
            ilist_delete(l, i);
            break;
        }
}


void
ilist_scramble(ilist l)
{
    ilist_shuffle(l);
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
ilist_shuffle(ilist l)
{
    int len = ilist_len(l) - 1;
    int i;
    for (i = 0; i < len; i++)
    {
        int r = rnd(i, len);
        if (r != i)
        {
            int tmp = l[i];
            l[i] = l[r];
            l[r] = tmp;
        }
    }
}


void
ilist_test(void)
{
    ilist l = NULL;
    ilist c = NULL;
    int i;

    setbuf(stdout, NULL);
    printf("ilist_test: starting\n");

    printf("ilist_test: len of empty list = %d\n", ilist_len(l));
    assert(ilist_len(l) == 0);

    enum { N = 100 };
    int items[N];
    for (i = 0; i < N; i++)
        items[i] = i + 1;

    for (i = 0; i < N; i++)
        ilist_append(&l, items[i]);

    printf("ilist_test: after append, len = %d\n", ilist_len(l));
    assert(ilist_len(l) == N);

    for (i = 0; i < N; i++)
        assert(l[i] == items[i]);

    c = ilist_copy(l);
    assert(ilist_len(c) == N);
    for (i = 0; i < N; i++)
    {
        assert(&c[i] != &l[i]);
        assert(c[i] == l[i]);
    }
    printf("ilist_test: copy verified\n");

    ilist_delete(&l, 50);
    assert(ilist_len(l) == N - 1);
    printf("ilist_test: after delete, len = %d\n", ilist_len(l));

    ilist_prepend(&l, items[50]);
    assert(ilist_len(l) == N);
    assert(l[0] == items[50]);
    printf("ilist_test: after prepend, len = %d\n", ilist_len(l));

    assert(ilist_lookup(l, items[50]) == 0);
    printf("ilist_test: lookup verified\n");

    ilist_clear(&l);
    assert(ilist_len(l) == 0);
    printf("ilist_test: after clear, len = %d\n", ilist_len(l));

    ilist_reclaim(&l);
    ilist_reclaim(&c);
    assert(l == NULL);
    assert(c == NULL);

    for (i = 0; i < N; i++)
        items[i] = 0;

    printf("ilist_test: all tests passed\n");
}


/*
 *  Reallocing array handler
 *
 *  Length is stored in ilist[0], maximum in ilist[1].
 *  The user-visible ilist is shifted to &ilist[2], so that iterations can proceed from index 0.
 */
