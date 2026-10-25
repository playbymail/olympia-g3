# use-persuasion — use of the persuasion skills

Pins the `ok` cells of the persuasion skills in use group 2 (issue #192,
use backlog parent #180): `bribe_noble` (671), `persuade_oath` (672),
`raise_mob` (673) and `rally_mob` (674). `incite_mob` (675) is covered by
social-bribe, and `train_angry` (676) is a `v_implicit` row, left to group
10.

## Scenario

Three factions, 300–302, start in Greyfell (57081) and are poofed to
provinces with peasants and a mob cookie:

| Faction | Noble | Place | Orders |
|---|---|---|---|
| 300 Persuaders | Persuader One [4126] | Forest [13449] | `use 671 8651 100`, `use 672 8651`, `use 674 101396` |
| 301 Marks | Mark One [8651] | Forest [13449] | — |
| 302 Agitators | Agitator One [8159] | Plain [13450] | `use 673` |

The mob [101396] is seeded in the forest by `oly.mob` (#139), away from the
agitator's plain, as in recruitment-raise. Every start returns TRUE. The
mark is oath-2, so it thanks the persuader for the gift and is not
convinced to join. The mob stacks beneath the persuader, and the agitator
raises an angry peasant mob.

## What `check.sh` asserts

1. `use:ok` in the turn's `--coverage` dump, and every skill's `ok`
   cell above in its `--use-coverage` dump.
2. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`use-persuasion.lua` builds the scenario with `olyscript-g3`;
`build-scenario.sh` freezes it as `scenario.patch` over the shared base world.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
