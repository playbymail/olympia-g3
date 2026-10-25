# gm-refused — the GM verbs, failed and refused

Pins the `fail` and `rejected` outcomes of the gm family (issue #151,
backlog parent #116): `credit`, `emote` and `relore`.

## Scenario

One faction, **300** "Guild", whose noble Herald One [4126] starts in
Greyfell (57081). The herald's orders:

| Order | Outcome |
|---|---|
| `credit 4126 5` | rejected: only the GM player's units may issue it |
| `emote 4126 "Hello, %s."` | rejected |
| `relore 600` | rejected |

The orders of the GM player, The Fates [200]:

| Order | Outcome |
|---|---|
| `credit 57081 5` | fail: Greyfell is not a character or player |
| `credit 4126 2 np` | fail: NP go to a player, not a noble |
| `credit 57081` | fail: the Times pays only a character |
| `credit 4126` | ok: the Times pays the herald 25 gold |
| `credit 4126` | fail: the Times has already paid faction 300 |
| `emote 4126` | fail: no message |
| `relore 57081` | fail: Greyfell is not a skill |

`credit` has no other fail branch. `emote` never checks its target, so its
only fail is a missing message. `relore`'s only fail is a non-skill.

## What `check.sh` asserts

1. Each verb reaches `fail` and `rejected` in the turn's `--coverage` dump.
2. The GM's report, the faction's report and the faction's unit state
   (`save/1/200`, `save/1/300`, `fact/300`) match `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`gm-refused.lua` builds the scenario with `olyscript-g3`. `build-scenario.sh`
runs it on the bare map and freezes the result as `scenario.patch` over the
shared base world. The script never runs the `-a` pass, so `build-scenario.sh`
also swaps in `world.tgz`'s `lib/log`. A turn deletes `lib/log` before it
writes anything, so it is not turn input.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
