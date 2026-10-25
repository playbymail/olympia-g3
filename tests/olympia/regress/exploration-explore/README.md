# exploration-explore — exploring, seeking and questing

Pins the `ok` outcome of `explore`, `seek`, `quest`, `plugh` and `xyzzy`
(issue #148, backlog parent #116).

## Scenario

Four factions start in Greyfell (57081). Plain [13450], west of Greyfell's
forest, hides a cave [73045] and a ruins [74516]:

| Faction | Noble | Set up | Orders |
|---|---|---|---|
| 300 Explorers | Explorer One [4126] | poofed to Plain [13450] | `explore` |
| 301 Seekers | Seeker One [8651] | none | `plugh`, `xyzzy`, `seek 8159`, `seek 4126`, `seek` |
| 302 Idlers | Idler One [8159] | none | none |
| 303 Questers | Quester One [7012] | poofed into the ruins [74516] | `quest` |

- **explore.** `v_explore` always starts. The find is up to `d_explore`, and
  each of its draws is on the explore stream (`expl`, see
  [doc/claude/rng-streams.md](../../../../doc/claude/rng-streams.md)), keyed
  on (explorer, province) under a per-day stream (#167). The gate draw
  succeeds, and on day 7 the explorer finds the hidden cave [73045]. The hash
  pins the find.
- **seek.** `plugh` and `xyzzy` are developer no-ops that take no time.
  `seek 8159` names a noble who is here, so the seeker contacts it at once.
  `seek 4126` names a noble in another place: the 7-day search runs and
  draws nothing, because the target is not in the seeker's location. The
  bare `seek` then scans Greyfell for hidden nobles. There are none, so it
  draws nothing and finds nothing.
- **quest.** The ruins are not a safe haven, the quester leads its own
  stack, and ruins have rows in `quest_monster`, so the quest starts. The
  quest stream (`qest`), keyed on the ruins, the quester and the day
  (#167), comes up empty on day 8: "Nothing of interest was found." The
  quest's monster and battle path is pinned by `exploration-refused` and
  `rng-repeat`.

## What `check.sh` asserts

1. `explore`, `seek`, `quest`, `plugh` and `xyzzy` reach `ok` in the
   turn's `--coverage` dump.
2. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match
   `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`exploration-explore.lua` builds the scenario with `olyscript-g3`.
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
