# exploration-refused — exploration orders that fail or are refused

Pins the `fail` outcome of `seek` and `quest`, and the `rejected` outcome
of `explore`, `seek`, `quest`, `plugh` and `xyzzy` (issue #148, backlog
parent #116).

## Scenario

Five factions start in Greyfell (57081), a safe haven. Plain [13450], west
of Greyfell's forest, is not a safe haven and hides a ruins [74516]:

| Faction | Noble | Set up |
|---|---|---|
| 300 Bunglers | Bungler One [4126] | stays in Greyfell |
| 301 Leaders | Leader One [8651] | poofed to Plain [13450] |
| 302 Followers | Follower One [8159] | poofed to Plain [13450] |
| 303 Questers | Quester One [7012] | poofed into the ruins [74516] |
| 304 Latecomers | Latecomer One [6947] | poofed into the ruins [74516] |

| Unit | Order | Day | Fails with |
|---|---|---|---|
| bungler | `seek 57081` | 1 | [d21] is not a character. |
| bungler | `quest` | 1 | Questing is not permitted in safe havens. |
| leader | `quest` | 1 | There are no quests to be found here. (a plain has no `quest_monster` rows) |
| follower | `quest` | 1 | Only the stack leader may initiate quests. |
| latecomer | `quest` | 11 | This area has been quested in recently, nothing of interest is found. |

The leader admits the follower, and the follower stacks beneath it before
its quest. The quester's quest in the ruins starts (`ok`). On day 7 it
raises 2 bandits (a draw on the `qest` stream, keyed on the ruins, the
quester and the day), attacks them, wins and takes their 1,152 gold. The
quest also marks the ruins as quested. The latecomer waits until day 10,
so its quest finds the ruins already quested.

Rejected: every exploration verb is for nobles (`c` or `cr`), so the
Bunglers' player entity orders `explore`, `seek`, `quest`, `plugh` and
`xyzzy`, and `check_allow()` refuses each.

No `fail` cell: `explore`, `plugh` and `xyzzy` always start. When an
explore finds nothing, `d_explore` fails after the start, so that is not a
`fail` cell.

## What `check.sh` asserts

1. `seek` and `quest` reach `fail`, and all five verbs reach `rejected`, in
   the turn's `--coverage` dump.
2. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match
   `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`exploration-refused.lua` builds the scenario with `olyscript-g3`.
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
