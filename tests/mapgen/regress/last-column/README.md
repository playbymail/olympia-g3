# last-column — province scans reach the last map column

Pins the #275 fix.

`read_map()` sets `max_col` to the highest occupied column, not a count. Three
scans used `c < max_col` while rows used `r <= max_row`, so they never saw the
last column:

- `random_province()`: no random gate (`random_province_gates()`,
  `gate_province_islands()`, `gate_stone_circles()`, `gate_land_ring()`) could
  land there
- `not_random_province()`: no random city could be placed there
- `mark_bad_locs()`, safe-haven pass: a safe haven there was never marked
  (harmless only while `random_province()` could not pick it)

All three now scan `c <= max_col`.

This directory's `Map` is the standard map with column 79 made land for rows
5-75 and a start city (`9`, a safe haven) at (40,79). Its `Regions` adds
`5,79 Far East`. The other inputs come from `tests/mapgen/fixtures`.
`EXPECT.sha256` pins `gate`, `loc`, `road` and stderr.

With the standard seed, the pre-fix build gates into column 79 only from the
unbounded scans (two gate ends). The fixed build adds random-province gates
there. Neither build gates the safe haven at (40,79), region 14079.

In the standard fixtures column 79 is all ocean, so their output is
unchanged.

```bash
./tests/mapgen/regress/last-column/check.sh           # YES = pass
./tests/mapgen/regress/last-column/check.sh --update  # refresh EXPECT.sha256 (C build only)
```
