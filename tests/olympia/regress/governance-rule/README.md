# governance-rule — installing, ruling and disbanding a garrison

Pins the `ok` outcome of `garrison`, `decree` and `ungarrison`, and
`pledge` as the way the garrison's ruler is set (issue #150, backlog
parent #116).

## Scenario

Two factions start in Greyfell (57081). `oly.makeloc` makes a castle,
Castle [66159], in the city, and the lord stands in it, so it is the
castle's owner (`building_owner`):

| Faction | Noble | Set up | Orders |
|---|---|---|---|
| 300 Lords | Lord One [4126] | in the castle | `pledge 8651` |
| 301 Wardens | Warden One [8651] | Forest [13451], Greyfell's province; 20 soldiers | `garrison 66159`, `decree watch 4126`, `decree hostile 1009`, `ungarrison` |

- **pledge.** A priority-1 order, so it runs on day 1 before the warden's
  priority-3 garrison. The lord's lands are now the warden's.
- **garrison.** The forest is at province level and has no garrison
  (Greyfell is a safe haven, so `add_city_garrisons` seeds none). The
  castle is finished and in the same region, and it is in this province
  (`province_subloc` looks in the city too), so no adjoining garrison is
  needed. The warden spends 10 soldiers on Garrison [4277], whose id is
  minted (`new_char`, the `mint` stream).
- **decree.** The garrison is bound to the castle, whose owner pledged to
  the warden, so the warden rules it (`may_rule_here`, through
  `loop_loc_owner`). It has ten soldiers, so it takes both decrees: watch
  for the lord, and attack Catchclaw's seeded garrison [1009] on sight.
- **ungarrison.** The garrison disbands, and its ten soldiers go back to
  the warden, who ends the turn with 20.

## What `check.sh` asserts

1. `garrison`, `decree`, `ungarrison` and `pledge` reach `ok` in the
   turn's `--coverage` dump.
2. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match
   `EXPECT.sha256`. Garrisons and rulers are not in the state export
   (#114); the reports pin them.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`governance-rule.lua` builds the scenario with `olyscript-g3`.
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
