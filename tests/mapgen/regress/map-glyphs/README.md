# map-glyphs — map holes, special glyphs and sea lanes

Pins the #274 fix and adds the coverage #276 asks for. It has its own `Map`,
`Regions`, `Land` and `randseed`. `Cities` comes from `tests/mapgen/fixtures`.

## #274: holes at the edge or beside another hole

`bridge_map_hole_sup()` read every neighbor's `mark` before checking for NULL.
`adjacent_tile_sup()` returns NULL for an off-map square and for another `#`
hole, so a hole in row 0, or next to another hole, crashed mapgen-g3 with
SIGSEGV (exit 139). It now uses the guarded `(n && n->mark) || ...` form, as
`bridge_corner_sup()` does. Maps without such holes produce the same output
as before.

## What the map covers

`Map` is the standard fixture map with these squares changed (row, col):

| Square | Glyphs | Path |
|---|---|---|
| (0,40) | `#` | hole in row 0; no road (all its neighbors are sea) |
| (39,10-11) | `##` | two adjacent holes; (39,10) is bridged n-s |
| (20,25) | `#` | single hole inside land; bridged n-s |
| (1,10-13) | `;:~"` | sea lanes, `sl 1` in `loc` |
| (2,36-48) | `ppp^vppp{}ppp` | Uldim squares, `uf 1`-`uf 4`; `region_boundary` stops `flood_land_inside()` |
| (2,58) | `*` | named city alone in the sea; `fix_terrain_land()` can't infer a terrain and assumes forest |
| (10,18) | `*` | named city inside land; the terrain is inferred |
| (77,30-37) | `sss][sss` | Summerbridge squares, `sf 1`, `sf 2` |

`Regions` adds a seed for each new region, and a second seed at (2,37), which
the "Uldim West" flood has already claimed. That gives the `collision between`
message. `Land` adds `2,36 f Westpass` over a `p` square, which gives the
`Land '...' expects` message.

`EXPECT.sha256` pins `gate`, `loc`, `road` and stderr. Those two messages
appear only on stderr.

## Constraints on hand-made maps

The fixture works around three behaviors of the C that are still in place:

- **Boundary squares come in pairs, and each side needs its own `Regions`
  seed.** A boundary square takes the region of the first flood that reaches
  it and stops there. A later flood from the other side then finds it claimed
  and asserts. Land on each side may touch only its own square of the pair,
  and its seed must flood before the row-major unnamed-region scan reaches
  the boundary square.
- **Every region must be named in `Regions`.** Unnamed regions keep a NULL
  `inside_names[]` entry, and `make_gates()` passes it to `strcmp()`. The
  `;`, `~` and `"` lanes each have their own color, so each one is a separate
  sea and gets a seed.
- **The seed is chosen.** `random_province_gates()` links `map[r1][c1]` to
  `map[r1][c2]` (row of the first pick, column of the second). On a map with
  holes, that square can be a hole, and `new_gate()` dereferences NULL. Seed
  `S000000000000001` does not hit this.

## Run it

```bash
./tests/mapgen/regress/map-glyphs/check.sh           # YES = pass
./tests/mapgen/regress/map-glyphs/check.sh --update  # refresh EXPECT.sha256 (C build only)
MAPGEN_BIN=/path/to/port/mapgen ./tests/mapgen/regress/map-glyphs/check.sh
```
