# load-orphan-unit — an orphaned unit with no location to touch

Pins the fix for #330. `check_indep()` in `olympia/check.c` swears every
character with no player to the independent player. `set_lord()` then calls
`touch_loc()`, and `touch_loc_pl()` in `olympia/day.c` marks the unit's
`viewloc()` as seen by the player. For a unit that is nowhere, or that sits
directly in a region, `viewloc()` is 0, and `loc_depth(0)` failed
`assert(FALSE)` at `u.c:386`. So the repair `check_db()` makes for an
orphaned unit aborted the whole load (exit 134).

Now `touch_loc_pl()` returns when `viewloc()` is 0. There is no location to
mark. Every other path to that point already aborted, so a game that loaded
before is unchanged.

## Scenario

No `scenario.patch`. Each case extracts the base world
`tests/olympia/fixtures/world.tgz` and edits garrison unit 1009 in
`lib/fact/207`. It drops the unit's `lo 207` line, so the unit has no player,
and moves it:

| case | unit 1009's location |
|---|---|
| nowhere | `wh 58706` dropped |
| region | `wh 58761`, a region |

The engine runs with `-l ./lib -S`: it loads the DB, runs `check_db()` and
saves, with no turn.

## Checks

For each case: exit status 0; no AddressSanitizer or UBSan report on stderr;
exactly one `check_indep: swearing unit [1009] to` report; and the saved
`lib/fact/100` holds unit 1009. Before the fix both cases exit 134.
