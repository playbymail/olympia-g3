# use-stealth-refused — refused uses of the stealth skills

Pins the `fail` cells of the stealth skills in use group 2 (issue #192, use
backlog parent #180): every usable stealth skill. `hide_lord` (635) is a
`v_implicit` row, left to group 10.

## Scenario

Two factions start in Greyfell (57081). 301 Absentees stays there with no
orders. The noble of 300 Bunglers, Bungler One [4126], knows the stealth
school and every skill below, and is poofed to Plain [13450], which has no
city or inn, still leading its 25 peasants. Every use passes `v_use`'s
shared checks, reaches its start, and fails there:

| Order | Skill | Start's refusal |
|---|---|---|
| `use 631` | petty_thief | Must be in a city. |
| `use 632 8651`, `use 633 8651`, `use 634 8651` | spy_inv/skills/lord | [8651] cannot be seen here. |
| `use 636` | find_rich | May only be used in an inn. |
| `use 637 8651` | torture | [8651] is not a prisoner of Bungler One. |
| `use 638 1` | hide_self | Must be alone to hide. |
| `use 639` | sneak_build | Must be alone in order to sneak. |

A failed start takes no time, so all eight run on the same day.

## What `check.sh` asserts

1. `use:fail` in the turn's `--coverage` dump, and every skill's `fail`
   cell above in its `--use-coverage` dump.
2. The faction's report and unit state (`save/1/300`, `fact/300`) match `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`use-stealth-refused.lua` builds the scenario with `olyscript-g3`;
`build-scenario.sh` freezes it as `scenario.patch` over the shared base world.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
