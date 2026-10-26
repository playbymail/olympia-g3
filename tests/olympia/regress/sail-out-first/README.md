# sail-out-first — SAIL to a destination sails out first, like a direction

Pins the fix for #266, the `v_sail` copy of #253 (`move-out-first`) and #265
(`fly-out-first`). `v_sail` (`olympia/move.c`) tries each argument in turn
from the ship's location and shifts it off with `cmd_shift`. If none gives a
usable water route, it asks `can_sail_at_outer_level` whether the argument
works from an outer location. If it does, the ship sails out first
("(assuming 'sail out' first)") and the order is queued again.

Before the fix the loop shifted off every argument, so the outer-level check
read `c->parse[1]` past the end of the list. That slot still held the last
argument's word, because `cstrings_delete` moves no elements when it removes
the last one, but `c->a` had been shifted to 0. `parse_exit_dir` uses `c->a`
for a destination and the word only for a direction, so a direction passed
the check and a destination never did:

- `sail east` from the island sailed out, then east;
- `sail 13199` from the island stopped at "No visible route" and stayed put.

Now the loop stops before it shifts off the last argument, so the check
tests that argument as the loop did, word and parsed id together. A
direction behaves as before. A destination that the outer location reaches
now sails out first.

## Why an island, not a harbor

A ship docked directly in a city can't reach this path with an ocean
destination. A port city already has its province's ocean exits, so the
loop finds the route itself. A province with a port city marks its own
ocean exits impassable, and a mountain's ocean exits are impassable too, so
the outer level of any coastal city has no open water route. An island is a
sublocation of an ocean province with only an "out" exit, and the ocean
around it reaches every neighbor, so a ship docked there is the natural case.

## Scenario

Three factions, 300–302, start in Greyfell [57081]. Each captain knows
Sailing [601], trades its 25 starting peasants for 8 sailors (a roundship's
full crew) and is moved to the island [59113, `a113`] in the Ocean [13198,
`bp98`]. It builds a roundship there with `makeloc` and boards it. The Ocean
[13199, `bp99`] lies east of [13198]. The island's only exit is out.

| Faction | Captain | Ship | Order | Report |
|---|---|---|---|---|
| 300 One | One Captain [4126] | [61319] | `sail 13199` | no route from the island; sails out first, then to [13199] |
| 301 Two | Two Captain [4947] | [69557] | `sail east` | control: the same before and after the fix |
| 302 Three | Three Captain [9655] | [64623] | `sail nowhere bp99` | the last argument is tested: sails out first, then to [13199] |

Before the fix One and Three got only "No visible route from Island~[a113]
to …" and their ships stayed at the island.

## What `check.sh` asserts

1. The report lines in the table: each order is echoed twice (once at the
   island, once in [13198]), "(assuming 'sail out' first)" once, "Arrival at
   Ocean~[bp98]." once and "Arrival at Ocean~[bp99]." once.
2. All three ships end the turn in [13199], in the saved `lib/ship`.
3. Each faction's report and unit state (`save/1/30x`, `fact/30x`) and the
   ship file (`ship`) match `EXPECT.sha256`.
4. The post-turn `--state-export` snapshot matches `EXPECT.json`.

Without the fix, checks 1 and 2 fail for One and Three on both presets.

## Authored in Lua

`sail-out-first.lua` builds the scenario with `olyscript-g3`;
`build-scenario.sh` freezes it as `scenario.patch` over the shared base
world.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
