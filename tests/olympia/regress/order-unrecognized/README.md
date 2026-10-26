# order-unrecognized — a bad order is reported and the next one runs

Pins the fix for #248. When an order fails to parse, `load_command()`
(`olympia/input.c`) sets the command to `STATE_ERROR`. The comment above it
says `do_command()` reports error states to the player, but nothing got
there: `set_state()` queues a command only for `STATE_LOAD` and
`STATE_RUN`, and `start_phase()` and `process_player_orders()` run only
`STATE_LOAD` commands. So a command in `STATE_ERROR` sat on no queue:

- the player was never told ("Unrecognized command." never printed);
- the unit's remaining orders did not run that turn and stayed queued.

Now `load_command()` passes a command that fails to parse straight to
`do_command()`. Its `STATE_ERROR` branch echoes the order, prints
"Unrecognized command." and counts `(unrecognized)` as rejected in the
`--coverage` dump; `command_done()` then loads the unit's next order. A run
of bad orders is reported one after another. This happens when the order is
loaded, so a bad order at the head of a unit's queue is reported on day 0.

## Scenario

Four factions, 300–303, start in Greyfell (57081).

| Faction | Unit | Orders | Report |
|---|---|---|---|
| 300 One | One Noble [4126] | `frobnicate the widgets`, `wait time 3` | the bad order is echoed and rejected; the wait finishes after three days |
| 301 Two | Two Noble [8651] | `frobnicate`, `glorp 5`, `wait time 2` | both bad orders are rejected; the wait finishes after two days |
| 302 Three | the player entity [302] | `frobnicate`, `realname Third Player Renamed` | the bad order is rejected; the full name changes |
| 303 Four | Four Noble [7012] | `wait time 3` | control: no bad order |

Before the fix, 300, 301 and 302 got no report lines at all. Their waits
never started, the full name stayed "P Word Here", and `wait time 3`,
`glorp 5`, `wait time 2` and the `realname` order stayed queued in
`lib/orders`.

## What `check.sh` asserts

1. The report lines in the table: each bad order's echo and
   "Unrecognized command.", the waits' `Wait finished:` lines and the new
   full name in `fact/302`.
2. No order is left queued for units 4126, 8651 and 302.
3. `(unrecognized)` is rejected exactly 4 times, and `wait:ok` is nonzero,
   in the turn's `--coverage` dump.
4. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match
   `EXPECT.sha256`.
5. The post-turn `--state-export` snapshot matches `EXPECT.json`.

Without the fix, checks 1, 2 and 3 fail on both presets.

## Authored in Lua

`order-unrecognized.lua` builds the scenario with `olyscript-g3`;
`build-scenario.sh` freezes it as `scenario.patch` over the shared base
world.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
