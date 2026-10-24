# player-quit — the QUIT order

Pins the `fail` and `rejected` outcomes of `quit` (issue #118, backlog parent
#116).

## Scenario

Two factions in Greyfell (57081): **300** "Leavers" (Leaver One [4126]) and
**301** "Stayers" (Stayer One [8651]).

| Who | Order | Outcome |
|---|---|---|
| player 300 | `quit` | fail: the faction is dropped and its noble vanishes |
| Stayer One | `quit` | rejected: only a player may issue it |

A successful `quit` counts as `fail`. `v_quit` drops the player and then
returns FALSE, because the command's owner no longer exists to finish it.
So the `fail` cell is the one a real quit reaches, and the `ok` cell is `n/a`.

## What `check.sh` asserts

1. `quit` reaches `fail` and `rejected` in the turn's `--coverage` dump.
2. Both reports (`save/1/30{0,1}`) and the staying faction's unit state
   (`fact/301`) match `EXPECT.sha256`. `fact/300` is gone with the dropped
   player. Stayer One's report shows the leaver melting away.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`: only
   faction 301 is left.

## Authored in Lua

`player-quit.lua` builds the scenario with `olyscript-g3`; `build-scenario.sh`
freezes it as `scenario.patch`, as in
[player-settings](../player-settings/README.md#authored-in-lua).

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
