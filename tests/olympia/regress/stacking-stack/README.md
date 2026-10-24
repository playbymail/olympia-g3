# stacking-stack — stacking orders that start

Pins the `ok` outcome of the stacking-family verbs (issue #141, backlog
parent #116): `stack`, `unstack` and `promote`.

## Scenario

Three factions start in Greyfell (57081).

| Unit | Orders |
|---|---|
| Leader One [4126] (300 "Leaders") | `admit 4126 8651 8159`, `wait day 3`, `promote 8159`, `wait day 5`, `unstack 8651` |
| Visitor One [8651] (301 "Visitors") | `wait day 1`, `stack 4126`, `wait day 2`, `unstack`, `wait day 4`, `stack 4126` |
| Joiner One [8159] (302 "Joiners") | `wait day 1`, `stack 4126`, `wait day 4`, `stack 4126` |

Every start returns TRUE. In order:

1. The visitor and the joiner `stack` under the leader, which the admit
   allows (other factions need one; `will_admit`).
2. The visitor leaves with a bare `unstack`.
3. The leader `promote`s the joiner. It is stacked right beneath the
   leader, so the promote is allowed across factions; it moves the joiner
   out of the stack, ahead of the leader in Greyfell's location order.
4. Both stack again, and the leader drops the visitor with `unstack 8651`.

The turn ends with the joiner stacked under the leader and the visitor on
its own.

## What `check.sh` asserts

1. `stack`, `unstack` and `promote` reach `ok` in the turn's `--coverage`
   dump.
2. The three factions' reports and unit state (`save/1/30{0,1,2}`,
   `fact/30{0,1,2}`) match `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`. It shows
   the final `stacked_under`, but its `here` list is in id order, not
   location order, so the promote's reordering is pinned only by the hashes
   (#114).

## Authored in Lua

`stacking-stack.lua` builds the scenario with `olyscript-g3`.
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
