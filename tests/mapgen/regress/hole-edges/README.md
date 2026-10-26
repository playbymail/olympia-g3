# hole-edges — map holes in the last row and column

Pins the #285 fix.

`bridge_map_holes()` looks for `#` holes and gives each one a hidden road
("Secret pass", "Secret route" or "Old road") between land squares on
opposite sides. It scanned `row < max_row` and `col < max_col`. Those are the
highest occupied row and column, not counts, so holes in the last row or
column were never bridged. It now scans `row <= max_row` and
`col <= max_col`. This is the same off-by-one as #275.

This directory's `Map` is the standard map with three holes added:

| Hole | Land around it | Bridge |
|---|---|---|
| (35,79) | column 79, rows 30-40 | n-s |
| (79,35) | row 79, columns 30-40 | e-w |
| (20,79) | (20,77-78) and (20,0-1) | e-w across the column wrap: `adjacent_tile_sup()` takes column `max_col + 1` to column 0 |

`Regions` names the four new land areas. The other inputs come from
`tests/mapgen/fixtures`. `EXPECT.sha256` pins `gate`, `loc`, `road` and
stderr. The pre-fix build lays none of the three bridges.

As `link_roads()` always does, a road end moves to a non-city sublocation in
the province when there is one. For example, the (20,79) road joins (20,0)
to a cave inside (20,78).

Whether a hole is bridged also depends on `mark`. `bridge_map_hole_sup()`
skips a hole when any neighbor is marked, and gate placement leaves marks.
That applies to every hole, not only these.

A hole in the bottom-right corner (`max_row`, `max_col`) used to crash
`main()`'s "highest province" line (#287), so this fixture leaves the corner
alone. `corner-hole` covers it.

```bash
./tests/mapgen/regress/hole-edges/check.sh           # YES = pass
./tests/mapgen/regress/hole-edges/check.sh --update  # refresh EXPECT.sha256 (C build only)
```
