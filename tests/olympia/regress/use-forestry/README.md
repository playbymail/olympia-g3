# use-forestry — use of the forestry skills

Pins the `ok` cells of the forestry skills in use group 2 (issue #192, use
backlog parent #180): `make_ram` (701), `harvest_lumber` (702),
`harvest_yew` (703) and `improve_opium` (707). `collect_foliage` (704) and
`harvest_opium` (706) are `v_implicit` rows, left to group 10.

## Scenario

Three factions, 300–302, start in Greyfell (57081) and are poofed to where
their skills work. Each noble knows the forestry school and the skills it
uses:

| Faction | Noble | Place | Setup | Orders |
|---|---|---|---|---|
| 300 Woodcutters | Woodcutter One [4126] | Forest [13451] | 3 wood, 1 iron, 3 workers | `use 701`, `use 702 2` |
| 301 Bowyers | Bowyer One [8651] | Yew grove [62199] | 2 workers | `use 703 2` |
| 302 Poppy Growers | Farmer One [8159] | Poppy field [59084] | — | `use 707` |

Every start returns TRUE. `make_ram` has no start: `v_use` hands it to
`skill_produce`, and on day 14 `d_use` makes a battering ram; the
woodcutter then cuts 2 wood. The bowyer cuts 2 yew. `improve_opium` is
listed under Forestry's subskill 705, so the farmer knows that too.

## What `check.sh` asserts

1. `use:ok` in the turn's `--coverage` dump, and every skill's `ok`
   cell above in its `--use-coverage` dump.
2. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`use-forestry.lua` builds the scenario with `olyscript-g3`;
`build-scenario.sh` freezes it as `scenario.patch` over the shared base world.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
