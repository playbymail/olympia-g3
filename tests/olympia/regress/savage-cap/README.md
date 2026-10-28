# savage-cap — MAX_SAVAGES caps a turn's savage spawns

Pins the fix for #354. `init_savage_attacks` (`olympia/savage.c`) counts the
world's savage units on day 0 and stops if there are `MAX_SAVAGES` (200).
Then each fort draws a keyed 1-in-100 roll, and one that rolls 1 calls a
band of savages to attack it. The count was checked only before the loop,
so from 199 savages every fort that drew the roll spawned a band, past the
cap. Now `call_savage` counts each band it makes, and `init_savage_attacks`
spawns no more once the count reaches the cap. A drum's call (`use_drum`)
already checked the count, which now includes the turn's spawns.

## Scenario

One faction starts in Greyfell (57081). Builder One [4126] is put in Plain
[13450] and raises 300 towers there (`oly.makeloc`); three of them draw the
spawn roll on turn 1. 199 bands of one savage each wait in the forest
[13449] (`oly.savage`), one short of the cap.

With the fix the first tower that draws the roll gets a band, which brings
the count to 200, and the other two get none: `init_savage_attacks:spawn`
acts once. Before the fix it acted three times.

## What `check.sh` asserts

1. The turn's `--phase-coverage` dump has `init_savage_attacks:spawn`
   acted exactly once.
2. The Builders' report and unit state (`save/1/300`, `fact/300`) match
   `EXPECT.sha256`.

## Authored in Lua

`savage-cap.lua` builds the scenario with `olyscript-g3`;
`build-scenario.sh` freezes it as `scenario.patch` over the shared base
world.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
