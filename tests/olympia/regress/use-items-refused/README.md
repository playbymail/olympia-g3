# use-items-refused — refused use of the item use keys

Pins the reachable `fail` cells of the item use keys, use group 9 (issue
#218, use backlog parent #180): the palantir (4), the proj_cast and
quick_cast potions (5, 6) and the orb (9). The `ok` cells are in
[use-items](../use-items/README.md). The other item starts always return
TRUE, so their `fail` cells are `n/a`.

## Scenario

Two factions, 300 and 301, start in Greyfell (57081) and are poofed to
Plain [13450], since magic items may not be used in a safe haven. The seer
knows Basic magic, so it is a magician; the dabbler is not.

| Faction | Noble | Setup | Orders |
|---|---|---|---|
| 300 Dabblers | Dabbler One [4126] | a proj_cast potion (Forest [13449]), a quick_cast potion (2) (`oly.potion`) | `use` proj_cast, `use` quick_cast |
| 301 Seers | Seer One [8651] | a palantir (`oly.palantir`), an orb with 3 uses (`oly.orb`) | `use` palantir 8651, `use` orb 13449 twice |

- The dabbler is no magician, so each potion does nothing, is spent, and
  its start returns FALSE.
- The seer names itself, not a location, to the palantir.
- The first orb use shows the forest. An orb may be used only once a
  month, so the second fails.

## What `check.sh` asserts

1. `use:fail` in the turn's `--coverage` dump, and the `fail` cells of
   item use keys 4, 5, 6 and 9 in its `--use-coverage` dump.
2. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`use-items-refused.lua` builds the scenario with `olyscript-g3`;
`build-scenario.sh` freezes it as `scenario.patch` over the shared base world.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
