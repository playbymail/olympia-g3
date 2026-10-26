# seed-no-province — `Regions`/`Land` entries with no province

Pins the #278 fix.

`set_regions()` and `set_province_clumps()` read `map[row][col]->...` for the
square each `Regions` / `Land` entry names, without checking it. A `#` hole,
or a square past the map's last row or column, is NULL there, and a row or
column outside `0..99` is past the array. Either crashed mapgen-g3 (SIGSEGV,
exit 139). Such an entry is now reported on stderr and skipped:

```
Regions '<name>': no province at (r,c)
Land '<name>': no province at (r,c)
```

This directory's inputs, over `tests/mapgen/fixtures`:

| File | Change |
|---|---|
| `Map` | (0,0) is a `#` hole, so the standard "Great Sea" seed names a hole |
| `Regions` | adds (99,99), past the 80×80 map, and (150,5), past the array |
| `Land` | adds (0,0) (the hole), (150,5) and (-1,3) |

With "Great Sea" skipped, the sea is left unnamed, so this fixture also
depends on the #273 fix. `EXPECT.sha256` pins `gate`, `loc`, `road` and
stderr. Inputs without such entries give the same output as before.

```bash
./tests/mapgen/regress/seed-no-province/check.sh           # YES = pass
./tests/mapgen/regress/seed-no-province/check.sh --update  # refresh EXPECT.sha256 (C build only)
```
