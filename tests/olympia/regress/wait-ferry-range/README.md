# wait-ferry-range — `wait ferry` with an out-of-range id

Pins the fix for #349. The ferry case of `check_wait_conditions()` in
`olympia/c1.c` tested `is_ship(p->a1)` before it checked the id. `is_ship()`
uses `subkind()`, which reads `bx[n]` unchecked (`olympia/oly.h`). An id past
`MAX_BOXES`, such as `wait ferry 2147483647`, read outside `bx` and crashed
the turn (exit 139). This takes only an ordinary malformed order, not a corrupt
database. The `unit`, `loc` and `ship` conditions already went through
`kind()`, which is bounds-checked.

Now the ferry case tests `valid_box()` first. An id that names no entity gets
the same message as an id that names something that is not a ship:
`Wait finished: [id] is not a ship`.

## Scenario

No `scenario.patch`. Extracts the base world
`tests/olympia/fixtures/world.tgz`, drops `lib/master`, adds noble 1000
(player 200) in plain 10113, and queues three orders. One turn runs.

| order | what it tests |
|---|---|
| `wait ferry 2147483647` | id past `MAX_BOXES` (the crash) |
| `wait ferry -5` | negative id (the parser reads it as 0) |
| `wait ferry 10113` | control: an in-range id that is not a ship |

## Checks

Exit status 0; no AddressSanitizer or UBSan report on stderr; and each order's
echo line and its `Wait finished: … is not a ship` line appear exactly once in
`lib/save/1/200`. Before the fix the turn exits 139.
