# stealth-hide — hiding, sneaking and torture

Pins the `ok` outcome of `hide`, `sneak` and `torture` (issue #145, backlog
parent #116).

## Scenario

Four factions start in Greyfell (57081):

| Faction | Noble | Set up | Orders |
|---|---|---|---|
| 300 Hiders | Hider One [4126] | knows Hide self [638]; no peasants | `hide 1`, `hide 0` |
| 301 Sneakers | Sneaker One [8651] | owns a tower [74301]; no peasants | `sneak`, `sneak 74301` |
| 302 Yielders | Yielder One [8159] | none | `form 9655 Hireling` |
| | Hireling [9655] | formed on day 8 | `surrender 7012` |
| 303 Captors | Captor One [7012] | knows Torture [637] | `wait time 10`, `torture 9655` |

`char_alone` counts men as well as nobles, so the hider and sneaker drop
their 25 starting peasants with `oly.subitem`. `oly.makeloc` + `oly.poof`
make the sneaker the tower's owner (as in `combat-attack`).

- **hide.** `hide 1` takes 3 days and hides the unit. `hide 0` then unhides
  it at once (it needs the skill but not to be alone).
- **sneak.** `sneak` with no direction leaves the tower for Greyfell, and
  `sneak 74301` enters it again. Each takes 3 days.
- **torture.** Starting nobles are oath-2, and their talk chance is 0, so
  the prisoner is a formed noble: the yielder's 7-day `form` makes a
  contract-500 hireling, whose chance is 50%. Once it exists (day 8) it
  surrenders to the captor, who has waited 10 days so that the prisoner is
  already in its stack. Torture takes 50 health and draws on the skills
  stream (`skil`, see
  [doc/claude/rng-streams.md](../../../../doc/claude/rng-streams.md)),
  keyed on (captor, prisoner) under a per-day child of the stream (#186).
  With the factions in this order and the torture finishing on day 17, the
  draw succeeds, and the captor learns the hireling belongs to the Yielders.
  (A 9-day wait finishes on day 16, where the prisoner refuses.) The hash
  pins the draw.

## What `check.sh` asserts

1. `hide`, `sneak` and `torture` reach `ok` in the turn's `--coverage` dump.
2. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match
   `EXPECT.sha256`. Hiding and the prisoner's health are not in the state
   export (#114); the reports pin them.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`stealth-hide.lua` builds the scenario with `olyscript-g3`.
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
