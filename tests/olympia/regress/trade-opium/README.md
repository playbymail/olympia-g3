# trade-opium — a city's opium addiction level moves at month end

Pins the fix for issue #252. At month end `opium_market_delta`
(`olympia/buy.c`) moves each city's opium addiction level (`opium_econ`,
saved as `op`) by last month's opium BUY trade:

- the city bought all it wanted (the trade's qty is 0): the level rises;
- it bought none (the qty is still the level's full qty): the level falls;
- otherwise the level stays.

It looked the trade up with `find_trade`, which walks the list with
`loop_trade`, and `loop_trade` skips any trade whose qty is 0. A sold-out
trade was never found, so the level could fall but never rise. It now scans
the city's trades itself, with no qty filter.

The level matters: it sets the size and price of the city's opium demand,
and each level cuts the city's tax base by 10% (`seed_taxes`).

## Scenario

One faction, 300 "Pushers", starts in Greyfell (57081). The base world has
no opium market (its only month end ran before the cities were seeded), so
`oly.opium` gives two cities one, as an earlier month end leaves it:

| City | Level | Wants | Turn |
|---|---|---|---|
| Greyfell [57081] | 0 | 15 opium at 17 | Pusher One [4126] (15 opium) orders `sell 93 15 17` and sells all 15 for 255 gold |
| Adalgar [57625] | 3 | 50 opium at 18 | nobody sells |

At month end Greyfell has sold out, so it rises to level 1 (it now wants 28
at 17, listed in the market report), and its tax cookies drop from 100 to
90. Adalgar sold none, so it falls to level 2 (CONSUME 37 at 18), with 80
tax cookies.

Without the fix Greyfell stays at level 0, still wants 15 at 17 unlisted,
and keeps 100 tax cookies; `check.sh` prints
`NO  (city 57081: opium level 0, want 1)`.

## What `check.sh` asserts

1. The saved opium level of each city: Greyfell 1, Adalgar 2.
2. Both cities' saved `loc` entries match `EXPECT.loc` (opium trades, tax
   cookies and level).
3. The faction's report and unit state (`save/1/300`, `fact/300`) match
   `EXPECT.sha256`. The report holds the sale and Greyfell's market report.

## Authored in Lua

`trade-opium.lua` builds the scenario with `olyscript-g3`, using the
`oly.opium` binding added for this fixture. `build-scenario.sh` runs it on
the bare map and freezes the result as `scenario.patch` over the shared base
world, taking `world.tgz`'s `lib/log` as `trade-market` does.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
