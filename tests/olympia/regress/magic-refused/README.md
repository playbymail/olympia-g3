# magic-refused — magic orders that fail or are refused

Pins the `fail` and `rejected` outcomes of `trance`, `breed` and `bind`
(issue #149, backlog parent #116).

## Scenario

Four factions start in Greyfell (57081), a safe haven:

| Faction | Noble | Set up |
|---|---|---|
| 300 Bunglers | Bungler One [4126] | stays in Greyfell, no skills |
| 301 Breeders | Breeder One [8651] | stays in Greyfell; knows Beastmastery [650] and Breed beasts [654]; one ox [76] |
| 302 Landlubbers | Landlubber One [8159] | knows Magic, Weather magic, Bind storm, Summon wind (4 aura); poofed to Plain [13450] |
| 303 Paupers | Pauper One [7012] | knows Magic, Weather magic, Bind storm, Summon rain (4 aura); aboard Roundship [74301] in Ocean [13351] |

| Unit | Order | Day | Fails with |
|---|---|---|---|
| bungler | `trance` | 1 | Requires knowledge of Trance [921]. |
| bungler | `breed 10 76` | 1 | Requires Breed beasts [654]. |
| bungler | `bind 57081` | 1 | Bungler One [4126] doesn't control any storm [d21]. |
| breeder | `breed 10` | 1 | Usage: breed &lt;item&gt; &lt;item&gt; |
| breeder | `breed 57081 10` | 1 | 57081 is not an item. |
| breeder | `breed 10 51` | 1 | Don't have any [51]. |
| breeder | `breed 76 76` | 1 | Don't have two [76]. |
| landlubber | `bind 122602` | 8 | Landlubber One [8159] must be on a ship to bind the storm to. |
| pauper | `bind 103520` | 9 | Three aura required, current level is one. |

Nothing in `oly` makes a storm, so both weather mages summon one in the
turn, and each storm id was read from a run. Plain is not a safe haven and
holds a wind cookie, so the landlubber's `use 824 3` summons Wind [122602]
on day 7. The pauper's `use 825 3` summons Rain [103520] over the ocean on
day 8 and leaves it 1 aura. Both summons start (`use` `ok`).

Rejected: `trance`, `breed` and `bind` are for nobles (`c`), so the
Bunglers' player entity orders all three, and `check_allow()` refuses each.

The one `bind` fail not covered is a storm in another province than the
ship. A mage would have to summon a storm and then move away from it in the
same turn.

## What `check.sh` asserts

1. `trance`, `breed` and `bind` reach `fail` and `rejected` in the turn's
   `--coverage` dump.
2. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match
   `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`magic-refused.lua` builds the scenario with `olyscript-g3`.
`build-scenario.sh` runs it on the bare map and freezes the result as
`scenario.patch` over the shared base world. The script never runs the `-a`
pass, so `build-scenario.sh` also swaps in `world.tgz`'s `lib/log`; a turn
deletes `lib/log` before it writes anything, so it is not turn input.

If a change moves the turn's mint, the summons mint different storm ids and
the two late `bind` orders fail for the wrong reason (no storm). Read the new
ids from the reports, set `GALE` and `SHOWER` in `magic-refused.lua`, and
rebuild.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
