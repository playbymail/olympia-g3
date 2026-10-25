# combat-stack-flee — a beaten stack flees together

Pins the fix for issue #212. After a battle, `demote_units` makes the losing
side's surviving nobles flee. Only stack leaders may flee, and they take their
stacks with them. Before #212 the leader test read
`!stack_leader(u) == u`, which is always false, so every follower fled on its
own too. In a province that unstacks the follower silently: `stack_flee` calls
`set_where(follower, province)`, which takes it out of its leader's
`here_list`.

## Scenario

Three factions are poofed into plain province 10113, which is not a safe
haven, so combat is allowed:

| Faction | Noble | Orders |
|---|---|---|
| 300 Raiders | Raider One [4126], 200 soldiers | `wait day 7`, `attack 8651` |
| 301 Victims | Victim One [8651], 300 extra peasants | `admit 8651 8159` |
| 302 Followers | Follower One [8159] | `wait day 3`, `stack 8651` |

The victim's `admit` runs on day 2, so the follower waits until day 3 and
stacks under the victim on day 4. On day 8 the raider beats the stack. The
victim loses 255 of its 325 peasants and the follower 16 of its 25. Neither
noble is taken prisoner, so both survive to flee. The follower ends the turn
still stacked under the victim (`stacked_under: 8651` in `EXPECT.json`).
Before #212 the follower was left on its own in the province.

The army sizes are chosen so the capture roll can miss. Each losing noble is
taken prisoner with chance `25 * winners / losers` (left alive, unhurt men on
each side), clamped to 25–75%. With only the 25 peasants each noble starts
with, the losers keep so few men that the chance is 75% and the battle
captured one or both of them on every day tried. The victim's extra
peasants keep enough losers alive to bring the chance down. With 160
soldiers the raider lost; with 200 it wins. The battle draws from the
per-battle `begin_battle()` stream, keyed on the place, both leaders and the
day (see
`doc/claude/rng-streams.md`), so the result is pinned by the hashes.

## What `check.sh` asserts

1. `attack`, `admit` and `stack` reach `ok` in the turn's `--coverage` dump.
   The backlog cells for these verbs belong to `combat-attack` and
   `stacking-stack`; this fixture only checks that its own orders ran.
2. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match
   `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

With the #212 fix reverted, checks 2 and 3 fail: the follower's
`stacked_under` drops to 0.

## Authored in Lua

`combat-stack-flee.lua` builds the scenario with `olyscript-g3`.
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
