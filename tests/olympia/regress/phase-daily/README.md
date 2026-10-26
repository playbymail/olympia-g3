# phase-daily — the daily events

Pins four `daily` cells of the phase backlog (issue #233, parent #227):
`default_garrison_pay:pay`, `ship_coastal_damage:omen`,
`check_ocean_chars:plunge` and `dogs_bark_at_hidden_chars:bark`. The fifth
`todo` cell of the phase, `noncreator_curse_erode:erode`, is `n/a` (see
[tests/ultron/README.md](../../../ultron/README.md#the-phase-backlog)).

## Scenario

Five factions, 300–304, start in Greyfell (57081), and four of the nobles
are moved to where a daily event acts on them:

| Faction | Noble | Place | Setup | Orders |
|---|---|---|---|---|
| 300 Payees | Payee One [4126] | Catchclaw [58706] | — | `stack 1009` (its default garrison) |
| 301 Fliers | Flier One [8651] | deep ocean [10100], no ship | — | — |
| 302 Sailors | Sailor One [8159] | the 12th of 12 roundships on deep ocean [10102] | — | — |
| 303 Shadows | Shadow One [7012] | Greyfell | no peasants, hidden (`oly.hide`) | — |
| 304 Kennels | Kennel One [6947] | Greyfell | 3 hounds | — |

- **pay.** A default garrison admits anyone, so the payee stacks under
  Garrison [1009] and receives 2 gold (`garrison_pay`) on each of the 30
  days. No start city has a default garrison: they are safe havens.
- **plunge.** The flier is on the ocean with no ship, so it is flying.
  After 15 days its flight can no longer be maintained, and it plunges into
  the sea and dies.
- **omen.** A deep ocean province has ocean on all four sides, so
  `near_rocky_coast()` is 3 for a ship on it, and each day the ship draws a
  keyed omen roll (1–3 of 200) on its id. Ship 12, [59379], is the first
  minted id that hits: on day 21 hungry birds circle overhead. The sailor
  is aboard it, so the omen is in its report; the other 11 ships sail empty.
- **bark.** The dogs bark on the turn's keyed `dog_bark_day`, day 2 of turn
  1, wherever a character is really hidden (hidden, with no men and no
  stackmates). A hide in the turn finishes only on day 3, so `oly.hide`
  sets the flag as an earlier turn's hide leaves it. One of the kennel's
  hounds barks.

## What `check.sh` asserts

1. Every cell above acts in the turn's `--phase-coverage` dump.
2. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match
   `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`phase-daily.lua` builds the scenario with `olyscript-g3`;
`build-scenario.sh` freezes it as `scenario.patch` over the shared base world.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
