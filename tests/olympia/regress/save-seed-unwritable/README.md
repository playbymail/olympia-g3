# save-seed-unwritable — a failed seed save is reported, not a crash

Pins the fix for #240. `save_seed()` (`olympia/rnd.c`) checked `fopen()`
with `if (fd >= 0)`. `fd` is a `FILE *`, so the test was always true: when
`lib/randseed` could not be created, `fwrite()` and `fclose()` ran on
`NULL`, and the engine died with SIGSEGV at the start of `save_db()`, with
no message and nothing else saved.

Now `save_seed()` tests `if (fd)`, like `load_seed()`, and on failure
writes `couldn't write <path>:<strerror>` to stderr (the form `save_db()`'s
rename failures use). The turn goes on: the rest of the DB is saved, and
the exit status is 0.

## Scenario

No `scenario.patch`: the base world `tests/olympia/fixtures/world.tgz` as
is, run twice with `lib/randseed` removed so both runs start from the same
built-in seed.

| Run | `lib/randseed` | `save_seed()` |
|---|---|---|
| ref | absent | creates it |
| test | a directory | `fopen()` fails with `EISDIR` |

## Checks

On the test run: exit 0; `couldn't write ./lib/randseed:` on stderr;
`lib/randseed` still a directory; and every other file under `lib` equal
to the ref run's. Before the fix the test run exits 139.

The mapgen copy of `save_seed()` (`lib/rnd.c`) has the same fix, pinned by
`tests/mapgen/regress/save-seed-unwritable`.
