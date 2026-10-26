# map-glyphs — map holes, special glyphs and sea lanes

Pins the #274 and #272 fixes and adds the coverage #276 asks for. It has its
own `Map`, `Regions` and `Land`. `Cities` and `randseed` come from
`tests/mapgen/fixtures`.

## #274: holes at the edge or beside another hole

`bridge_map_hole_sup()` read every neighbor's `mark` before checking for NULL.
`adjacent_tile_sup()` returns NULL for an off-map square and for another `#`
hole, so a hole in row 0, or next to another hole, crashed mapgen-g3 with
SIGSEGV (exit 139). It now uses the guarded `(n && n->mark) || ...` form, as
`bridge_corner_sup()` does. Maps without such holes produce the same output
as before.

## #272: random gates to (r1,c2)

`random_province_gates()` drew two provinces and gated the first to
`map[r1][c2]`: the first one's row with the second one's column. That square
was never filtered by `random_province()`, so the gate could lead into the
ocean, a safe haven or a hole. With this map and seed it is a hole, and
`new_gate()` dereferenced NULL (SIGSEGV, exit 139). It now gates to
`map[r2][c2]`. The draws are unchanged, so only the gate destinations (`tl`
in `gate`) and the gate counts on stderr differ; `loc` and `road` do not.

## What the map covers

`Map` is the standard fixture map with these squares changed (row, col):

| Square | Glyphs | Path |
|---|---|---|
| (0,40) | `#` | hole in row 0; no road (all its neighbors are sea) |
| (39,10-11) | `##` | two adjacent holes; (39,10) is bridged n-s |
| (20,25) | `#` | single hole inside land; bridged e-w |
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

## Why the inputs look like this

When the fixture was built, three behaviors of the C crashed on hand-made
maps. All three are now fixed and pinned by their own fixtures:

- an unnamed region (#273, `unnamed-regions`)
- a `Regions` or `Land` entry naming a hole (#278, `seed-no-province`)
- a boundary square reached by a second region's flood (#281,
  `lone-boundary`)

The fixture still has the workarounds, and its output depends on them. The
boundary glyphs come in pairs (`^v`, `{}`, `][`) with a `Regions` seed on
each side. The `;`, `~` and `"` lanes, each its own color and so its own sea,
are seeded too.

## Run it

```bash
./tests/mapgen/regress/map-glyphs/check.sh           # YES = pass
./tests/mapgen/regress/map-glyphs/check.sh --update  # refresh EXPECT.sha256 (C build only)
MAPGEN_BIN=/path/to/port/mapgen ./tests/mapgen/regress/map-glyphs/check.sh
```
