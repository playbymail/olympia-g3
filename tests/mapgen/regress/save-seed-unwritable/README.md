# save-seed-unwritable — a failed seed save is fatal

Pins the mapgen half of the #240 fix. `lib/rnd.c` carries the same
`save_seed()` as the engine, with the same `if (fd >= 0)` test on a
`FILE *`. When `randseed` could not be created, mapgen-g3 crashed with
SIGSEGV. Now it writes `couldn't write randseed:<strerror>` to stderr and
exits 1.

The check runs mapgen-g3 with `randseed` replaced by a directory. It must
exit 1 and report the failure. Before the fix it exits 139.

`save_seed()` runs after `gate`, `loc` and `road` are written, so they are
left behind. The exit status is what tells a caller not to trust them.

The engine half is pinned by `tests/olympia/regress/save-seed-unwritable`.
