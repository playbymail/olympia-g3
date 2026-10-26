# phase-month-close — Uldim pass and Summerbridge close

Pins `special_locs_close:close` of the phase backlog (issue #234, parent
#227). Its pair is `phase-month-open`.

## Scenario

Uldim pass and Summerbridge are open during months 3–6. At the end of month
2 they open, and at the end of month 6 they close. `oly.clock` sets the
saved turn so that the turn the fixture runs is turn 7, which ends month
6. The shipped map has neither place (mapgen makes them from the map's
`]`, `[`, `{` and `}` glyphs), so `oly.pass` marks four provinces around
Greyfell, one for each route, and a noble of its own faction stands in each:

| Faction | Province | Mark |
|---|---|---|
| 300 Northers | Forest [13449] | Summerbridge, passage north (`summer_flag` 1) |
| 301 Southers | Plain [13450] | Summerbridge, passage south (`summer_flag` 2) |
| 302 Southpassers | Forest [13550] | Uldim pass, to the south (`uldim_flag` 3) |
| 303 Northpassers | Plain [13551] | Uldim pass, to the north (`uldim_flag` 4) |

Each province's message is in its noble's report.

## What `check.sh` asserts

1. `special_locs_close:close` acts in the turn's `--phase-coverage` dump.
2. Each faction's report and unit state (`save/7/30x`, `fact/30x`) match
   `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`phase-month-close.lua` builds the scenario with `olyscript-g3`;
`build-scenario.sh` freezes it as `scenario.patch` over the shared base world.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
