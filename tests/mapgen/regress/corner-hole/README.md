# corner-hole — a `#` hole at (`max_row`, `max_col`)

Pins the #287 fix.

`main()` ends by reporting the highest province number:

```c
fprintf(stderr, "highest province = %d\n", map[max_row][max_col]->region);
```

`max_row` and `max_col` are the highest occupied row and column, taken
separately. When the square at that corner is a `#` hole (or the last line of
`Map` is shorter than the widest), `map[max_row][max_col]` is NULL, and
mapgen-g3 crashed (SIGSEGV, exit 139). By then it had written `gate`, `loc`
and `road`, but it had not saved `randseed`.

A province's number depends only on its position (`rc_to_region()`), so the
line now prints `rc_to_region(max_row, max_col)`. That is the same number for
every map that ran before.

This directory's `Map` is the standard map with (79,74-78) land, a hole at
(79,79), and land at (79,0). The hole is bridged east-west across the column
wrap (since #285). `Regions` names the two land areas. The other inputs come
from `tests/mapgen/fixtures`. `EXPECT.sha256` pins `gate`, `loc`, `road`,
stderr and the saved `randseed`.

```bash
./tests/mapgen/regress/corner-hole/check.sh           # YES = pass
./tests/mapgen/regress/corner-hole/check.sh --update  # refresh EXPECT.sha256 (C build only)
```
