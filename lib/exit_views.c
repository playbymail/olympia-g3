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
 *  Reallocing array handler for struct exit_view *
 *
 *  Layout: allocate an array of (struct exit_view *) with 2 hidden slots at the front.
 *    - base[0] stores length (as int via memcpy)
 *    - base[1] stores capacity in total slots (as int via memcpy)
 *    - User-visible list is &base[2], so iterations proceed from index 0.
 *
 *  Uses standard malloc/calloc/realloc/free.
 */

static inline struct exit_view **
exit_views_base(exit_views_list l)
{
    return l ? (l - 2) : NULL;
}

static inline int
exit_views_get_len(struct exit_view **base)
{
    int v = 0;
    memcpy(&v, &base[0], sizeof v);
    return v;
}

static inline void
exit_views_set_len(struct exit_view **base, int v)
{
    memset(&base[0], 0, sizeof base[0]);
    memcpy(&base[0], &v, sizeof v);
}

static inline int
exit_views_get_cap(struct exit_view **base)
{
    int v = 0;
    memcpy(&v, &base[1], sizeof v);
    return v;
}

static inline void
exit_views_set_cap(struct exit_view **base, int v)
{
    memset(&base[1], 0, sizeof base[1]);
    memcpy(&base[1], &v, sizeof v);
}

static struct exit_view **
exit_views_alloc_block(int cap_total_slots)
{
    assert(cap_total_slots >= 3);
    struct exit_view **base = calloc((size_t)cap_total_slots, sizeof *base);
    if (!base)
    {
        fprintf(stderr, "exit_views_alloc_block: out of memory\n");
        exit(1);
    }
    exit_views_set_len(base, 0);
    exit_views_set_cap(base, cap_total_slots);
    return base;
}

static void
exit_views_ensure_capacity(exit_views_list *l, int min_len_needed)
{
    static long loops = 0;
    assert(l != NULL);

    int min_total = min_len_needed + 2;

    if (*l == NULL)
    {
        int cap = ILIST_ALLOC;
        if (cap < 3)
            cap = 3;
        while (cap <= min_total)
            cap *= 2;
        struct exit_view **base = exit_views_alloc_block(cap);
        *l = &base[2];
        return;
    }

    struct exit_view **base = exit_views_base(*l);
    int cap = exit_views_get_cap(base);
    assert(cap != 0);

    if (cap > min_total)
        return;

    size_t old_bytes = (size_t)cap * sizeof *base;
    while (cap <= min_total)
    {
        loops++;
        cap *= 2;
    }

    base = realloc(base, (size_t)cap * sizeof *base);
    if (!base)
    {
        fprintf(stderr, "exit_views_ensure_capacity: out of memory\n");
        exit(1);
    }

    memset((char *)base + old_bytes, 0, (size_t)cap * sizeof *base - old_bytes);
    exit_views_set_cap(base, cap);
    *l = &base[2];
}


void
exit_views_append(exit_views_list *l, struct exit_view *n)
{
    int len = exit_views_len(*l);
    exit_views_ensure_capacity(l, len + 1);

    struct exit_view **base = exit_views_base(*l);
    base[2 + len] = n;
    exit_views_set_len(base, len + 1);
}


void
exit_views_clear(exit_views_list *l)
{
    if (*l)
        exit_views_set_len(exit_views_base(*l), 0);
}


exit_views_list
exit_views_copy(exit_views_list l)
{
    if (!l)
        return NULL;

    struct exit_view **base = exit_views_base(l);
    int len = exit_views_get_len(base);
    int cap = exit_views_get_cap(base);

    struct exit_view **copy = exit_views_alloc_block(cap);
    exit_views_set_len(copy, len);
    memcpy(&copy[2], &base[2], (size_t)len * sizeof *base);

    return &copy[2];
}


void
exit_views_delete(exit_views_list *l, int i)
{
    assert(*l != NULL);
    struct exit_view **base = exit_views_base(*l);
    int len = exit_views_get_len(base);
    assert(i >= 0 && i < len);

    memmove(&base[2 + i], &base[2 + i + 1], (size_t)(len - i - 1) * sizeof *base);
    exit_views_set_len(base, len - 1);
}


int
exit_views_len(exit_views_list l)
{
    struct exit_view **base = exit_views_base(l);
    return base ? exit_views_get_len(base) : 0;
}


int
exit_views_lookup(exit_views_list l, struct exit_view *n)
{
    if (l == NULL)
        return -1;

    int len = exit_views_len(l);
    int i;
    for (i = 0; i < len; i++)
        if (l[i] == n)
            return i;

    return -1;
}


void
exit_views_prepend(exit_views_list *l, struct exit_view *n)
{
    int len = exit_views_len(*l);
    exit_views_ensure_capacity(l, len + 1);

    struct exit_view **base = exit_views_base(*l);
    memmove(&base[3], &base[2], (size_t)len * sizeof *base);
    base[2] = n;
    exit_views_set_len(base, len + 1);
}


void
exit_views_reclaim(exit_views_list *l)
{
    if (*l)
        free(exit_views_base(*l));
    *l = NULL;
}


void
exit_views_rem_value(exit_views_list *l, struct exit_view *n)
{
    int i;
    for (i = 0; i < exit_views_len(*l); i++)
        if ((*l)[i] == n)
        {
            exit_views_delete(l, i);
            i--;
        }
}


void
exit_views_scramble(exit_views_list l)
{
    exit_views_shuffle(l);
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
exit_views_shuffle(exit_views_list l)
{
    int len = exit_views_len(l) - 1;
    int i;
    for (i = 0; i < len; i++)
    {
        int r = rnd(i, len);
        if (r != i)
        {
            struct exit_view *tmp = l[i];
            l[i] = l[r];
            l[r] = tmp;
        }
    }
}


void
exit_views_test(void)
{
    exit_views_list l = NULL;
    exit_views_list c = NULL;
    int i;

    setbuf(stdout, NULL);
    printf("exit_views_test: starting\n");

    printf("exit_views_test: len of empty list = %d\n", exit_views_len(l));
    assert(exit_views_len(l) == 0);

    enum { N = 100 };
    struct exit_view *items[N];
    for (i = 0; i < N; i++)
        items[i] = (struct exit_view *)malloc(1);

    for (i = 0; i < N; i++)
        exit_views_append(&l, items[i]);

    printf("exit_views_test: after append, len = %d\n", exit_views_len(l));
    assert(exit_views_len(l) == N);

    for (i = 0; i < N; i++)
        assert(l[i] == items[i]);

    c = exit_views_copy(l);
    assert(exit_views_len(c) == N);
    for (i = 0; i < N; i++)
    {
        assert(&c[i] != &l[i]);
        assert(c[i] == l[i]);
    }
    printf("exit_views_test: copy verified\n");

    exit_views_delete(&l, 50);
    assert(exit_views_len(l) == N - 1);
    printf("exit_views_test: after delete, len = %d\n", exit_views_len(l));

    exit_views_prepend(&l, items[50]);
    assert(exit_views_len(l) == N);
    assert(l[0] == items[50]);
    printf("exit_views_test: after prepend, len = %d\n", exit_views_len(l));

    assert(exit_views_lookup(l, items[50]) == 0);
    printf("exit_views_test: lookup verified\n");

    exit_views_clear(&l);
    assert(exit_views_len(l) == 0);
    printf("exit_views_test: after clear, len = %d\n", exit_views_len(l));

    exit_views_reclaim(&l);
    exit_views_reclaim(&c);
    assert(l == NULL);
    assert(c == NULL);

    for (i = 0; i < N; i++)
        free(items[i]);

    printf("exit_views_test: all tests passed\n");
}
