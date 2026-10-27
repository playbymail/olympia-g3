# save-libdir-space — a libdir holding a space

Pins the fix for #320. Four functions cleared a directory under the libdir
through the shell, with the libdir unquoted:

| function | file | command |
|---|---|---|
| `open_logfile()` | `olympia/sout.c` | `rm -rf %s/log` |
| `write_all_boxes()` | `olympia/io.c` | `rm -rf %s/fact` |
| `save_orders()` | `olympia/order.c` | `rm -rf %s/orders` |
| `save_logdir()` | `olympia/io.c` | `rm -rf %s/save/%d` |

With `-l "./my lib"`, `rm -rf ./my lib/fact` removed `./my` and
`./lib/fact`, and left `./my lib/fact` alone. The `-w` branches (`del`,
`rd`) had the same problem. All four now call `remove_dir()`
(`olympia/io.c`), which removes the directory with `readdir`, `unlink` and
`rmdir`, without the shell.

The fix doesn't change golden output.

## Scenario

No `scenario.patch`. The fixture extracts the base world
`tests/olympia/fixtures/world.tgz` into `my lib`, then plants:

- a decoy at every path the old commands removed: `my/keep`,
  `lib/log/keep`, `lib/fact/keep`, `lib/orders/keep`, `lib/save/1/keep`;
- a stale file in every directory the engine should clear: `log`, `fact`,
  `orders` and `save/1` under `my lib`.

The engine runs one turn with `-r -l "./my lib" -S`, which reaches all four
functions. The same turn on a plain `./lib` is the reference.

## Checks

The turn exits 0, every decoy is still there, every stale file is gone, and
the saved `my lib` matches the reference `lib` file for file. Before the
fix every decoy is removed and every stale file survives.
