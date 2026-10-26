# unnamed-regions — regions with no `Regions` entry

Pins the #273 fix (#279 is a duplicate).

`set_regions()` names a region only when `Regions` seeds it. Every other
region is still numbered (`unnamed land at ...`, `unnamed sea at ...`), but
its `inside_names[]` entry stays NULL. Three places used that name without
checking it:

- `mark_bad_locs()` and `random_tile_from_each_region()`: `strcmp()` against
  "Impassable Mountains"
- `island_allowed()`: a `*p` walk looking for "Deep"

So any unnamed region crashed mapgen-g3 (SIGSEGV, exit 139). An unnamed
region is now never "Impassable Mountains" and never "Deep". The stone-circle
listing on stderr prints its name as `??`, matching `print_continent()`.

This directory's `Regions` is the standard one without the "Great Sea" and
"Orwald" seeds. That leaves an unnamed sea and an unnamed land region. The
rest of the inputs are `tests/mapgen/fixtures`. `EXPECT.sha256` pins `gate`,
`loc`, `road` and stderr. Maps whose regions are all named give the same
output as before.

```bash
./tests/mapgen/regress/unnamed-regions/check.sh           # YES = pass
./tests/mapgen/regress/unnamed-regions/check.sh --update  # refresh EXPECT.sha256 (C build only)
```
