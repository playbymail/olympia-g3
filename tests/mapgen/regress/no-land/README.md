# no-land — a map with no land region

Pins the #328 fix. `gate_continental_tour()` in `mapgen/mapgen.c` takes one
random tile from each land region. On a map with no land region the list is
empty (NULL). The tour loop doesn't run, and the closing line read `l[0]`
through NULL, so mapgen-g3 died with SIGSEGV (exit 139) just after printing
`Continental gate tour:`.

Now it prints `the map has no land region` on stderr and exits 1.

Each case writes a 20×20 `Map`, a `Regions` naming only the sea, and an empty
`Land`. `Cities` and `randseed` come from `tests/mapgen/fixtures`.

| case | every square |
|---|---|
| water | `,` (the issue's repro) |
| holes | `#` |

Each case must exit 1 with `the map has no land region` as its last stderr
line. There are no EXPECT files.

```bash
./tests/mapgen/regress/no-land/check.sh           # YES = pass
```
