# use-weather-refused — refused uses of the weather magic skills

Pins the `fail` cells of the Weather magic school, use group 4 (issue #196,
use backlog parent #180): `fierce_wind` (821), `bind_storm` (822),
`write_weather` (823), `summon_wind` (824), `summon_rain` (825),
`summon_fog` (826), `direct_storm` (827), `dissipate` (828),
`renew_storm` (829), `lightning` (831), `seize_storm` (832) and
`death_fog` (833).

## Scenario

One faction, 300 Bunglers. Its noble, Bungler One [4126], knows the
Weather magic school and every skill in it (13 aura), holds a blank scroll,
and is poofed to Plain [13450]. `oly.storm` raises two storms it owns:
Wind [135802] over the plain, which spends the plain's wind cookie, and Rain
[99374] over Forest [13550], to the south. Every use passes `v_use`'s shared
checks, reaches its start, and fails there:

| Order | Skill | Start's refusal |
|---|---|---|
| `use 821 135802 13450` | fierce_wind | [13450] is not a valid target. |
| `use 822 135802` | bind_storm | Bungler One [4126] must be on a ship to bind the storm to. |
| `use 823 840` | write_weather | Bungler One [4126] does not know [840]. |
| `use 824` | summon_wind | A storm has already been summoned from this province. |
| `use 825` | summon_rain | Rain may not be summoned here. |
| `use 826` | summon_fog | Fog may not be summoned here. |
| `use 827 13450` | direct_storm | You don't control any storm [13450]. |
| `use 828 99374` | dissipate | Rain [99374] is not here. |
| `use 829 13450` | renew_storm | [13450] is not a storm. |
| `use 831 135802 4126` | lightning | Wind [135802] is not a rain storm. |
| `use 832 135802` | seize_storm | You already control Wind [135802]. |
| `use 833 99374 4126` | death_fog | Rain [99374] is not a fog. |

The blank scroll gets scribing past `meets_requirements` to its start.

## What `check.sh` asserts

1. `use:fail` in the turn's `--coverage` dump, and every skill's `fail`
   cell above in its `--use-coverage` dump.
2. The faction's report and unit state (`save/1/300`, `fact/300`) match `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`use-weather-refused.lua` builds the scenario with `olyscript-g3`;
`build-scenario.sh` freezes it as `scenario.patch` over the shared base world.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
