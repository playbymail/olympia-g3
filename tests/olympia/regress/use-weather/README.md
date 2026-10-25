# use-weather — use of the weather magic skills

Pins the `ok` cells of the Weather magic school, use group 4 (issue #196,
use backlog parent #180): `fierce_wind` (821), `bind_storm` (822),
`write_weather` (823), `summon_wind` (824), `summon_rain` (825),
`summon_fog` (826), `direct_storm` (827), `dissipate` (828),
`renew_storm` (829), `lightning` (831), `seize_storm` (832) and
`death_fog` (833).

## Scenario

Six factions, 300–305, start in Greyfell (57081) and are poofed out of it,
since magic may not be used in a safe haven. Each mage knows the Weather
magic school and the skills it uses; each skill known adds one aura. The
storms, of strength 6, are raised by `oly.storm` (#170).

| Faction | Noble | Place | Setup | Orders |
|---|---|---|---|---|
| 300 Windcallers | Windcaller One [4126] | Plain [13450] | Tower [61319] there; owns Wind [99374] over the plain; a blank scroll | `use 829 99374 2`, `use 827 99374 13449`, `use 821 99374 61319 1`, `use 823 821` |
| 301 Rainmakers | Rainmaker One [8533] | Forest [13550] | owns Rain [144746] and Fog [84087] over the forest | `use 831 144746 6523 1`, `use 833 84087 6523 1`, `use 828 144746` |
| 302 Victims | Victim One [6523] | Forest [13550] | 10 peasants | — |
| 303 Binders | Binder One [5303] | Roundship [61618] in Ocean [13350] | owns Rain [81927] over the ocean | `use 822 81927`, `use 824` |
| 304 Seizers | Seizer One [8731] | the same ship | Fog [128367] over the ocean has no owner | `use 832 128367` |
| 305 Summoners | Summoner One [8761] | Forest [13449] | — | `use 825`, `use 826` |

Every start returns TRUE:

- The windcaller renews its wind to strength 10, directs it west to Forest
  [13449] for month end, and has it buffet the tower for one strength (1%
  damaged). The wind moves west at month end, at strength 8 after decay.
  The windcaller then spends three weeks scribing Fierce wind, which does
  not finish this turn.
- The rainmaker strikes the victim with lightning (health 99), kills two of
  its peasants with the fog of death and dissipates the rest of the rain,
  for five aura.
- The binder binds its rain to the ship, then summons Wind [116228] at sea.
  The seizer takes control of the unowned fog.
- The summoner raises Rain [122602] and Fog [145244] over Forest [13449].

`lightning` and `death_fog` strike only a character standing in the storm's
province, so the victim stands in the forest, not in a building or ship.
`bind_storm` needs a ship in the storm's province, so the binder's ship is
built at sea.

**Fierce wind spends only the aura it is given** (#197). Before the fix,
`d_fierce_wind` capped the aura with an inverted comparison, so the wind spent
the whole storm and dissipated it, and the direct order had nothing to move.

## What `check.sh` asserts

1. `use:ok` in the turn's `--coverage` dump, and every skill's `ok` cell
   above in its `--use-coverage` dump.
2. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`use-weather.lua` builds the scenario with `olyscript-g3`;
`build-scenario.sh` freezes it as `scenario.patch` over the shared base world.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
