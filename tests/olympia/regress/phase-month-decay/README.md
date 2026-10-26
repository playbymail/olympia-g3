# phase-month-decay — month-end decay and upkeep

Pins the last `todo` cells of the phase backlog (issue #234, parent #227):
`decrement_meditation_hinder:decrement`, `loyalty_decay` `release` and
`desert`, `pillage_decay:decay`, `relic_decay` `decay` and `vanish`,
`animal_deaths:death`, `ghost_warrior_decay:evaporate`, `dead_body_rot:rot`
and `collapsed_mine_decay` `decrement` and `clear`.

Most of this counts down state that earlier month ends left, so the scenario
sets that state with path (B) bindings: `oly.loyalty`, `oly.loot`,
`oly.collapse`, `oly.relic` with a decay, and `oly.clock`.

## Scenario

The world is built at turn 0, when Doomed One is killed (`oly.kill`), and
then `oly.clock(12)` moves the game on, so the turn the fixture runs is turn
13. Six factions start in Greyfell (57081):

| Faction | Noble | Place | Setup | Orders |
|---|---|---|---|---|
| 300 Deserters | Deserter One [4126] | Greyfell | loyalty contract 0 (`oly.loyalty`) | — |
| 301 Mages | Mage One [8651] | Plain [13450] | knows magic (800) and hinder meditation (814) | `use 814 8159 1` |
| 302 Patients | Patient One [8159] | Plain [13450] | — | — |
| 303 Keepers | Keeper One [7012] | Greyfell | Crown of Prosperity [402] at decay 3 and Skull of Bastrestric [403] at decay 1 (`oly.relic`), a ghost warrior, 300 riding horses, Doomed One's body [6947] | — |
| 304 Doomed | (dead) | — | killed at turn 0 | — |
| 305 Miners | Miner One [8731] | Plain [13450] | two mines, collapsed 3 [74395] and 1 [78175] months from clearing (`oly.collapse`) | — |

There is also one independent: a band of 10 savages [117278] in Forest
[13449] (`oly.savage`) whose bond is down to 0 (`oly.loyalty`). Plain was
pillaged an earlier turn and keeps loot 4 (`oly.loot`).

- **decrement.** The hinder is cast on day 10 (magic may not be used in
  Greyfell, a safe haven). The patient never meditates, which would clear
  it, so at month end it wears off a step.
- **release.** The savages' bond has run out: they leave any stack and
  become NPCs.
- **desert.** A contract unit below 50 deserts on a keyed 1-in-2 roll. That
  roll comes up for the first noble minted, [4126], so the deserter is the
  first faction. A unit formed in the turn would be a fresh hire, which
  loyalty decay skips.
- **decay (pillage).** Plain's loot falls by one. A pillage in the turn would
  set `recent_loot` and stop it.
- **decay, vanish.** Both relics decay; the Skull reaches 0 and vanishes.
- **death.** Each animal has a keyed 1-in-100 chance of dying: four of the
  300 horses die.
- **evaporate.** One ghost warrior evaporates.
- **rot.** The body is 13 turns dead, at least 12, so it decomposes.
- **decrement, clear (mines).** Both collapsed mines count down; the one at 1
  is cleared away.

## What `check.sh` asserts

1. Every cell above acts in the turn's `--phase-coverage` dump.
2. Each faction's report and unit state (`save/13/30x`, `fact/30x`) match
   `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`phase-month-decay.lua` builds the scenario with `olyscript-g3`;
`build-scenario.sh` freezes it as `scenario.patch` over the shared base world.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
