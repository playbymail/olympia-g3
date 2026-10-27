# load-nowhere-unit — a character that is nowhere is moved to Nowhere

Pins the fix for #347. `check_nowhere()` in `olympia/check.c` only warned
about a character with no location (`loc 0`). The loader accepted it and
`save_db()` kept it, and then the next turn crashed:

- with a queued order, `exec_precedence()` in `olympia/input.c` calls
  `here_pos()` in `olympia/stack.c`, which takes `rp_loc_info(loc(who))` and
  reads the empty `bx[0]` (exit 139);
- with no order, the auto-attack scan fails `valid_box(where)` in
  `olympia/combat.c` (exit 134).

Now `check_nowhere()` moves the character to the Nowhere province,
`nowhere_loc` (`nl=` in `lib/system`), and reports it on stderr under the
warning (`moved to [jk58]`). Like `check_indep()`'s repair, the move is saved.
Units stacked under the character move with it. A world that has not created
Nowhere yet (`nowhere_loc` 0) keeps the old behavior: the warning alone.

## Scenario

No `scenario.patch`. Each case extracts the base world
`tests/olympia/fixtures/world.tgz`, drops `lib/master`, and appends character
1000 (player 200, no `LI`) to `lib/fact/200`. One turn runs.

| case | orders |
|---|---|
| stop | `1000:stop` |
| idle | none |

## Checks

For each case: exit status 0; no AddressSanitizer or UBSan report on stderr;
exactly one `unit [1000] is nowhere` warning and one `moved to` report; and
the saved `lib/fact/200` places unit 1000 in the Nowhere province. The `stop`
case's report also echoes `> stop`. Before the fix the `stop` case exits 139
and the `idle` case 134.
