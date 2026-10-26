# phase-month-gold — month-end gold, noble points, ranks and drops

Pins six `month` cells of the phase backlog (issue #234, parent #227):
`garrison_gold:castle`, `garrison_gold:owner`, `add_noble_points:point`,
`temple_income:offering`, `auto_drop:drop` and `determine_noble_ranks:rank`.

## Scenario

`oly.clock` sets the saved turn, so the turn the fixture runs is turn 8: every
faction gains a noble point at the end of turns 8, 16, 24 and so on
(`next_np_turn`). `oly.auto_quit(2)` sets the game's `auto_quit` option.

| Faction | Noble | Place | Setup |
|---|---|---|---|
| 300 Absentees | Absent One [1190] | Greyfell | joined at turn 6 (`oly.clock(6)` before `add_player`), no orders |
| 301 Lords | Lord One [6483] | a castle [75312] in Greyfell | owns the castle |
| 302 Priests | Priest One [5034] | a temple [62553] in Greyfell | knows religion (750) |

Two garrisons of 12 soldiers (`oly.add_garrison`) are bound to the lord's
castle: one in Greyfell's forest [13451], one in Plain [13450].

- **castle.** The forest's city holds a castle (`province_subloc`), so the tax
  left after the forest garrison's maintenance goes to the castle as tax
  cookies. The lord collects 113 gold in taxes.
- **owner.** Plain has no castle, so half of what is left goes to the owner of
  the garrison's castle: the lord collects 38 gold from owned provinces.
- **rank.** The lord owns, through the castle, two garrisons of strength 10
  or more, so it ranks as a lord.
- **offering.** A temple whose owner is a priest collects 100 gold.
- **point.** All three factions gain a noble point.
- **drop.** The absent faction last sent orders (joined) at turn 6, two turns
  ago, so a `quit` is queued for it. The others joined at turn 7.

## What `check.sh` asserts

1. Every cell above acts in the turn's `--phase-coverage` dump.
2. Each faction's report and unit state (`save/8/30x`, `fact/30x`) match
   `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`phase-month-gold.lua` builds the scenario with `olyscript-g3`;
`build-scenario.sh` freezes it as `scenario.patch` over the shared base world.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
