# use-persuasion-refused — refused uses of the persuasion skills

Pins the `fail` cells of the persuasion skills in use group 2 (issue #192,
use backlog parent #180): every usable persuasion skill. `train_angry`
(676) is a `v_implicit` row, left to group 10.

## Scenario

Two factions start in Greyfell (57081). 301 Absentees stays there with no
orders. The noble of 300 Bunglers, Bungler One [4126], knows the
persuasion school and every skill below, and stands in a tower [66159] it
built in Greyfell, so the absentee is not here and no mob may be raised.
Every use passes `v_use`'s shared checks, reaches its start, and fails
there:

| Order | Skill | Start's refusal |
|---|---|---|
| `use 671 8651 100` | bribe_noble | [8651] cannot be seen here. |
| `use 672 8651` | persuade_oath | [8651] cannot be seen here. |
| `use 673` | raise_mob | Mobs can only be raised in provinces and cities. |
| `use 674 8651` | rally_mob | [8651] cannot be seen here. |
| `use 675 8651 8651` | incite_mob | [8651] cannot be seen here. |

A failed start takes no time, so all five run on the same day.

## What `check.sh` asserts

1. `use:fail` in the turn's `--coverage` dump, and every skill's `fail`
   cell above in its `--use-coverage` dump.
2. The faction's report and unit state (`save/1/300`, `fact/300`) match `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`use-persuasion-refused.lua` builds the scenario with `olyscript-g3`;
`build-scenario.sh` freezes it as `scenario.patch` over the shared base world.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
