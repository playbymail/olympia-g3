# use-forestry-refused — refused uses of the forestry skills

Pins the `fail` cells of the forestry skills in use group 2 (issue #192,
use backlog parent #180): `harvest_lumber` (702), `harvest_yew` (703) and
`improve_opium` (707). `make_ram` (701) has no start, so it cannot fail.
`collect_foliage` (704) and `harvest_opium` (706) are `v_implicit` rows,
left to group 10.

## Scenario

One faction, 300 Bunglers. Its noble, Bungler One [4126], knows the
forestry school and every skill below, and is poofed to Plain [13450],
which has no lumber, yew or poppy field. Every use passes `v_use`'s shared
checks, reaches its start, and fails there:

| Order | Skill | Start's refusal |
|---|---|---|
| `use 702 1` | harvest_lumber | Wood must be cut in forest provinces. |
| `use 703 1` | harvest_yew | Yew must be cut in yew groves |
| `use 707` | improve_opium | Opium is produced only in poppy fields. |

## What `check.sh` asserts

1. `use:fail` in the turn's `--coverage` dump, and every skill's `fail`
   cell above in its `--use-coverage` dump.
2. The faction's report and unit state (`save/1/300`, `fact/300`) match `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`use-forestry-refused.lua` builds the scenario with `olyscript-g3`;
`build-scenario.sh` freezes it as `scenario.patch` over the shared base world.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
