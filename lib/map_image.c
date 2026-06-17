/*
 * map_image.c -- render a glyph grid as an uncompressed 24-bit BMP (issue #81).
 *
 * Self-contained: stdio + stdint only.  No engine headers, no RNG -- so the
 * minimal-source-set tools (genesis-g3 links its own PCG, not lib/rnd.c/rng.c)
 * can use it.  A debugging aid emitted only on demand; it never touches engine
 * output or the golden gates.
 *
 * The glyph->color palette is the only map-specific knowledge and lives here,
 * mirroring genesis.c's ocean_color()/is_ocean_glyph() and the mapgen.c reader's
 * `case` labels.  The four ocean blues ascend in lightness so distinct seas read
 * apart; sea-lane variants share their plain counterpart's color; unmapped
 * glyphs render magenta so holes/unknown stand out.
 */

#include <stdio.h>
#include <stdint.h>
#include <stddef.h>

#include "map_image.h"

/* An RGB triple (stored R,G,B; written to the BMP as B,G,R). */
struct rgb {
	unsigned char r, g, b;
};

/*
 * Glyph -> color.  Covers every glyph genesis-g3 and mapgen-g3 can emit:
 *
 *   - genesis.c writes the four plain ocean glyphs (',' '.' ' ' '\''), 'o'
 *     (random-terrain fill), 'M' (mountain), and 'O' (Mt. Olympus).
 *   - mapgen.c's reader additionally tolerates the sea-lane ocean variants
 *     (';' ':' '~' '"'), the lower/upper terrain pairs (p/P d/D m/M s/S f/F),
 *     start-city digits '0'..'9', and the special region-boundary features
 *     '^' 'v' '{' '}' ']' '[' plus the '*'/'%' city markers.
 *
 * The spec (issue #81) pins exact RGB for the core set; the extra mapgen-only
 * glyphs are mapped to the nearest sensible color (uppercase terrain == its
 * lowercase, every start-city digit == the '0' gold, special features == their
 * underlying terrain) so a mapgen-authored map renders sensibly rather than
 * speckling magenta.  Magenta is reserved strictly for genuinely unknown glyphs.
 */
static struct rgb
glyph_color(char c)
{
	switch (c) {
	/* --- Ocean (mirror genesis.c ocean_color); sea-lane variant shares. --- */
	case ',': case ';':	return (struct rgb){   0,   0, 160 };	/* ocean 1 */
	case '.': case ':':	return (struct rgb){   0,  80, 220 };	/* ocean 2 */
	case ' ': case '~':	return (struct rgb){  40, 140, 255 };	/* ocean 3 */
	case '\'': case '"':	return (struct rgb){ 120, 200, 255 };	/* ocean 4 */

	/* --- Land / features (spec palette). --- */
	case 'p':		return (struct rgb){  96, 176,  80 };	/* plains */
	case 'f':		return (struct rgb){  32,  96,  32 };	/* forest */
	case 'm': case 'M':	return (struct rgb){ 128, 128, 128 };	/* mountain */
	case 'd':		return (struct rgb){ 210, 180, 140 };	/* desert */
	case 's':		return (struct rgb){ 107, 142,  35 };	/* swamp */
	case 'O':		return (struct rgb){ 255,   0,   0 };	/* Mt. Olympus */
	case 'o':		return (struct rgb){ 200, 200, 120 };	/* random fill */
	case '0':		return (struct rgb){ 255, 215,   0 };	/* starting city */

	/*
	 * --- mapgen-only extras (not in the spec table; nearest sensible color).
	 * Uppercase terrain variants mirror their lowercase color.
	 */
	case 'P':		return (struct rgb){  96, 176,  80 };	/* plains */
	case 'D':		return (struct rgb){ 210, 180, 140 };	/* desert */
	case 'S':		return (struct rgb){ 107, 142,  35 };	/* swamp */
	case 'F':		return (struct rgb){  32,  96,  32 };	/* forest */

	/* Every named/random start-city digit renders as the '0' gold. */
	case '1': case '2': case '3': case '4': case '5':
	case '6': case '7': case '8': case '9':
				return (struct rgb){ 255, 215,   0 };	/* start city */

	/* Region-boundary specials: mapgen makes these mountain or swamp terrain. */
	case '^': case 'v': case '{': case '}':
				return (struct rgb){ 128, 128, 128 };	/* mountain pass */
	case ']': case '[':	return (struct rgb){ 107, 142,  35 };	/* Summerbridge swamp */

	/* '*'/'%' are bare-land city markers (terr_land); show as plains green. */
	case '*': case '%':	return (struct rgb){  96, 176,  80 };

	default:		return (struct rgb){ 255,   0, 255 };	/* unknown -> magenta */
	}
}

/* Little-endian field writers -- never fwrite a struct (padding/endianness). */
static void
put_u16(FILE *fp, uint16_t v)
{
	fputc((int)(v & 0xff), fp);
	fputc((int)((v >> 8) & 0xff), fp);
}

static void
put_u32(FILE *fp, uint32_t v)
{
	fputc((int)(v & 0xff), fp);
	fputc((int)((v >> 8) & 0xff), fp);
	fputc((int)((v >> 16) & 0xff), fp);
	fputc((int)((v >> 24) & 0xff), fp);
}

int
map_image_write_bmp(const char *path, const char *grid, int width,
		    int pixels, int grid_n)
{
	FILE *fp;
	int dim;		/* image side, pixels */
	uint32_t row_bytes;	/* unpadded BGR bytes per row */
	uint32_t pad;		/* zero-pad bytes to a 4-byte boundary */
	uint32_t padded;	/* padded bytes per row */
	uint32_t pixel_bytes;	/* total pixel data */
	uint32_t file_size;
	int px, py;		/* image pixel coordinates */
	const struct rgb grid_rgb = { 0, 0, 0 };	/* grid lines: black */

	if (!path || !grid)
		return 1;
	if (width < 1 || pixels < 1 || pixels > 64 || grid_n < 0 || grid_n > 4)
		return 1;

	/*
	 * Per axis: width cells of `pixels`, with (width+1) grid lines of grid_n
	 * between and around them.  With grid_n == 0 this is just width*pixels.
	 * Guard the arithmetic against overflow before it grows (width<=99,
	 * pixels<=64, grid_n<=4 keeps dim tiny in practice, but be defensive).
	 */
	if ((int64_t)width * pixels + (int64_t)(width + 1) * grid_n > 1000000)
		return 1;
	dim = width * pixels + (width + 1) * grid_n;

	row_bytes = (uint32_t)dim * 3u;
	pad = (4u - (row_bytes & 3u)) & 3u;
	padded = row_bytes + pad;
	pixel_bytes = padded * (uint32_t)dim;
	file_size = 14u + 40u + pixel_bytes;	/* file + info header + pixels */

	fp = fopen(path, "wb");
	if (!fp)
		return 1;

	/* --- BITMAPFILEHEADER (14 bytes) --- */
	fputc('B', fp);
	fputc('M', fp);
	put_u32(fp, file_size);
	put_u16(fp, 0);			/* bfReserved1 */
	put_u16(fp, 0);			/* bfReserved2 */
	put_u32(fp, 14u + 40u);		/* bfOffBits -- pixels start after headers */

	/* --- BITMAPINFOHEADER (40 bytes) --- */
	put_u32(fp, 40u);		/* biSize */
	put_u32(fp, (uint32_t)dim);	/* biWidth */
	put_u32(fp, (uint32_t)dim);	/* biHeight (positive -> bottom-up rows) */
	put_u16(fp, 1);			/* biPlanes */
	put_u16(fp, 24);		/* biBitCount */
	put_u32(fp, 0);			/* biCompression = BI_RGB */
	put_u32(fp, pixel_bytes);	/* biSizeImage */
	put_u32(fp, 0);			/* biXPelsPerMeter */
	put_u32(fp, 0);			/* biYPelsPerMeter */
	put_u32(fp, 0);			/* biClrUsed */
	put_u32(fp, 0);			/* biClrImportant */

	/*
	 * Pixel data, bottom-up (BMP rows run bottom-to-top).  Map an image pixel
	 * (px,py) -- with py measured top-down -- to a cell or a grid line.  Within
	 * a cell, look up the glyph color; otherwise paint a black grid line.
	 *
	 * Cell/grid layout per axis: a repeating [grid_n][pixels] block, then a
	 * trailing grid_n.  A coordinate landing in the leading grid_n of a block,
	 * or in the trailing border, is a grid line.
	 */
	for (py = dim - 1; py >= 0; py--) {	/* bottom row first */
		for (px = 0; px < dim; px++) {
			int cell_x = -1, cell_y = -1;
			struct rgb col;
			int t;

			/* Resolve px -> cell column (or grid line, cell_x == -1). */
			t = px % (pixels + grid_n);
			if (px < (width * pixels + (width + 1) * grid_n) &&
			    t >= grid_n && (px / (pixels + grid_n)) < width)
				cell_x = px / (pixels + grid_n);

			t = py % (pixels + grid_n);
			if (py < (width * pixels + (width + 1) * grid_n) &&
			    t >= grid_n && (py / (pixels + grid_n)) < width)
				cell_y = py / (pixels + grid_n);

			if (cell_x >= 0 && cell_y >= 0)
				col = glyph_color(grid[cell_y * width + cell_x]);
			else
				col = grid_rgb;

			fputc(col.b, fp);	/* BGR order */
			fputc(col.g, fp);
			fputc(col.r, fp);
		}
		for (px = 0; px < (int)pad; px++)
			fputc(0, fp);		/* row pad to 4-byte boundary */
	}

	if (ferror(fp)) {
		fclose(fp);
		return 1;
	}
	if (fclose(fp) != 0)
		return 1;

	return 0;
}
