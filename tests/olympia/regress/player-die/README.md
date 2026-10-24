# player-die — the DIE order

Pins the `ok` and `rejected` outcomes of `die` (issue #118, backlog parent
#116). The Chaos Goblin leaves `die` out by default (#110), so this fixture is
the only place it runs.

## Scenario

One faction, **300** "Doomed", whose only noble Doomed One [4126] starts in
Greyfell (57081).

| Who | Order | Outcome |
|---|---|---|
| player 300 | `die` | rejected: only a noble may issue it |
| Doomed One | `die` | ok: the noble dies (`kill_char`) |

`die`'s start always returns TRUE, so its `fail` cell is `n/a`.

## What `check.sh` asserts

1. `die` reaches `ok` and `rejected` in the turn's `--coverage` dump.
2. The faction's report and unit state (`save/1/300`, `fact/300`) match
   `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`: the faction
   is left with no units.

## Authored in Lua

`player-die.lua` builds the scenario with `olyscript-g3`; `build-scenario.sh`
freezes it as `scenario.patch`, as in
[player-settings](../player-settings/README.md#authored-in-lua).

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
