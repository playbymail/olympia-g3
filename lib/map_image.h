/*
 * map_image.h -- render a glyph grid as an uncompressed 24-bit BMP image.
 *
 * A dependency-free debugging aid (issue #81): turn a generated `Map` glyph
 * grid into a raster image so a world can be eyeballed at a glance instead of
 * squinting at ASCII.  The glyph->color palette (the only map-specific
 * knowledge) lives in map_image.c, mirroring genesis.c's ocean_color().
 *
 * This module is intentionally self-contained -- it pulls in nothing but
 * <stdio.h>/<stdint.h>/<stddef.h>.  In particular it does NOT touch the engine
 * headers or the RNG, so genesis-g3 (which links a minimal source set with its
 * own PCG, not the engine's MD5 rng) can use it without dragging in the rest of
 * the engine.  It is a pure debugging output and never affects engine output or
 * the golden gates.
 */

#ifndef OLYMPIA_MAP_IMAGE_H
#define OLYMPIA_MAP_IMAGE_H

#include <stddef.h>

/*
 * Write `grid` (a `width` x `width` square glyph grid, row-major, `grid[r*width+c]`)
 * to `path` as an uncompressed 24-bit BMP.
 *
 *   width   number of provinces per axis (the map is square; 10..99 for genesis,
 *           but any width >= 1 is accepted).
 *   pixels  N x N pixels per province cell, 1 <= pixels <= 64.
 *   grid_n  black grid-line thickness in pixels between/around cells,
 *           0 <= grid_n <= 4 (0 = no grid lines).
 *
 * The grid lines ADD to the image size; per axis the total is
 *   width*pixels + (width+1)*grid_n
 * (with grid_n == 0 this reduces to width*pixels).
 *
 * Returns 0 on success, non-zero on a bad argument or any I/O failure.
 */
int map_image_write_bmp(const char *path, const char *grid, int width,
			int pixels, int grid_n);

#endif /* OLYMPIA_MAP_IMAGE_H */
