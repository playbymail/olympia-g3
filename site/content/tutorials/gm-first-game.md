---
title: Running your first game as a GM
weight: 2
---

In this tutorial you will build the engine, generate a small world, and run one
turn end to end against it. By the end you will have a working game library on
disk and a turn you ran yourself. This is the game-master side of the same loop
players see: **orders in → turn runs → reports out.**

{{< callout type="info" >}}
You will work from a checkout of the
[olympia-g3 repository](https://github.com/playbymail/olympia-g3). You need
CMake (≥ 4.1), Ninja, and Clang or GCC. The commands below assume a Unix-like
shell at the repository root.
{{< /callout >}}

## What you are aiming for

A G3 game is just a directory of flat files — the **game library**,
conventionally `lib/`. The engine reads that directory, applies every faction's
queued orders, writes reports, and saves the updated library back. Running a turn
is one command against that directory. You are about to create a library and run
a turn against it once.

## Step 1 — Build the engine

From the repository root, configure and build the default (debug) preset:

```bash
cmake --preset debug
cmake --build --preset debug
```

This produces three binaries under `build/debug/`:

- `olympia-g3` — the game engine (runs turns).
- `mapgen-g3` — the map generator (builds the world map).
- `island-g3` — the island generator.

## Step 2 — Generate a world

The engine needs a map before it can host a game. The repo ships a driver script
that runs the map generator and writes the map files (`gate`, `loc`, `road`):

```bash
./run/mapgen/mapgen.sh
```

The map generator is **seeded**, so the same seeds produce the same world every
time — handy when you want a reproducible game to test against.

## Step 3 — Run a turn

The repo's run driver assembles a ready-made game library from the test fixtures
and runs a full turn against it. Use it to see the complete cycle without
hand-authoring a world first:

```bash
./run/olympia-g3.sh
```

That script extracts a `lib/` game library into `run/olympia/`, loads it once in
immediate mode to rebuild indexes, then runs a turn and saves the result. The
turn-running command at its core is:

```bash
build/debug/olympia-g3 -r -l ./lib -S
```

- `-l ./lib` points the engine at the game library directory.
- `-r` runs a turn (resolves every faction's queued orders).
- `-S` saves the updated library back to disk.

When it finishes, the engine has advanced the game by one turn and written the
players' reports.

## Step 4 — Inspect what changed

The turn rewrote the library in place. Compare the before/after snapshots the
driver left behind to see the turn's effect on the game state:

```bash
diff -ru run/olympia/lib-before run/olympia/lib
```

You will see entity files under `lib/` change — nobles that moved, locations that
were explored, and the generated reports. This diff *is* the turn: every line is
a consequence of the orders the engine resolved.

## Step 5 — Confirm the turn is sound

G3 ships a golden-snapshot gate that verifies a turn produced exactly the
expected library. Run it to confirm your turn matched the known-good baseline
byte for byte:

```bash
./tests/olympia/golden_check.sh
```

A `YES` means your build ran the turn correctly. You now have a reproducible game
you ran yourself.

## Where to go next

- Shape a world to your liking:
  [How to configure a scenario](../../how-to/configure-a-scenario/).
- See every order a player can send you:
  the [order catalog](../../reference/order-catalog/).
- Understand how the engine orders simultaneous actions within a turn:
  [The turn-resolution model](../../explanation/turn-resolution-model/).
