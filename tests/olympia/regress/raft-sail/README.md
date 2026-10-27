# raft-sail — a raft sails with no crew

Pins the fix for #350. `build raft` needs no skill, only flotsam, which
replenishes on islands and coastal provinces. But two switches in
`olympia/move.c` had cases only for roundships and galleys, and failed
`assert(FALSE)` for a raft:

- `move_exit_water()`, which works out a voyage's days: every `sail` from a
  raft aborted the turn (exit 134);
- `check_captain_loses_sailors()`, which adds days when the captain loses
  sailors mid-voyage (to `get`, or to starvation).

The rule now: **a raft needs no crew**. `move_exit_water()` adds no days for
missing hands and prints no crew message, and `check_captain_loses_sailors()`
returns at once. A raft gets no wind bonus; that was already the case, since
only a roundship gets one.

## Scenario

No `scenario.patch`. Each case extracts the base world
`tests/olympia/fixtures/world.tgz`, drops `lib/master`, and puts ship 61102
at plain 10113 with captain 1001 (player 200, Sailing 601) aboard. Ocean 10013
is to the north. One turn runs.

| case | ship | sailors | orders |
|---|---|---|---|
| sail | raft | 0 | 1001 `sail north`, `sail south` |
| lose | raft | 9 | 1001 `sail north`; deckhand 1002 aboard: `wait time 1`, `get 1001 19 2` |
| lose-ship | roundship | 9 | as lose: the control |

## Checks

For each case: exit status 0, and no AddressSanitizer or UBSan report on
stderr. In `lib/save/1/200`:

- **sail:** each leg takes two days, the base distance (out on day 1, arrive day 2; back on day 3, arrive day 4).
- **lose:** the deckhand takes two sailors on day 2. There is no `Loss of crew` line, and the raft still arrives on day 2.
- **lose-ship:** the same `get` gives a roundship `Loss of crew will cause travel to take an extra day.`, and it arrives on day 3. This shows the lose case reaches `check_captain_loses_sailors()`.

Neither raft case may get a `The crew of a …` line.

Before the fix, both raft cases exit 134. With only `move_exit_water()` fixed,
the lose case still exits 134 in `check_captain_loses_sailors()`.
