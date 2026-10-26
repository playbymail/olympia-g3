# raze-rebuild — a deleted box does not stay in the chain cache

Pins the fix for #246. `add_next_chain()` and `add_sub_chain()`
(`olympia/code.c`) keep a static cache of the last box they added. When the
next box has the same kind (or subkind), a higher id, and the cached box is
the tail of its chain (`x_next_kind == 0`), they append the new box after the
cached one without walking the chain.

`delete_box()` calls `remove_next_chain()` and `remove_sub_chain()`, which
unlink the box and set its link to 0, but left the cache alone. If the deleted
box was the cached one, the next box of that kind with a higher id passed all
three tests and was linked after a box that was no longer on the chain. It
was then missing from `loop_kind` and `loop_subkind`, and a later
`remove_next_chain()` or `remove_sub_chain()` on it would fail `assert(i > 0)`.

Now the caches are file-scope statics, and `remove_next_chain()` and
`remove_sub_chain()` clear theirs when they remove the cached box. The
shortcut gives the same chain as the walk whenever the cache is valid, so the
only change in behavior is in that stale case.

## Why the goldens don't move

The stale case needs the box added last to be deleted, and then a box of the
same kind and a higher id to be added, with nothing added in between. Neither
golden turn does that, so both trees are byte-identical. The turn's storms do
not hit it either: natural weather adds storms on four days of the month,
while `storm_decay()` deletes them only at month end.

## Scenario

One faction starts in Greyfell (57081). The scenario is built by
`raze-rebuild.lua`:

| Faction | Noble | Set up | Orders |
|---|---|---|---|
| 300 Razers | Razer One [4126] | knows Construction [680]; 300 workers, 100 stone; unformed ids 1375 and 3743 | `wait time 2`, `build tower First 1 1375`, `raze`, `build tower Second 1 3743` |

- **Day 4.** `build` claims the lower unformed id. `start_build()` changes
  1375 to a `T_loc` / `sub_tower_notdone`, which makes it the cached box of
  both chains.
- **Day 5.** Its 327 men are worth 163 raze points a day, capped at 100,
  so First [1375] collapses on the first day of `raze`, and
  `delete_box(1375)` removes it from both chains.
- **Day 6.** `build` claims the higher unformed id, 3743. Before the fix,
  the stale caches linked it after 1375 on both chains, so `save_db` (which
  writes `lib/loc` by walking the `T_loc` chain) left it out of `lib/loc`,
  and `write_leftovers` put it in `lib/misc`. With the fix it is in
  `lib/loc`.

The `wait time 2` keeps the three steps clear of the turn's weather days
(1, 3, 9 and 26 under this seed). Natural weather adds about 1,600 storms on
each of those days, which resets the cache. Both ids are the faction's
unformed ids, which the orders name, so no id minted in the turn is needed.

## Checks

The turn exits 0; `3743 loc tower-in-progress` is in `lib/loc`; and the
whole post-turn `lib` matches `EXPECT.sha256` byte for byte. Before the fix
the second check fails on both presets:
`NO  (tower 3743 is not in lib/loc: it fell off the T_loc chain)`.

## Authored in Lua

`raze-rebuild.lua` builds the scenario with `olyscript-g3`.
`build-scenario.sh` runs it on the bare map and freezes the result as
`scenario.patch` over the shared base world. The script never runs the `-a`
pass, so `build-scenario.sh` also swaps in `world.tgz`'s `lib/log`; a turn
deletes `lib/log` before it writes anything, so it is not turn input.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
