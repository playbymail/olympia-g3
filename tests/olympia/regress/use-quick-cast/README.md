# use-quick-cast — the cast speedup, and use 997–999

Answers issue #362, which asked for coverage of the three `use_tbl` skills
no fixture reached: `add_ram` (997), `save_quick` (998) and `quick_cast`
(999). None of them can run in a game. They are in `use_tbl`, but the world's
`lib/skill` has no box for them and nothing in the engine makes one (a GM's
`know` needs a skill box too). So `use 997` fails in `v_use` as "not a valid
skill to use" before any of `v_add_ram`, `v_save_quick` or `v_quick_cast`
is called. This fixture pins that outcome. Their `ok` and `fail` cells stay
`n/a` in `tests/ultron/use-backlog.tsv`.

The speedup those skills would store is reachable another way: a
quick_cast potion (item use key 6) adds to the drinker's `quick_cast`, and
`magically_speed_casting()` spends it on the next magic cast that starts.
This fixture pins each branch of that.

## Scenario

Five factions, 300–304, start in Greyfell (57081). Magic may not be used in
a safe haven, so every noble is poofed to Plain [13450]. The four mages know
Basic magic (800) and View aura (804), a 7-day cast. The potions are minted
before the turn by `oly.potion`. One made in the turn would have an id
minted in the turn, which no order can name.

| Faction | Noble | Setup | Orders | Outcome |
|---|---|---|---|---|
| 300 Hasty Mages | Hasty One [4126] | a quick_cast potion (2) | `use` potion, `use 804` | speedup 2; the cast is speeded by 2 days (7 → 5) |
| 301 Clamped Mages | Clamped One [8651] | a quick_cast potion (10) | `use` potion, `use 804` | speedup 10; the cast is speeded by 6 days and keeps its last day; the rest of the speedup is lost |
| 302 Stacking Mages | Stacker One [8159] | quick_cast potions (2, 3) | `use` each potion, `use 804` | speedup 2, then 5; the cast is speeded by 5 days |
| 303 Trancers | Trancer One [7012] | a quick_cast potion (2); also knows Advanced sorcery (920) and Trance (921) | `use` potion, `use 921`, `use 804` | Trance is never speeded and takes its 28 days; the View aura that follows on day 29 is speeded by 2 days |
| 304 Checkers | Checker One [6947] | no magic | `use 997`, `use 998`, `use 999` | each fails: not a valid skill to use |

`magically_speed_casting()` also exempts `save_quick` (998), which can't
run. Its zero-duration branch (a magic cast whose start leaves `c->wait` at
0) reports "speeded cast by 0 days" and keeps the speedup. No magic
skill's start sets `c->wait` to 0, so this fixture doesn't reach it.

## What `check.sh` asserts

1. `use:ok` and `use:fail` in the turn's `--coverage` dump, and
   `item:6:ok`, `skill:804:ok`, `skill:921:ok` and `invalid:0:checks` in its
   `--use-coverage` dump.
2. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match
   `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`use-quick-cast.lua` builds the scenario with `olyscript-g3`.
`build-scenario.sh` runs it on the bare map and freezes the result as
`scenario.patch` over the shared base world.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
