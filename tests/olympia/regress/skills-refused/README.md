# skills-refused — skills orders that fail or are refused

Pins the `fail` and `rejected` outcomes of `study`, `research`, `forget` and
`use` (issue #144, backlog parent #116).

## Scenario

Three factions start in Greyfell (57081):

| Faction | Noble | Set up |
|---|---|---|
| 300 Dunces | Dunce One [4126] | knows Combat [610] |
| 301 Hermits | Hermit One [8651] | knows Combat and Forestry [700]; owns a tower; no gold |
| 302 Lodgers | Lodger One [8159] | knows Forestry; inside the hermit's tower, second |

The dunce's orders, in order. Every failure is instant, so all but the
Forestry studies run on day 1:

| Order | Fails with |
|---|---|
| `study` | Must specify a skill to study. |
| `study 1` | not a valid skill (gold) |
| `study 631` | Stealth must be learned before Petty thievery [631] |
| `study 610` | Already know Combat. |
| `study 820` | Instruction in Weather magic is not available here. |
| `research` | Must specify skill to research. |
| `research 1` | not a valid skill |
| `research 600` | does not know Shipcraft |
| `research 610` | Research must be performed in a tower. |
| `forget 1` | not a skill |
| `forget 600` | Don't know Shipcraft. |
| `use 610` | Skill schools have no direct use. |
| `use 611` | does not know Survive fatal wound |
| `study 700` ×2 | (ok) 14 days of Forestry |
| `study 700` | Maximum 14 days studied this month. |

In the tower, the hermit's `research 610` fails because Combat has nothing
to research, and its `research 700` fails because it cannot pay 25 gold. The
lodger's `research 700` fails because it is not the first character inside.
With no gold, the hermit also cannot pay maintenance at month end, and nine
of its peasants starve.

Rejected: all four verbs are for nobles (`c`), so the Dunces' player entity
orders `study`, `research`, `forget` and `use`, and `check_allow()` refuses
each.

Not reached: study's NP and tuition shortfalls, fast study, and research's
temple branch and its aura and civilization limit for high-level mages.

## What `check.sh` asserts

1. Each of the four verbs reaches `fail` and `rejected` in the turn's
   `--coverage` dump.
2. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match
   `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`skills-refused.lua` builds the scenario with `olyscript-g3`.
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
