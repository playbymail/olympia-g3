# use-orb-plain — use of the plain crystal orb

Pins the fix for issue #221: using the base world's crystal orb (item 290)
aborted the turn. Item 290 is a plain, non-unique item with the orb use key
(9), but `v_use_orb` treated every orb as a unique one made by `new_orb`. It
decremented a use count that item 290 does not have and then called
`destroy_unique_item`, which asserts `item_unique(item)`. A plain orb now
shatters after one vision, and `consume_item` spends one of the stack. The
`ok` cell of use key 9 is also in [use-items](../use-items/README.md), with a
unique orb from `oly.orb`.

No engine code gives item 290 out; a GM can with `additem`.

## Scenario

One faction, 300, starts in Greyfell (57081) and is poofed to Plain
[13450], since magic items may not be used in a safe haven.

| Faction | Noble | Setup | Orders |
|---|---|---|---|
| 300 Seers | Seer One [4126] | two crystal orbs [290] (`oly.additem`) | `wait time 2`, `use 290 13449` |

- On day 1 the orb's 1-in-3 murky roll would return before the shatter; the
  wait moves the use to day 2, where it does not.
- The orb shows Forest [13449], shatters, and Seer One keeps one orb.

## What `check.sh` asserts

1. `use:ok` in the turn's `--coverage` dump, and the `ok` cell of item use
   key 9 in its `--use-coverage` dump.
2. The faction's report and unit state (`save/1/300`, `fact/300`) match `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`use-orb-plain.lua` builds the scenario with `olyscript-g3`;
`build-scenario.sh` freezes it as `scenario.patch` over the shared base world.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
