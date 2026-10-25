# production-harvest — harvesting and making

Pins the `ok` outcome of every production-family verb (issue #126, backlog
parent #116): `make`, `train`, `quarry`, `stone`, `collect`, `wood`, `yew`,
`mallorn`, `opium`, `catch` and `fish`.

## Scenario

Seven factions, 300–306, start in Greyfell (57081). Each noble is poofed to a
place that holds what it harvests, and given the skill and the workers or
sailors its `harv_tbl` row needs:

| Faction | Noble | Place | Setup | Orders |
|---|---|---|---|---|
| 300 Quarry Guild | Quarryman One [4126] | Mountain [13349] | Stone quarrying | `make 11 2`, `train 11 2`, `quarry 2`, `stone 2`, `collect 78 2` |
| 301 Woodcutters | Woodcutter One [8651] | Forest [13451] | Harvest lumber, 2 workers | `wood 2` |
| 302 Bowyers | Bowyer One [8159] | Yew grove [62199] | Harvest yew, 2 workers | `yew 2` |
| 303 Mallorn Friends | Elf-friend One [7012] | Mallorn grove [74976] | Harvest mallorn wood | `mallorn 1` |
| 304 Poppy Growers | Poppy One [6947] | Swamp [13549] | Harvest opium | `opium 2` |
| 305 Wranglers | Wrangler One [8731] | Plain [13450] | Catch wild horses | `catch 1` |
| 306 Fisherfolk | Fisher One [8761] | Roundship [60294] on Ocean [13350] | Fishing, 2 sailors | `fish 2` |

The quarryman makes its own workers from its 25 peasants (`make 11` needs no
skill), and then quarries with them. `train` is `make`'s alias.

Every harvest verb except `collect` re-parses itself as `collect <item>`, and
the coverage hook counts the verb the player wrote, so `quarry` and `stone`
each count once.

### Daily yield chance

`mallorn`, `catch` and `fish` have a daily yield chance. `econ_harvest`
(`olympia/buy.c`) rolls it for each unit on each day, so a miss one day says
nothing about the next (#132). In this turn the mallorn cutter misses days 1–3
and cuts on day 4, the wrangler catches on day 2, and the fisher catches on
day 3.

Before #132 the roll was keyed on (item, where, turn) only. Every day of the
month drew the same roll, and on Ocean 13351, 13352 and 13452 the fisher would
have fished all month for nothing.

## What `check.sh` asserts

1. Every cell above reaches `ok` in the turn's `--coverage` dump.
2. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match
   `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`production-harvest.lua` builds the scenario with `olyscript-g3`.
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
