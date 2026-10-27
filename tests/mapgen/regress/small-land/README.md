# small-land — a map too small for mapgen's random picks

Pins the #329 fix. `random_province()`, `not_random_province()` and
`random_island()` in `mapgen/mapgen.c` pick an unmarked square at random:
they count the choices and draw `rnd(1, count)`. When nothing is left the
count is 0, and `rnd(1, 0)` loops forever (#309), so mapgen-g3 hung in
`make_gates()`. `random_island()` looped the same way when every island was
marked.

Now each of them prints a report on stderr and exits 1:

```
random_province: no unmarked province left to choose
random_island: no unmarked island left to choose
```

The check makes no random draw, so every map that ran before gets the same
output.

Each case writes a 20×20 `Map`, its own `Regions` and an empty `Land`.
`Cities` and `randseed` come from `tests/mapgen/fixtures`.

| case | Map | stops in |
|---|---|---|
| one-land | water, one plains square (the issue's repro) | `random_province` |
| few-land | water, a row of five plains squares | `random_province` |
| all-land | plains everywhere, so no water for islands | `random_island` |

Each case must exit 1 within 20 seconds, with its report as the last stderr
line. Before the fix every case hangs. There are no EXPECT files.

```bash
./tests/mapgen/regress/small-land/check.sh        # YES = pass
```
