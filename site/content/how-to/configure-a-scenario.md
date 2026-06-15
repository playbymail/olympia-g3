---
title: Configure a scenario
weight: 3
---

This guide is for **game masters**. It shows how to produce the two ingredients a
G3 game needs — a generated world and a game library to host — so you can run
turns against them. It assumes you have built the engine (see
[Running your first game as a GM](../../tutorials/gm-first-game/)).

## Generate a world map

The map generator turns map definition inputs into the map files the engine
loads (`gate`, `loc`, `road`). Run the bundled driver:

```bash
./run/mapgen/mapgen.sh
```

Under the hood this calls `build/debug/mapgen-g3`. The generator is **seeded**:
the same seed values produce the same world every time, so a scenario is
reproducible. The run drivers set the seeds explicitly, for example:

```bash
export G3_MAPGEN_SEED_1=18481
export G3_MAPGEN_SEED_2=28078
export G3_MAPGEN_SEED_3=26982
```

Change the seeds to roll a different world; keep them fixed to regenerate the same
one.

## Generate standalone islands

To add isolated landmasses, use the island generator directly:

```bash
build/debug/island-g3
```

It shares the same seeded RNG as the map generator, so island layouts are
reproducible the same way.

## Prepare a game library

A game is a directory of flat files — the **game library**, conventionally
`lib/`. The simplest way to get a working one is to let the run driver assemble it
from the shipped fixtures:

```bash
./run/olympia-g3.sh
```

This extracts a ready-to-run `lib/` into `run/olympia/`, loads it once in
immediate mode to rebuild indexes, then runs a turn against it. Use that `lib/`
as the starting point for your own scenario, then run turns against it with:

```bash
build/debug/olympia-g3 -r -l ./lib -S
```

where `-l ./lib` selects the library, `-r` runs a turn, and `-S` saves the result.

## Keep the scenario reproducible

Two things determine whether a scenario reproduces exactly:

- the **map seeds** (above), which fix the world, and
- the **RNG stream**, which the engine draws from when resolving turns.

{{< callout type="info" >}}
G3's turn RNG is a single process-global stream, so the order in which the engine
makes random draws affects every later draw. If you script scenario setup, build
it the same way each time so ids and outcomes stay stable. The combat subsystem
already draws from a per-battle keyed stream, which is why combat outcomes are
reproducible independently of the rest of the turn.
{{< /callout >}}

## Verify the scenario runs cleanly

Run the golden gate to confirm a turn against the reference library matches the
known-good baseline byte for byte:

```bash
./tests/olympia/golden_check.sh   # prints YES
```

A `YES` means the engine, map, and library are consistent and a turn resolves
correctly.

## Related

- The full run cycle, step by step:
  [Running your first game as a GM](../../tutorials/gm-first-game/).
- How simultaneous orders are sequenced within a turn:
  [The turn-resolution model](../../explanation/turn-resolution-model/).
