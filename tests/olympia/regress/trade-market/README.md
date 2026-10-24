# trade-market — buy and sell orders that start, and match

Pins the `ok` outcome of the trade-family verbs `buy` and `sell` (issue
#142, backlog parent #116). `fee` has its `ok` in `move-ship`.

## Scenario

Two factions start in Greyfell (57081). Its city market sells wood [77]
at 14 and buys woven baskets [94] at 4. The seller gets 5 woven baskets.

| Unit | Orders |
|---|---|
| Buyer One [4126] (300 "Buyers") | `buy 77 5 14`, `buy 94 2 10`, `buy 261 1 1`, `buy 261 0` |
| Seller One [8651] (301 "Sellers") | `wait day 1`, `sell 94 2 9`, `sell 94 3 4` |

Every start returns TRUE. In order:

1. `buy 77 5 14` matches the city's wood at once: the buyer pays 70 gold
   for 5 wood.
2. `buy 94 2 10` finds no seller and stays pending.
3. `buy 261 1 1` posts a buy for pitch below the city's price of 50, so it
   does not match; `buy 261 0` clears it.
4. On day 2, `sell 94 2 9` matches the buyer's pending buy. The trade
   settles at the seller's price: 18 gold for 2 baskets.
5. `sell 94 3 4` sells the other 3 baskets to the city for 12 gold.

The buyer ends with 87 gold, 5 wood and 2 baskets; the seller with 205 gold
and no baskets. The city's own stock is restocked at month end, so the
market report and the saved `loc` show no change to it.

## What `check.sh` asserts

1. `buy` and `sell` reach `ok` in the turn's `--coverage` dump.
2. Both factions' reports and unit state (`save/1/30{0,1}`, `fact/30{0,1}`)
   match `EXPECT.sha256`. The reports hold the "Bought"/"Sold" lines for
   both sides of each match.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`, which
   shows the gold and items each unit ends with.

## Authored in Lua

`trade-market.lua` builds the scenario with `olyscript-g3`.
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
