// Copyright (c) 2026 Michael D Henderson. All rights reserved.

//
// Created by Michael Henderson on 1/27/26.
//

#include "checked_alloc.h"

// checked_alloc.c
#include "checked_alloc.h"

#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdalign.h>

// enum {
//     CANARY_HEAD = 0xDEADBEEF,
//     CANARY_TAIL = 0xBABEFACE,
//     CANARY_FREED = 0x0BADF00D
// };
//
// typedef struct {
//     size_t   user_size;     // requested size
//     uint32_t head_canary;   // CANARY_HEAD while live, CANARY_FREED after free
//     // padding happens naturally due to alignment of the struct
// } hdr_t;
//
// static size_t round_up(size_t n, size_t a) {
//     return (n + (a - 1)) & ~(a - 1);
// }
//
// static uint32_t load_u32(const void *p) {
//     uint32_t v;
//     memcpy(&v, p, sizeof(v));
//     return v;
// }
//
// static void store_u32(void *p, uint32_t v) {
//     memcpy(p, &v, sizeof(v));
// }
//
// static void *checked_alloc(size_t user_size) {
//     // Ensure user pointer is aligned for any type.
//     const size_t A = alignof(max_align_t);
//
//     // Layout:
//     // [hdr_t][padding to A][user bytes][tail canary (u32)][padding]
//     size_t hdr_sz = round_up(sizeof(hdr_t), A);
//
//     // overflow checks
//     if (user_size > (SIZE_MAX - hdr_sz - sizeof(uint32_t))) {
//         fprintf(stderr, "my_malloc: size overflow (%zu)\n", user_size);
//         abort();
//     }
//
//     size_t total = hdr_sz + user_size + sizeof(uint32_t);
//
//     // calloc to keep your old "bzero" behavior for the user region
//     unsigned char *base = (unsigned char *)calloc(1, total);
//     if (!base) {
//         fprintf(stderr, "my_malloc: out of memory (can't malloc %zu bytes)\n", user_size);
//         abort();
//     }
//
//     hdr_t h;
//     h.user_size = user_size;
//     h.head_canary = CANARY_HEAD;
//     memcpy(base, &h, sizeof(h));
//
//     unsigned char *user = base + hdr_sz;
//     unsigned char *tailp = user + user_size;
//     store_u32(tailp, CANARY_TAIL);
//
//     return user;
// }
//
// static hdr_t *ptr_to_hdr(void *ptr) {
//     if (!ptr) return NULL;
//     const size_t A = alignof(max_align_t);
//     size_t hdr_sz = round_up(sizeof(hdr_t), A);
//     return (hdr_t *)((unsigned char *)ptr - hdr_sz);
// }
//
// static void check_block(hdr_t *hdr, void *user_ptr) {
//     assert(hdr != NULL);
//
//     // Read header safely (in case someone scribbled on it)
//     hdr_t h;
//     memcpy(&h, hdr, sizeof(h));
//
//     if (h.head_canary == CANARY_FREED) {
//         fprintf(stderr, "my_free/my_realloc: double free detected (%p)\n", user_ptr);
//         abort();
//     }
//
//     assert(h.head_canary == CANARY_HEAD);
//
//     unsigned char *user = (unsigned char *)user_ptr;
//     unsigned char *tailp = user + h.user_size;
//     uint32_t tail = load_u32(tailp);
//     assert(tail == CANARY_TAIL);
// }

void *my_malloc(size_t size) {
    return calloc(1, size);
}

void *my_realloc(void *ptr, size_t size) {
    return realloc(ptr, size);
}

void my_free(const void *ptr) {
    if (!ptr) return;
    free((void*)ptr);
}