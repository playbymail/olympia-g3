# use-crafts — use of the shipcraft, construction, mining and trade skills

Pins the `ok` cells of the skills in use group 1 (issue #190, use backlog
parent #180): `pilot_ship` (601), `fishing` (603), `make_siege` (681),
`quarry_stone` (682), `mine_iron` (721), `mine_gold` (722), `mine_mithril`
(723) and `find_sell` (732). `find_buy` (733) is covered by trade-routes, and
`shipbuilding` (602) has no `ok`: `v_shipbuild` always fails.

## Scenario

Six factions, 300–305, start in Greyfell (57081). Each noble knows its
school and the skills it uses, and has what each skill's start needs:

| Faction | Noble | Place | Setup | Orders |
|---|---|---|---|---|
| 300 Ferry Line | Captain One [4126] | Roundship [66761] in Greyfell | Sailing, 8 sailors, no peasants | `use 601 east` |
| 301 Fisherfolk | Fisher One [8651] | Roundship [61857] on Ocean [13350] | Fishing, 2 sailors | `use 603 2` |
| 302 Siege Works | Wright One [8159] | Greyfell | Construct siege tower, 3 wood, 3 leather, 3 workers | `use 681` |
| 303 Quarry Guild | Quarryman One [7012] | Mountain [13349] | Stone quarrying, 2 workers | `use 682 2` |
| 304 Deep Delvers | Miner One [6947] | Mine [59352], depth 4, on Mountain [13349] | the three mining skills, 20 workers | `use 721`, `use 722`, `use 723` |
| 305 Merchants | Trader One [8731] | Greyfell | Find tradegood for sale | `use 732` |

Every start returns TRUE. `make_siege` has no start function: `v_use` hands
it to `skill_produce`, and 14 days on `d_use` consumes the wood and leather
and makes a siege tower. The trader finds rose perfume for sale in Greyfell.

### The mine

A mine `oly.makeloc` creates has no shaft, and the month-end
`mine_production` asserts a depth above zero, so the script sinks it with
`oly.mine_depth` (#190) to depth 4. That is the shallowest depth with
mithril, and the binding stocks the mine as a finished `build mine` is
stocked. The three 7-day digs yield 8 iron, 500 gold and 1 mithril.

A mine's daily cave-in chance grows with its depth. This one caves in three
times and kills six workers, so the miner starts with 20 and still has the
ten each dig needs. With 10, `use 722` lost its workers mid-dig and
`use 723` failed.

## What `check.sh` asserts

1. `use:ok` in the turn's `--coverage` dump, and every skill cell above in
   its `--use-coverage` dump.
2. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match
   `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`use-crafts.lua` builds the scenario with `olyscript-g3`.
`build-scenario.sh` runs it on the bare map and freezes the result as
`scenario.patch` over the shared base world, taking `world.tgz`'s `lib/log`
as production-harvest does.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
