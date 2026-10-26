# fly-out-first — FLY to a destination flies out first, like a direction

Pins the fix for #265, the `v_fly` copy of #253 (`move-out-first`). `v_fly`
(`olympia/move.c`) tries each argument in turn and shifts it off with
`cmd_shift`. If none gives a usable exit from where the unit is, it asks
`can_fly_at_outer_level` whether the argument works from an outer location.
If it does, the unit flies out first ("(assuming 'fly out' first)") and the
order is queued again.

Before the fix the loop shifted off every argument, so the outer-level check
read `c->parse[1]` past the end of the list. That slot still held the last
argument's word, because `cstrings_delete` moves no elements when it removes
the last one, but `c->a` had been shifted to 0. `parse_exit_dir` uses `c->a`
for a destination and the word only for a direction, so a direction passed
the check and a destination never did:

- `fly west` from Greyfell flew out, then west;
- `fly 13450` from Greyfell stopped at "No visible route" and stayed put.

Now the loop stops before it shifts off the last argument, so the check
tests that argument as the loop did, word and parsed id together. A
direction behaves as before. A destination that the outer location reaches
now flies out first.

## Scenario

Three factions, 300–302, start in the port city Greyfell [57081], inside the
Forest [13451]. The Plain [13450, `bs50`] lies west of the Forest. Greyfell's
own exits are north and east (ocean) and out. Each noble's 25 starting
peasants are replaced by one winged horse [54] (fly 150), so the noble alone
(100) can fly.

| Faction | Unit | Order | Report |
|---|---|---|---|
| 300 One | One Noble [4126] | `fly 13450` | no route from Greyfell; flies out first, then to the Plain |
| 301 Two | Two Noble [8651] | `fly west` | control: the same before and after the fix |
| 302 Three | Three Noble [8159] | `fly nowhere bs50` | the last argument is tested: flies out first, then to the Plain |

Before the fix One and Three got only "No visible route from Greyfell~[d21]
to …" and stayed in Greyfell.

## What `check.sh` asserts

1. The report lines in the table: each order is echoed twice (once in
   Greyfell, once in the Forest), "(assuming 'fly out' first)" once,
   "Arrival at Forest~[bs51]." once and "Arrival at Plain~[bs50]." once.
2. All three nobles end the turn in the Plain, in the `--state-export`
   snapshot.
3. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match
   `EXPECT.sha256`.
4. The post-turn `--state-export` snapshot matches `EXPECT.json`.

Without the fix, checks 1 and 2 fail for One and Three on both presets.

## Authored in Lua

`fly-out-first.lua` builds the scenario with `olyscript-g3`;
`build-scenario.sh` freezes it as `scenario.patch` over the shared base
world.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
