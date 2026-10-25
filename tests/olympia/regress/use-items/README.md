# use-items — use of the item use keys

Pins the `ok` cells of the 15 item use keys, use group 9 (issue #218, use
backlog parent #180): the three potions (1–3), the palantir (4), the
proj_cast and quick_cast potions (5, 6), the drum (7), the faery stone (8),
the orb (9), the five golden rings (10–14) and the Skull of Bastrestric
(15). The `fail` cells of 4, 5, 6 and 9 are in
[use-items-refused](../use-items-refused/README.md); the rest are `n/a`,
because their starts always return TRUE.

## Scenario

Five factions, 300–304, start in Greyfell (57081). Magic items may not be
used in a safe haven, so every noble is poofed to Plain [13450]. The mage
and the skullbearer know Basic magic, so they are magicians.

Every unique item is minted before the turn by a binding: `oly.potion`,
`oly.orb`, `oly.ring`, `oly.palantir`, and `oly.relic` for the skull. One
made in the turn would have an id minted in the turn, which no order can
name. The drum (98) and the elfstone (69) are plain items.

| Faction | Noble | Setup | Orders |
|---|---|---|---|
| 300 Drinkers | Drinker One [4126] | sick (`oly.sick`), a heal and a death potion | `use` heal, `use` death |
| 301 Thralls | Thrall One [8651] | a slave potion whose creator is the mage | `use` slave |
| 302 Mages | Mage One [8159] | a proj_cast potion (Forest [13449]), a quick_cast potion (2), an orb (3 uses), a palantir | `use` proj_cast, `use` quick_cast, `use` orb 13449, `use` palantir 13449 |
| 303 Ringers | Ringer One [7012] | the five golden rings, a drum, an elfstone; a band of 5 savages (`oly.savage`) shares the plain | `use` each ring, `use 98`, `use 69` |
| 304 Skullbearers | Skullbearer One [6947] | the Skull of Bastrestric (`oly.relic`) | `use 403` |

Every start returns TRUE:

- The heal potion cures the drinker's sickness. The death potion poisons
  it, and it dies.
- The thrall drinks the mage's slave potion and deserts to the mage.
- The mage stores a projected cast to the forest and a cast speedup of 2.
  The orb shows the forest at once and keeps 2 uses. The palantir shows it
  on day 7.
- The barbarian ring fizzles ("Nothing happens"). The savage ring kills the
  savage band. Each ring vanishes.
- The drum sounds a battle challenge: with no speed after the item, the
  speed is 0 (#220). A band of savages comes in from a neighboring province
  and attacks Ringer One, who wins, takes the band prisoner and loots its
  drum.
- The elfstone opens no faery hill on the plain ("Nothing happens").
- The skull gives the magician a burst of aura, capped to its limit, and
  vanishes.

## What `check.sh` asserts

1. `use:ok` in the turn's `--coverage` dump, and the `ok` cells of all 15
   item use keys in its `--use-coverage` dump.
2. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`use-items.lua` builds the scenario with `olyscript-g3`;
`build-scenario.sh` freezes it as `scenario.patch` over the shared base world.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
