# skills-learn — studying, researching and forgetting skills

Pins the `ok` outcome of `study`, `research` and `forget` (issue #144,
backlog parent #116). `use` already has its `ok` cell from `trade-routes`.

## Scenario

Three factions start in Greyfell (57081), which teaches Shipcraft, Combat,
Construction, Forestry, Trade, Magic and Gatecraft:

| Faction | Noble | Set up | Orders |
|---|---|---|---|
| 300 Scholars | Scholar One [4126] | none | `study 610`, `study 610` |
| 301 Foresters | Forester One [8651] | knows Forestry [700]; owns a tower | `research 700`, `study 701` |
| 302 Forgetters | Forgetter One [8159] | knows Magic [800], Meditate [801], Combat [610] | `forget 800`, `forget 610` |

`oly.know` sets up the known skills, and `oly.makeloc` + `oly.poof` make the
forester the tower's first character, so its owner (as in `combat-attack`).

- **study through the city.** The scholar pays the 100 gold tuition on the
  first `study 610`, which Greyfell teaches. The second order continues the
  same skill without paying again. Combat takes 21 days to learn, so it is
  still being learned (14 of 21 days) at month end.
- **research.** The forester pays 25 gold and researches Forestry for 7
  days. Forestry's researchable skills are Harvest opium [706] and Improve
  opium production [707]; only 706 qualifies, as 707's parent is unknown.
  The 25% success gate is a draw on the skills stream (`skil`, see
  [doc/claude/rng-streams.md](../../../../doc/claude/rng-streams.md)), keyed
  on (forester, 700). Here it succeeds, and 706 is uncovered.
  The hash pins the draw.
- **study through a known skill.** The forester then studies Construct
  battering ram [701]. The tower teaches nothing; Forestry offers 701
  (`may_study`'s second source), for the same 100 gold.
- **forget.** Forgetting Magic, a school, forgets Meditate with it and
  refunds Magic's 1 NP (18 to 19). Forgetting Combat refunds nothing (0 NP).

## What `check.sh` asserts

1. `study`, `research` and `forget` reach `ok` in the turn's `--coverage` dump.
2. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match
   `EXPECT.sha256`. Skills being learned (days studied) and NP are in
   `fact/30x`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`. It lists
   known skills only.

## Authored in Lua

`skills-learn.lua` builds the scenario with `olyscript-g3`.
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
