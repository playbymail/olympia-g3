#ifndef MAPGEN_PROTO_H
#define MAPGEN_PROTO_H

/*
 *  proto.h -- generated ANSI prototypes for cross-file (non-static)
 *  functions, extracted from their definitions (Phase 4 modernization).
 *  Eliminates -Wmissing-prototypes at the definitions and
 *  -Wimplicit-function-declaration at the call sites.
 */

struct tile;			/* defined privately in mapgen.c */

/* mapgen/mapgen.c */
extern char *name_guild(int skill);
extern int add_road(struct tile *from, int to_loc, int hidden, char *name);
extern int alloc_inside(void);
extern int bridge_caddy_corners(void);
extern int bridge_corner_sup(int row, int col);
extern int bridge_map_hole_sup(int row, int col);
extern int bridge_map_holes(void);
extern int bridge_mountain_ports(void);
extern int bridge_mountain_sup(int row, int col);
extern int clear_alloc_flag(void);
extern int clear_province_marks(void);
extern int clear_subloc_marks(void);
extern int count_cities(void);
extern int count_continents(void);
extern int count_subloc_coverage(void);
extern int count_sublocs(void);
extern int count_tiles(void);
extern int create_a_building(int sl, int hidden, int kind);
extern int create_a_city(int row, int col, char *name, int major);
extern int create_a_graveyard(int row, int col);
extern int create_a_subloc(int row, int col, int hidden, int kind);
extern int dir_assert(void);
extern int dump_continents(void);
extern int dump_gates(void);
extern int dump_roads(void);
extern int fix_terrain_land(void);
extern int flood_land_clumps(int row, int col, char *name);
extern int flood_land_inside(int row, int col, int ins);
extern int flood_water_inside(int row, int col, int ins);
extern int gate_continental_tour(void);
extern int gate_land_ring(int rings);
extern int gate_link_islands(int rings);
extern int gate_province_islands(int times);
extern int gate_stone_circles(void);
extern int is_port_city(int row, int col);
extern int island_allowed(int row, int col);
extern int link_roads(struct tile *from, struct tile *to, int hidden, char *name);
extern int make_gates(void);
extern int make_graveyards(void);
extern int make_islands(void);
extern int make_roads(void);
extern int map_init(void);
extern int mark_bad_locs(void);
extern int new_gate(struct tile *from, struct tile *to, int key);
extern int not_place_random_subloc(int kind, int hidden);
extern int open_fps(void);
extern int place_random_subloc(int kind, int hidden, int terr);
extern int place_sublocations(void);
extern int print_continent(int i);
extern int print_inside_locs(int n);
extern int print_inside_sublocs(int flag, int row, int col);
extern int print_map(void);
extern int print_subloc_gates(int n);
extern int print_sublocs(void);
extern int prov_dest(struct tile *t, int dir);
extern int random_island(void);
extern int random_province_gates(int n);
extern int randomize_dir_vector(void);
extern int rc_to_region(int row, int col);
extern int read_map(void);
extern int region_col(int where);
extern int region_row(int where);
extern int rnd_alloc_num(int low, int high);
extern int unnamed_province_clumps(void);
extern struct tile *adjacent_tile_sup(int row, int col, int dir);
extern struct tile *adjacent_tile_terr(int row, int col);
extern struct tile *adjacent_tile_water(int row, int col);
extern struct tile *choose_random_stone_circle(tiles_list l, struct tile *avoid1, struct tile *avoid2);
extern tiles_list random_tile_from_each_region(void);
extern tiles_list shift_tour_endpoints(tiles_list l);
extern void make_appropriate_subloc(int row, int col);
extern void not_random_province(int *row, int *col);
extern void set_province_clumps(void);
extern void set_regions(void);

#endif
