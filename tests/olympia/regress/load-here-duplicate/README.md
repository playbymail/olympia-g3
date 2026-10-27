# load-here-duplicate — a stale unit listed twice in a here list

Pins the fix for #331. The second pass of `check_here()` in
`olympia/check.c` walks each here list with `loop_here`, which iterates over
a copy, and removes every unit whose location is elsewhere.
`remove_from_here_list()` removes all copies of the unit from the real list.
On the copy's next entry for the same unit, it failed
`assert(in_here_list(loc, who))` at `loc.c:241`, so the damage `check_here()`
exists to repair aborted the load (exit 134).

Now `check_here()` skips an entry that an earlier one already removed. The
removal is reported once.

## Scenario

No `scenario.patch`. Each case extracts the base world
`tests/olympia/fixtures/world.tgz` and rewrites the here list of city 58706
(`hl 1009`) in `lib/loc`. Unit 1023 is somewhere else.

| case | here list of 58706 |
|---|---|
| twice | `1009 1023 1023` |
| apart | `1023 1009 1023` |
| thrice | `1023 1023 1009 1023` |

The engine runs with `-l ./lib -S`: it loads the DB, runs `check_db()` and
saves, with no turn.

## Checks

For each case: exit status 0; no AddressSanitizer or UBSan report on stderr;
exactly one `check_here: removing [1023] from here list of [58706]` report;
and the saved here list of 58706 is `hl 1009`. Before the fix every case
exits 134.
