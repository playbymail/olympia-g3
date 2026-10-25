# governance-refused — governance orders that fail or are refused

Pins the `fail` and `rejected` outcomes of `garrison`, `ungarrison` and
`decree` (issue #150, backlog parent #116).

## Scenario

Five factions start in Greyfell (57081). `oly.makeloc` makes a castle,
Castle [67765], an unfinished castle, Castle-in-progress [60176], and a
tower, Tower [72332], in the city. The lord stands in the castle.

| Faction | Noble | Set up |
|---|---|---|
| 300 Lords | Lord One [4126] | in the castle |
| 301 Squires | Squire One [8651] | Forest [13451], Greyfell's province; 5 soldiers |
| 302 Pretenders | Pretender One [8159] | Plain [13450], west of the forest; 10 soldiers |
| 303 Usurpers | Usurper One [7012] | Catchclaw [58706] |
| 304 Outlanders | Outlander One [6947] | Plain [10113], in Idar, not Provinia; 10 soldiers |

| Unit | Order | Fails with |
|---|---|---|
| lord | `garrison 67765` | Garrisons may only be installed at province level. |
| lord | `decree` | Must specify what to decree. |
| lord | `decree tax` | Unknown decree 'tax'. |
| lord | `decree watch 57081` | 57081 is not a character. |
| lord | `decree watch 8651` | We rule over no garrisons. |
| lord | `decree hostile 8651` | We rule over no garrisons. |
| squire | `garrison` | Must specify a castle to claim the province in the name of. |
| squire | `garrison 60176` | Castle-in-progress [b176] is not finished. … |
| squire | `garrison 72332` | 72332 is not a castle. |
| squire | `garrison 67765` | Must have ten soldiers [12] to establish a new garrison. |
| squire | `ungarrison` | There is no garrison here. |
| squire | `ungarrison 1009` | No garrison 1009 is here. |
| pretender | `garrison 67765` | A garrison may only be installed in a province adjoining an existing garrison … |
| outlander | `garrison 67765` | Castle [k765] is not in this region. |
| usurper | `ungarrison` | Usurper One [7012] does not rule over Garrison [1009]. |

Catchclaw's garrison, seeded by `oly.load`, is bound to no castle, so
nobody rules it. The pretender's plain is in the castle's region, but the
castle is not in that province and no garrison bound to it adjoins.

Rejected: `garrison`, `ungarrison` and `decree` are for nobles (`c`), so
Catchclaw's garrison orders all three, and `check_allow()` refuses each.

Not pinned: "There is already a garrison here." and the castle's garrison
cap (`allowed_garrisons`) need a garrison at province level, or six bound
to one castle, before the turn. Seeded garrisons stand in cities, and
`oly` cannot make one; that waits on #134's `oly.add_garrison`.

## What `check.sh` asserts

1. `garrison`, `ungarrison` and `decree` reach `fail` and `rejected` in the
   turn's `--coverage` dump.
2. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match
   `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`governance-refused.lua` builds the scenario with `olyscript-g3`.
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
