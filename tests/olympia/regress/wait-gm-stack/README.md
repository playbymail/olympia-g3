# wait-gm-stack — `wait top` and `wait stack` from the GM player

Pins the fix for #249. `wait` has allow string `"crm"`
(`olympia/glob.c`), so the GM player can issue it. Cases 7 and 8 of
`check_wait_conditions()` (`olympia/c1.c`), `stack` and `top`, called
`stack_leader(c->who)`, which starts with `assert(kind(who) == T_char)`
(`olympia/stack.c`). When `c->who` was the player, the turn aborted:

```
..assertion failure: olympia/stack.c (96): kind(who) == T_char
```

Now both cases call `wait_leader()`, which returns a non-character as its
own stack leader and calls `stack_leader()` for a character. That is what
`stack_leader()` itself would return for a player without the assert: the
loop over `kind(n) == T_char` never runs, so it returns `who`. A player is
in no stack, so `wait top` is true and `wait stack <char>` is false.

## Scenario

One faction, 300 Guild, starts in Greyfell (57081) with a lone noble,
Herald One [4126]. The GM player, The Fates [200], has no units and
issues the waits itself.

| Unit | Order | Wait finished |
|---|---|---|
| The Fates [200] | `wait top` | we are the stack leader |
| The Fates [200] | `wait not top time 1` | one day has passed. |
| The Fates [200] | `wait stack 4126 time 2` | two days have passed. |
| The Fates [200] | `wait not stack 4126` | Herald One~[4126] is not stacked with us. |
| Herald One [4126] | `wait top` | we are the stack leader |

Before the fix the turn aborted at the GM's first order. The herald is a
control: a character's `wait top` is unchanged.

## What `check.sh` asserts

1. The turn exits 0, and each wait's `Wait finished:` line gives the
   reason in the table above.
2. `wait:ok` in the turn's `--coverage` dump.
3. The GM's and the faction's reports and the faction's unit state
   (`save/1/200`, `save/1/300`, `fact/300`) match `EXPECT.sha256`.
4. The post-turn `--state-export` snapshot matches `EXPECT.json`.

Without the fix, check 1 fails on both presets: `NO  (olympia-g3 turn
failed: exit 134)`.

## Authored in Lua

`wait-gm-stack.lua` builds the scenario with `olyscript-g3`;
`build-scenario.sh` freezes it as `scenario.patch` over the shared base
world.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
