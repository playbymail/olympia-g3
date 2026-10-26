# save-seed-unwritable — a failed seed save is fatal

Pins the fix for #240. `save_seed()` (`olympia/rnd.c`) checked `fopen()`
with `if (fd >= 0)`. `fd` is a `FILE *`, so the test was always true: when
`lib/randseed` could not be created, `fwrite()` and `fclose()` ran on
`NULL`, and the engine died with SIGSEGV at the start of `save_db()`, with
no message.

Now `save_seed()` tests `if (fd)`, like `load_seed()`. On failure it writes
`couldn't write <path>:<strerror>` to stderr and exits 1. `save_seed()` is
the first thing `save_db()` does, so nothing else in the DB is saved: a
turn whose seed can't be saved is not committed.

## Scenario

No `scenario.patch`: the base world `tests/olympia/fixtures/world.tgz` as
is, with `lib/randseed` replaced by a directory so `fopen()` fails with
`EISDIR`.

## Checks

Exit status 1; `couldn't write ./lib/randseed:` on stderr; `lib/randseed`
still a directory; and `lib/system` and `lib/master` unchanged from the
base world. The turn's reports are written before `save_db()`, so the rest
of `lib` does change. Before the fix the run exits 139.

The mapgen copy of `save_seed()` (`lib/rnd.c`) has the same fix, pinned by
`tests/mapgen/regress/save-seed-unwritable`.
