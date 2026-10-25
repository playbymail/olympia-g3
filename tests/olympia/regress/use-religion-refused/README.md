# use-religion-refused — refused uses of the religion skills

Pins the `fail` cells of the religion skills in use group 2 (issue #192,
use backlog parent #180): `reveal_vision` (751), `last_rites` (752),
`pray` (753), `resurrect` (754) and `remove_bless` (755).
`vision_protect` (756) starts with `v_vision_protect`, which always returns
TRUE, so its `fail` cell is `n/a`.

## Scenario

Two factions start in Greyfell (57081). 301 Absentees stays there with no
orders. The noble of 300 Bunglers, Bungler One [4126], knows the religion
school and every skill below, and is poofed to Plain [13450], which has no
graveyard. It holds no dead body. Every use passes `v_use`'s shared checks
and reaches its start:

| Order | Skill | Start's outcome |
|---|---|---|
| `use 751 1` | reveal_vision | fail: [1] is not a unique item. |
| `use 752 8651` | last_rites | fail: Must be performed in a graveyard. |
| `use 753` | pray | ok: the ritual is prepared (3 days). |
| `use 753` | pray | fail: Have already completed a preparatory ritual. |
| `use 754 8651` | resurrect | fail: Don't have any body [8651]. |
| `use 755 8651` | remove_bless | fail: [8651] cannot be seen here. |

`pray` can only fail once a ritual is prepared, so the first `use 753`
succeeds; the fixture asserts only the `fail` cells.

## What `check.sh` asserts

1. `use:fail` in the turn's `--coverage` dump, and every skill's `fail`
   cell above in its `--use-coverage` dump.
2. The faction's report and unit state (`save/1/300`, `fact/300`) match `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`use-religion-refused.lua` builds the scenario with `olyscript-g3`;
`build-scenario.sh` freezes it as `scenario.patch` over the shared base world.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
