// Copyright (c) 2026 Michael D Henderson. All rights reserved.

//
// Created by Michael Henderson on 1/26/26.
//

#include <assert.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>

#include "ring_buffer.h"

#define		MAX_BUFFER	50
#define		BUF_LEN		2048	/* generic string max length */

/*
 *  ring_printf which returns a char * which does not need to
 *  be freed or	otherwise explicitly reclaimed.
 *
 *  Grabs the next buffer from the circular list, prints
 *  into it, and returns it.  Buffer will eventually be	reused.
 *
 *  Note - the engine is single threaded, so we won't have race
 *  conditions working with the ring buffer.
 */

char*
ring_printf(const char* format, ...)
{
    static char* ring_buffer[MAX_BUFFER];
    static int ring_index = 0;
    static int initialized = 0;

    if (!initialized)
    {
        char* buffer = calloc((size_t)MAX_BUFFER, (size_t)(BUF_LEN + 1));
        if (!buffer)
        {
            abort();
        }

        int i;
        for (i = 0; i < MAX_BUFFER; i++)
        {
            ring_buffer[i] = buffer + (size_t)i * (BUF_LEN + 1);
        }
        initialized = 1;
        ring_index = 0;
    }

    char* buf = ring_buffer[ring_index++];
    if (ring_index >= MAX_BUFFER)
    {
        ring_index = 0;
    }

    va_list args;
    va_start(args, format);
    int n = vsnprintf(buf, BUF_LEN + 1, format, args);
    if (n < 0)
    {
        // encoding/format error
    }
    else if (n > BUF_LEN)
    {
         // truncated
    }
    va_end(args);

    return buf;
}
