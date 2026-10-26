# move-out-first — MOVE to a destination moves out first, like a direction

Pins the fix for #253. `v_move` (`olympia/move.c`) tries each argument in
turn and shifts it off with `cmd_shift`. If none gives a usable exit from
where the unit is, it asks `can_move_at_outer_level` whether the argument
works from an outer location. If it does, the unit moves out first
("(assuming 'move out' first)") and the order is queued again.

Before the fix the loop shifted off every argument, so the outer-level check
read `c->parse[1]` past the end of the list. That slot still held the last
argument's word, because `cstrings_delete` moves no elements when it removes
the last one, but `c->a` had been shifted to 0. `parse_exit_dir` uses `c->a`
for a destination and the word only for a direction, so a direction passed
the check and a destination never did:

- `move west` from Greyfell moved out, then west;
- `move 13450` from Greyfell stopped at "No visible route" and stayed put.

Now the loop stops before it shifts off the last argument, so the check
tests that argument as the loop did, word and parsed id together. A
direction behaves as before. A destination that the outer location reaches
now moves out first.

## Scenario

Three factions, 300–302, start in the port city Greyfell [57081], inside the
Forest [13451]. The Plain [13450, `bs50`] lies west of the Forest. Greyfell's
own exits are north and east (ocean) and out.

| Faction | Unit | Order | Report |
|---|---|---|---|
| 300 One | One Noble [4126] | `move 13450` | no route from Greyfell; moves out first, then to the Plain |
| 301 Two | Two Noble [8651] | `move west` | control: the same before and after the fix |
| 302 Three | Three Noble [8159] | `move nowhere bs50` | the last argument is tested: moves out first, then to the Plain |

Before the fix One and Three got only "No visible route from Greyfell~[d21]
to …" and stayed in Greyfell.

## What `check.sh` asserts

1. The report lines in the table: each order is echoed twice (once in
   Greyfell, once in the Forest), "(assuming 'move out' first)" once, and
   "Arrival at Plain~[bs50]." once.
2. All three nobles end the turn in the Plain, in the `--state-export`
   snapshot.
3. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match
   `EXPECT.sha256`.
4. The post-turn `--state-export` snapshot matches `EXPECT.json`.

Without the fix, checks 1 and 2 fail for One and Three on both presets.

## Authored in Lua

`move-out-first.lua` builds the scenario with `olyscript-g3`;
`build-scenario.sh` freezes it as `scenario.patch` over the shared base
world.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
