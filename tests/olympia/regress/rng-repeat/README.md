# rng-repeat — repeated random actions draw independently

Pins the fix for #167. Before it, three streams were keyed too coarsely to
tell repeats of one action apart within a turn:

| Stream | Keyed on before | Repeats that replayed | Keyed on now |
|---|---|---|---|
| quest (`qest`) | turn, subloc | every quest in a subloc that turn, by any noble | turn, subloc, quester, day |
| explore (`expl`) | turn | every explore of a province by one noble; every daily `seek` poll | turn, day |
| battle (`comb`) and pillage (`pill`) | turn, location | every battle (or pillage) at one place that turn | turn, location, both leaders (the pillager), day |

## Scenario

Six factions, 300–305. All are poofed out of Greyfell:

| Faction | Noble | Place | Setup | Orders |
|---|---|---|---|---|
| 300 Questers | Quester One [4126] | Battlefield [59001] | none | `quest` ×4 |
| 301 Explorers | Explorer One [8651] | Plain [13450] | none | `explore` ×3 |
| 302 Raiders A | Raider A [8159] | Plain [10113] | 20 soldiers | `attack 6947` |
| 303 Raiders B | Raider B [7012] | Plain [10113] | 20 soldiers | `attack 8731` |
| 304 Victims A | Victim A [6947] | Plain [10113] | 20 soldiers | none |
| 305 Victims B | Victim B [8731] | Plain [10113] | 20 soldiers | none |

The two battles are identical apart from the ids, fought at the same place
on day 1.

## What the fix changes

Run on the engine from before #167, and on this one:

| Action | Before #167 | Now |
|---|---|---|
| quest ×4 on the battlefield | "Nothing of interest was found." on days 7, 14, 21 and 28 | nothing on day 7; on day 14 raises 13 nazgul, which win and take the quester prisoner |
| explore ×3 in Plain | finds a hidden location on days 7 and 14 (the same gate roll both times), nothing new on day 21 | nothing on day 7, a hidden location on day 14, nothing on day 21 |
| the two battles | both victims end with 14 soldiers: the same dice | the victims end with 15 and 17 soldiers |

The hashes pin the "now" column. The quester, sick in the nazgul's stack
from day 14, also heals on a weekly roll that #186 made fresh each week;
that changed only its hidden health, so `EXPECT.json` did not move.

## What `check.sh` asserts

1. `quest`, `explore` and `attack` reach `ok` in the turn's `--coverage` dump.
2. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match
   `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`rng-repeat.lua` builds the scenario with `olyscript-g3`. `build-scenario.sh`
runs it on the bare map and freezes the result as `scenario.patch` over the
shared base world.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
