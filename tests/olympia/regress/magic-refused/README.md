# magic-refused — magic orders that fail or are refused

Pins the `fail` and `rejected` outcomes of `trance`, `breed` and `bind`
(issue #149, backlog parent #116).

## Scenario

Five factions start in Greyfell (57081), a safe haven:

| Faction | Noble | Set up |
|---|---|---|
| 300 Bunglers | Bungler One [4126] | stays in Greyfell, no skills |
| 301 Breeders | Breeder One [8651] | stays in Greyfell; knows Beastmastery [650] and Breed beasts [654]; one ox [76] |
| 302 Landlubbers | Landlubber One [8159] | stays in Greyfell; knows Magic, Weather magic, Bind storm (3 aura); owns Rain [139904] over Forest [13451] |
| 303 Paupers | Pauper One [7012] | knows only Bind storm (1 aura); aboard Roundship [73052] in Greyfell; owns Fog [143336] over Forest [13451] |
| 304 Drifters | Drifter One [4940] | knows Magic, Weather magic, Bind storm (3 aura); aboard Roundship [65623] in Greyfell; owns Rain [128516] over Ocean [13351] |

| Unit | Order | Day | Fails with |
|---|---|---|---|
| bungler | `trance` | 1 | Requires knowledge of Trance [921]. |
| bungler | `breed 10 76` | 1 | Requires Breed beasts [654]. |
| bungler | `bind 57081` | 1 | Bungler One [4126] doesn't control any storm [d21]. |
| breeder | `breed 10` | 1 | Usage: breed &lt;item&gt; &lt;item&gt; |
| breeder | `breed 57081 10` | 1 | 57081 is not an item. |
| breeder | `breed 10 51` | 1 | Don't have any [51]. |
| breeder | `breed 76 76` | 1 | Don't have two [76]. |
| landlubber | `bind 139904` | 1 | Landlubber One [8159] must be on a ship to bind the storm to. |
| pauper | `bind 143336` | 1 | Three aura required, current level is one. |
| drifter | `bind 128516` | 2 | Storm must be in the same province as the ship it is to be bound to. |

`oly.storm` (#170) raises the storms at build time and records each mage
as its storm's summoner. The landlubber's and the pauper's storms are over
Greyfell's forest, which holds one rain cookie and one fog cookie. The
drifter's storm is over Ocean [13351], the next province north. The
drifter's ship is in port, so it counts as being in the forest. `bind`
checks the storm, then the ship, then the province, then the aura, so each
mage reaches a different fail. The drifter has the 3 aura that bind costs,
so the province is the only check it fails.

Rejected: `trance`, `breed` and `bind` are for nobles (`c`), so the
Bunglers' player entity orders all three, and `check_allow()` refuses each.

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

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
