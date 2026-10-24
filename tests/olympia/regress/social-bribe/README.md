# social-bribe — bribery, inciting a mob and terror

Pins the `ok` outcome of `bribe`, `incite` and `terrorize` (issue #146,
backlog parent #116).

## Scenario

Four factions start in Greyfell (57081); three are poofed to Forest
[13449], where `oly.mob` (#139) seeds a peasant mob, Mob [139904]:

| Faction | Noble | Set up | Orders |
|---|---|---|---|
| 300 Inciters | Inciter One [4126] | Forest; knows Persuasion [670] and Incite mob [675] | `incite 139904 8651`, `use 675 139904 8651` |
| 301 Marks | Mark One [8651] | Forest | none |
| 302 Bribers | Briber One [8159] | Forest; knows Bribe noble [671] | `bribe 8651 100` |
| 303 Terrorizers | Terrorizer One [7012] | Greyfell | `form 6133 Hireling`, `terrorize 6133 3` |

- **bribe.** The mark is a starting noble, oath-2, so no bribe reaches its
  threshold: the outcome is a 50/50 draw between pocketing the gold and
  reporting the bribe. The draw is on the social stream (`socl`, see
  [doc/claude/rng-streams.md](../../../../doc/claude/rng-streams.md)),
  keyed on (briber, mark). Here the mark pockets it. The gold is charged
  to the briber but never given to the mark: it leaves the game (the mark
  ends the turn with its 200 gold).
- **incite.** `incite`'s `cmd_tbl` row has a start (`v_incite`) but no
  finish, so the order checks its arguments, starts (`ok`), spends seven
  days and does nothing. The same skill used through `use 675` runs
  `d_incite`. Its social-stream draws are keyed on (inciter, target). With
  the inciters added first the ids make it succeed: on day 16 the mob
  attacks the mark, wins, kills the mark's 25 peasants and wounds it.
- **terrorize.** A formed noble is contract-500 and stacked beneath its
  former (`form_new_noble`), so once the 7-day `form` makes the hireling
  (day 8), the terrorizer's next order terrorizes it: 3 damage and fear-3
  loyalty on day 14. There is no draw on the vassal path.

## What `check.sh` asserts

1. `bribe`, `incite` and `terrorize` reach `ok` in the turn's `--coverage`
   dump.
2. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match
   `EXPECT.sha256`. Loyalty, health and the mob are not in the state export
   (#114); the reports pin them.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`social-bribe.lua` builds the scenario with `olyscript-g3`.
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
