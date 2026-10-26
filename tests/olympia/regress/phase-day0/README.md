# phase-day0 — day 0 and day 1 of the turn

Pins the `day0` and `day1` cells of the phase backlog that no fixture
reached before (issue #232, parent #227): `init_savage_attacks:spawn`,
`queue_npc_orders` for `unsworn`, `undead`, `savage`, `mob` and `bandit`,
`check_token_units` `melt` and `add`, `process_interrupted_units`
`interrupt` and `idle`, and `match_all_trades:trade`. The remaining one,
`queue_npc_orders:token`, is `n/a` (see
[tests/ultron/README.md](../../../ultron/README.md#the-phase-backlog)).

Day 0 picks up the state an earlier turn left behind, so most of the scenario
is built with path (B) bindings that leave that state: `oly.desert`,
`oly.release`, `oly.bandit`, `oly.token`, `oly.restock` and `oly.start`.

## Scenario

Eight factions, 300–307, start in Greyfell (57081):

| Faction | Noble | Place | Setup | Orders |
|---|---|---|---|---|
| 300 Builders | Builder One [4126] | Plain [13450] | 85 towers, the last [63072] | — |
| 301 Deserters | Deserter One [8651] | Greyfell | deserted (`oly.desert`) | — |
| 302 Necromancers | Necro One [8159] | Greyfell | summoned a demon lord [3127] in the graveyard [59022], whose bond ran out (`oly.release`) | — |
| 303 Ralliers | Rallier One [7012] | Forest [13449] | a mob [85354] there has run its `guard 1` (`oly.mob`, `oly.start`) | — |
| 304 Holders | Holder One [6947] | Greyfell | an NPC token, the Horn of the Savages [74324] (`oly.token`) | — |
| 305 Waiters | Waiter One [8731] | Greyfell | `wait time 40` left running (`oly.start`) | `stop` |
| 306 Buyers | Buyer One [8761] | Greyfell | 500 gold; `buy 77 30 14` (`oly.start`), then the market restocked (`oly.restock`) | — |
| 307 Idlers | Idler One [2294] | Greyfell | — | `guard 1`, `stop` |

Three independents have no faction: a band of 10 savages [93356] in the
forest whose bond ran out (`oly.savage`, `oly.release`), a band of 10 spirits
[111453] in Hades [26000] (`oly.bandit`), and Catchclaw's garrison [1009],
which holds a second token, the Golden idol of the Orcs [70678].

- **spawn.** Each turn every fort draws a keyed 1-in-100 roll, and a fort
  in a province (not a city) that rolls 1 calls savages from a neighbouring
  province. The base world's forts that roll 1 are all in cities. The towers
  are made last; the 85th tower minted is the first that rolls 1 on turn 1.
  Two bands of savages arrive (days 7 and 14) to attack it.
- **unsworn, undead, savage, mob, bandit.** `queue_npc_orders` gives orders
  only to independents that are idle: nothing running and nothing queued,
  and not summoned. Every spawn queues orders for the unit it makes, so only
  a unit left by an earlier turn is idle. The deserter is unsworn, the demon
  lord and the savages are free NPCs once their bond has run out, the mob
  has run the `guard 1` that raising it queued, and the bandit is one that
  an ambush made.
- **melt, add.** A token held by a player's noble gets its unit (a band of
  savages [109597] appears); one held by an independent is melted.
- **interrupt, idle.** A `stop` acts on day 0 only if it is still the top
  order after the turn has loaded each idle unit's first order. The waiter's
  wait is running, so its stop interrupts it. The idler's `guard 1` is
  loaded but not run, and a loaded zero-day order counts as nothing
  executing.
- **trade.** The buy outruns Greyfell's 25 wood: 25 sell when it is posted
  and 5 stay pending. Any gain of gold or goods re-checks pending trades at
  once, so the only way to bring a pending trade into a turn is a month-end
  restock, which offers the city's goods again without matching them.
  On day 1 the buyer gets its other 5 wood for 70 gold.

## What `check.sh` asserts

1. Every cell above acts in the turn's `--phase-coverage` dump.
2. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match
   `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`phase-day0.lua` builds the scenario with `olyscript-g3`;
`build-scenario.sh` freezes it as `scenario.patch` over the shared base world.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
