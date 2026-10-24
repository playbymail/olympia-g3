# player-press — the Times, posts and messages

Pins the press and newsletter verbs of the player family (issue #118, backlog
parent #116): the `ok` outcome of `press`, `rumor`, `post`, `message` and
`times`, and the `fail` outcome of `press`, `rumor`, `post` and `message`.

## Scenario

Two factions in Greyfell (57081): **300** "Town Crier" (Crier One [4126])
and **301** "Listeners" (Listener One [8651]). Each text verb takes its text
from the lines that follow it in the crier's orders: `0` reads up to `end`,
and a number reads that many lines.

| Crier's order | Outcome |
|---|---|
| `press 0` + 2 lines + `end` | ok: written to `times_press` (a line starting `=-=-` is quoted with `> `) |
| `press 1` + a 79-character line | fail: over 78 characters |
| `rumor 2` + 2 lines | ok: written to `times_rumor` |
| `rumor 1` + a 79-character line | fail: over 78 characters |
| `post 0` + 1 line + `end` | ok: posted in Greyfell, shown in both reports |
| `post 1` + a 61-character line | fail: over 60 characters |
| `message 1 8651` + 1 line | ok: delivered to the listener |
| `message 1 57081` + 1 line | fail: Greyfell is not a character |

Player 300 also orders `times 1`, which takes it off the Times mailing list
(`totimes`). `times` always returns TRUE, so its `fail` cell is `n/a`.

## What `check.sh` asserts

1. Every cell above reaches its outcome in the turn's `--coverage` dump.
2. Both factions' reports and unit state (`save/1/30{0,1}`, `fact/30{0,1}`),
   plus the Times files the turn writes (`times_press`, `times_rumor`,
   `totimes`), match `EXPECT.sha256`. A post is not saved with the database,
   so the reports are what pin it.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`. Nothing these
   verbs do shows in it.

## Authored in Lua

`player-press.lua` builds the scenario with `olyscript-g3`; `build-scenario.sh`
freezes it as `scenario.patch`, as in
[player-settings](../player-settings/README.md#authored-in-lua).

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
