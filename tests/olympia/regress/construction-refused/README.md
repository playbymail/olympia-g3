# construction-refused — construction orders that fail or are refused

Pins the `fail` and `rejected` outcomes of `build`, `improve` and `repair`
(issue #147, backlog parent #116).

## Scenario

Four factions start in Greyfell (57081). `oly.makeloc` makes a castle,
Castle [74301], and a tower, Tower [73052], in the city:

| Faction | Noble | Set up |
|---|---|---|
| 300 Bunglers | Bungler One [4126] | in the castle; no Construction, no workers |
| 301 Masons | Mason One [8651] | Greyfell; knows Construction [680]; no stone |
| 302 Keepers | Keeper One [8159] | in the castle; 1 worker, no stone |
| 303 Menders | Mender One [7012] | in the tower; 80 workers |

| Unit | Order | Day | Fails with |
|---|---|---|---|
| bungler | `build` | 1 | Must specify what to build. |
| bungler | `build palace` | 1 | Don't know how to build 'palace'. |
| bungler | `build tower` | 1 | Building a tower requires Construction [680]. |
| bungler | `improve` | 1 | Need at least one worker [11]. |
| bungler | `repair` | 1 | Need at least one worker [11]. |
| mason | `build tower` | 1 | Need 20 stone [78] to start. |
| mason | `build castle` | 1 | Building is not permitted in safe havens. |
| mason | `improve` | 1 | Not in a castle. |
| mason | `repair` | 1 | Greyfell [d21] may not be repaired. |
| keeper | `improve` | 1 | 50 stone [78] required to proceed with improvement to level one. |
| mender | `repair` | 3 | Tower [s052] is not damaged. |

A tower made by `oly.makeloc` has defense 0, under the tower default of 40,
so the mender's first `repair` starts (`ok`): 80 workers restore 40 points
(2 worker-days each) on its first day, day 2. Its second `repair` finds the
tower whole. The bungler's `build tower` mints an unformed id before the
skill check fails (`v_build` mints first).

Rejected: all three verbs are for nobles (`c`), so the Bunglers' player
entity orders all three, and `check_allow()` refuses each.

Not reached: a castle already at level six (nothing in `oly` sets a castle
level), a ship repair without glue, too many towers in a castle, and the
`d_` failures that halt work already started (no workers left, no stone for
the next fifth, the unit left the building). Those are `d_` outcomes, not
`fail` cells.

## What `check.sh` asserts

1. Each of the three verbs reaches `fail` and `rejected` in the turn's
   `--coverage` dump.
2. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match
   `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`construction-refused.lua` builds the scenario with `olyscript-g3`.
`build-scenario.sh` runs it on the bare map and freezes the result as
`scenario.patch` over the shared base world. The script never runs the `-a`
pass, so `build-scenario.sh` also swaps in `world.tgz`'s `lib/log`; a turn
deletes `lib/log` before it writes anything, so it is not turn input.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
