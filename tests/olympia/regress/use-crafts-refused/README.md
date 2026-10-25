# use-crafts-refused — refused uses of the shipcraft, construction, mining and trade skills

Pins the `fail` cells of the skills in use group 1 (issue #190, use backlog
parent #180): every skill in the four schools except `make_siege` (681).
With no start function, `make_siege` cannot fail: `v_use` counts each use
that passes its shared checks as `ok` (its `fail` cell is `n/a`).

## Scenario

One faction, 300 Bunglers. Its noble, Bungler One [4126], knows the four
schools and every skill below, and is poofed to Plain [13450], which has no
ship, mine, stone, fish or city. Every use passes `v_use`'s shared checks,
reaches its start, and fails there:

| Order | Skill | Start's refusal |
|---|---|---|
| `use 601 east` | pilot_ship | Must be on a sea-worthy ship to sail. |
| `use 602` | shipbuilding | Use the BUILD order to build ships. (always) |
| `use 603 1` | fishing | Fish must be caught in ocean provinces. |
| `use 682 1` | quarry_stone | Stone must be quarried in mountain provinces. |
| `use 721`, `use 722`, `use 723` | mine_iron/gold/mithril | Must be in a mine to extract iron (gold, mithril). |
| `use 732` | find_sell | Must be in a city. |
| `use 733 1` | find_buy | Must be in a city. |

A failed start takes no time, so all nine run on the same day.

## What `check.sh` asserts

1. `use:fail` in the turn's `--coverage` dump, and every skill's `fail` cell
   in its `--use-coverage` dump.
2. The faction's report and unit state (`save/1/300`, `fact/300`) match
   `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`use-crafts-refused.lua` builds the scenario with `olyscript-g3`;
`build-scenario.sh` freezes it as `scenario.patch` over the shared base world.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
