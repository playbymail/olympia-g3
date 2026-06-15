---
title: Engine command line
weight: 3
---

The `olympia-g3` engine is a command-line program that operates on a **game
library** directory. This page lists its options exactly. It is for **game
masters** running games; players never invoke it directly.

```text
olympia-g3 [options]
```

By default the engine acts on `./lib`. Use `-l` to point it elsewhere.

## Options

| Option | Effect |
|---|---|
| `-l dir` | Use `dir` as the game library (libdir). Default `./lib`. |
| `-r` | Run a turn — resolve every faction's queued orders. |
| `-S` | Save the database back to the library when finished. |
| `-i` | Immediate mode — interactive command interpreter against the library. |
| `-e` | Eat orders from `libdir/spool` (ingest submitted order files). |
| `-E` | Eat orders from `libdir/spool` and then terminate. |
| `-a` | Add-new-players mode. |
| `-s` | Extract safe havens as the start-city list. |
| `-M` | Mail reports and order acknowledgements. |
| `-A` | Charge player accounts. |
| `-p` | Don't pretty-print data files. |
| `-f` | Don't buffer files (debugging). |
| `-w` | Windows mode. |
| `-T` | Print timing info. |
| `-R` | Test the random number generator. |
| `-t` | Test the ilist code. |

## Common invocations

Run a turn and save the result (the core of a turn cycle):

```bash
olympia-g3 -r -l ./lib -S
```

Open the library interactively to inspect or adjust state:

```bash
olympia-g3 -i -l ./lib
```

Ingest queued order files from the spool and stop:

```bash
olympia-g3 -E -l ./lib
```

## See also

- The end-to-end turn cycle:
  [Running your first game as a GM](../../tutorials/gm-first-game/).
- Preparing the library these commands operate on:
  [How to configure a scenario](../../how-to/configure-a-scenario/).
