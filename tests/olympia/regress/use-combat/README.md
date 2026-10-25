# use-combat — use of the combat skills

Pins the `ok` cells of the combat skills in use group 2 (issue #192, use
backlog parent #180): `fight_to_death` (612), `make_catapult` (613),
`defense` (614), `archery` (615) and `swordplay` (616). Their `fail` cells
are `n/a`: the four starts always return TRUE, and `make_catapult` has no
start. So combat has no refused fixture. `weaponsmith` (617) is a
`v_implicit` row, left to group 10.

## Scenario

One faction, 300 Men at Arms. Its noble, Warrior One [4126], stays in
Greyfell (57081), knows the combat school and the five skills, and has 3
wood and 3 workers for a catapult:

| Order | Skill | Outcome |
|---|---|---|
| `use 612 1` | fight_to_death | Troops break at 50% (instant). |
| `use 613` | make_catapult | No start: `v_use` hands it to `skill_produce`; on day 15 `d_use` makes a catapult from the wood. |
| `use 614` | defense | Defense rating rises. |
| `use 615` | archery | Missile rating rises. |
| `use 616` | swordplay | Starts on day 30 and is still running at turn end. |

## What `check.sh` asserts

1. `use:ok` in the turn's `--coverage` dump, and every skill's `ok`
   cell above in its `--use-coverage` dump.
2. The faction's report and unit state (`save/1/300`, `fact/300`) match `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`use-combat.lua` builds the scenario with `olyscript-g3`;
`build-scenario.sh` freezes it as `scenario.patch` over the shared base world.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
