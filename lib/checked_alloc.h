// Copyright (c) 2026 Michael D Henderson. All rights reserved.

//
// Created by Michael Henderson on 1/27/26.
//

#ifndef OLYMPIA_CHECKED_ALLOC_H
#define OLYMPIA_CHECKED_ALLOC_H

#include <stddef.h>

void *my_malloc(size_t size);
void *my_realloc(void *ptr, size_t size);
void  my_free(const void *ptr);

#endif //OLYMPIA_CHECKED_ALLOC_H
