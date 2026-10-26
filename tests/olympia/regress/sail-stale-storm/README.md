# sail-stale-storm — a ship arrives with a dead storm in its bound list

Pins the fix for issue #250. When a ship arrives, `move_bound_storms`
(`olympia/storm.c`) moves each storm bound to it into the new province, and
drops any entry of the ship's bound-storm list that is no longer a storm:

```c
if (kind(storm) != T_storm)
{
	ilist_delete(&p->bound_storms, storm);
	i--;
	continue;
}
```

`ilist_delete` takes a list **index** and asserts it is in range. It was
passed the storm number (99374 here), so the turn aborted on
`Assertion failed: (i >= 0 && i < len), function ilist_delete`. It now
passes `i`.

The engine's own paths keep the list clean: `dissipate_storm` removes a
storm from the list of the ship its bind field names. A DB written while
`d_bind_storm` set that field to the storm itself (#169, fixed by PR #174)
breaks this: the ship lists the storm, but the storm names no ship, so
when it dissipates the ship keeps the dead entry, and the turn aborts the
next time the ship arrives anywhere.

## Scenario

One faction, 300 "Stale Storms". Captain One [4126] knows Sailing, Weather
magic, Bind storm to ship and Dissipate storm, and has eight sailors. It
stands on a roundship [61319] it built at sea in Ocean [13350], and owns
two storms `oly.storm` (#170) raises there, each of strength 6:

| Storm | State before the turn |
|---|---|
| Rain [99374] | in the ship's bound list (`SL` / `bs 99374`), with its own bind field naming itself (`MI` / `bs 99374`): the pre-#169 shape |
| Wind [88781] | unbound |

No binding writes the pre-#169 shape, so `sail-stale-storm.lua` appends
those two fields to the saved `lib/ship` and `lib/misc` after `oly.save`.

Orders: `use 822 88781` (bind the wind; the list becomes rain, wind),
`use 828 99374` (dissipate the rain; it stays in the list as a deleted box)
and `sail north`. On day 17 the ship arrives in Ocean [13250];
`move_bound_storms` drops the rain at index 0, steps back, and moves the
wind, now at index 0, north with the ship.

Without the fix the turn aborts on arrival and `check.sh` prints
`NO  (olympia-g3 turn failed: exit 134)`.

## What `check.sh` asserts

1. The turn completes.
2. In the saved DB the ship is in Ocean [13250] and its bound list is
   `bs 88781` alone; the wind is in Ocean [13250] and bound to the ship;
   the rain is gone.
3. `use:ok` and `sail:ok` in the turn's `--coverage` dump.
4. The faction's report and unit state (`save/1/300`, `fact/300`) match
   `EXPECT.sha256`.
5. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`sail-stale-storm.lua` builds the scenario with `olyscript-g3`;
`build-scenario.sh` freezes it as `scenario.patch` over the shared base
world.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
