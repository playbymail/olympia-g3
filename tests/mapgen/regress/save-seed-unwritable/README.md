# save-seed-unwritable — a failed seed save is reported, not a crash

Pins the mapgen half of the #240 fix. `lib/rnd.c` carries the same
`save_seed()` as the engine, with the same `if (fd >= 0)` test on a
`FILE *`. When `randseed` could not be created, mapgen-g3 crashed with
SIGSEGV after writing `gate`, `loc` and `road`. Now it writes
`couldn't write randseed:<strerror>` to stderr and exits 0.

The check runs mapgen-g3 twice with no `randseed` file: a ref run, where
`save_seed()` creates it, and a test run, where `randseed` is a directory.
The test run must exit 0, report the failure, and write the same
`gate`/`loc`/`road` as the ref run. Before the fix it exits 139.

The engine half is pinned by `tests/olympia/regress/save-seed-unwritable`.
