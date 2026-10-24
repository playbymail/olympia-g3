# social-refused — social orders that fail or are refused

Pins the `fail` and `rejected` outcomes of `bribe`, `incite` and
`terrorize` (issue #146, backlog parent #116).

## Scenario

Three factions start in Greyfell (57081); two are poofed to Catchclaw
[58706], which has a seeded garrison, Garrison [1009]:

| Faction | Noble | Set up |
|---|---|---|
| 300 Bunglers | Bungler One [4126] | Catchclaw; no social skill |
| 301 Schemers | Schemer One [8651] | Catchclaw; knows Bribe noble [671] and Incite mob [675]; 200 gold |
| 302 Terrorizers | Terrorizer One [8159] | Greyfell; forms Hireling [9655] |

| Unit | Order | Day | Fails with |
|---|---|---|---|
| bungler | `bribe 8651 100` | 1 | BRIBE requires knowledge of Bribe noble. |
| bungler | `incite 8651 8651` | 1 | Requires Incite mob violence. |
| bungler | `terrorize 8651 3` | 1 | [8651] does not belong to our faction. |
| schemer | `bribe 1009 100` | 2 | NPC's cannot be bribed. |
| schemer | `bribe 4126 0` | 2 | Must specify an amount of gold to use as a bribe. |
| schemer | `bribe 4126 500` | 2 | Don't have 500 gold for a bribe. |
| schemer | `incite 4126 4126` | 2 | Bungler One is not a peasant mob. |
| schemer | `incite 4126 57081` | 2 | [d21] is not here. |
| hireling | `terrorize 8159 3` | 8 | Unit to be terrorized must be stacked beneath us. |
| hireling | `terrorize 8159 3` | 16 | Units of fear loyalty may not terrorize. |

The terrorizer forms the hireling (day 8, stacked beneath it) and
terrorizes it (`ok`; fear-3 on day 14). The hireling's first terrorize
targets its own leader, which is not beneath it. It then waits for day 15
and tries again, now fear-loyal.

Rejected: all three verbs are for nobles (`c`, and `cr` for `terrorize`),
so the Bunglers' player entity orders all three, and `check_allow()`
refuses each.

Not reached: bribing a noble that switched lords this month (only a
desertion sets `new_lord`: a won bribe, persuade or prisoner terror),
bribing a unit of your own faction, inciting a mob stacked under a leader,
terrorizing an oath-bound vassal, and the prisoner paths of `terrorize`
(not your prisoner, an NPC prisoner).

## What `check.sh` asserts

1. Each of the three verbs reaches `fail` and `rejected` in the turn's
   `--coverage` dump.
2. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match
   `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`social-refused.lua` builds the scenario with `olyscript-g3`.
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
