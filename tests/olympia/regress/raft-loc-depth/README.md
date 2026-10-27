# raft-loc-depth — a raft is a ship at building depth

Pins the fix for #348. A raft is a ship (`is_ship()` in `olympia/oly.h`
includes `sub_raft`), and `build raft` makes one in normal play. But
`loc_depth()` in `olympia/u.c` had no case for `sub_raft` or
`sub_raft_notdone` and failed `assert(FALSE)` at `u.c:386`. `check_nowhere()`
calls `loc_depth()` for every location, so a single raft anywhere in the
world aborted the load (exit 134). The auto-attack scan reaches it too, through
`building_owner()`.

Past `loc_depth()`, combat with a raft failed the `assert(FALSE)` in
`fort_covers()` (`olympia/combat.c`), which had no raft case either.

Now `loc_depth()` returns `LOC_build` for both raft subkinds, as it does for
galleys and roundships. `fort_covers()` returns 0 for both: a raft gives no
cover. Its defense is 0 anyway (`fort_default_defense()` has no raft case), so
the cover would add nothing.

Sailing a raft (#350) is pinned by `raft-sail`.

## Scenario

No `scenario.patch`. Each case extracts the base world
`tests/olympia/fixtures/world.tgz`, drops `lib/master`, and appends raft 61102
and raft-in-progress 61103, both at plain 10113, to `lib/ship`.

| case | run | units |
|---|---|---|
| load | `-l ./lib -S` (load, `check_db()`, save) | none: both rafts empty |
| attack | one turn | noble 1001 (player 100) aboard raft 61102; noble 1000 (player 200) in plain 10113, hostile to the raft (`ah 61102`) |

## Checks

For each case: exit status 0; no AddressSanitizer or UBSan report on stderr;
and the saved `lib/ship` holds both rafts. In the attack case, unit 1000's
report shows `> [auto-attack c102]` and the combat log (`lib/save/1/210`)
shows `Combat between Raider~[1000] and Raft~[c102] on day 1`. Before the fix
both cases exit 134 in `loc_depth()`. With only `loc_depth()` fixed, the
attack case exits 134 in `fort_covers()`.
