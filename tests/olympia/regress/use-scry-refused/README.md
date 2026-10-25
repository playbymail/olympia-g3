# use-scry-refused — refused uses of the scrying skills

Pins the `fail` cells of the Scrying school, use group 4 (issue #196, use
backlog parent #180): `scry_region` (841), `write_scry` (842),
`shroud_region` (843), `dispel_region` (844), `bar_loc` (845), `unbar_loc`
(846), `locate_char` (847), `detect_scry` (848), `proj_cast` (849) and
`save_proj` (851). `banish_corpses` (852) always starts, so it cannot fail.

## Scenario

Two factions, 300 Bunglers and 301 Paupers, start in Greyfell (57081) and
are poofed to Plain [13450], since magic may not be used in a safe haven.
Each noble knows the Scrying school and the skills it uses. Each skill
known adds one aura. Every use below passes `v_use`'s shared checks and
reaches its start:

| Noble | Order | Skill | Start's refusal |
|---|---|---|---|
| Bungler One [4126] | `use 841 4126 1` | scry_region | [4126] is not a location. |
| | `use 842 801` | write_scry | Bungler One [4126] does not know [801]. |
| | `use 846 0 1` | unbar_loc | There is no barrier over Plain [13450]. |
| | `use 847 13450` | locate_char | [13450] is not a character. |
| | `use 849 13451` | proj_cast | Magic may not be projected to safe havens. |
| | `use 851` | save_proj | No projected cast state is active. |
| Pauper One [8651] | `use 843 99` | shroud_region | 99 aura required, current level is five. |
| | `use 845 8` | bar_loc | Eight aura required, current level is five. |
| | `use 843 5` | shroud_region | *(starts: an aura-ten shroud, for all five aura)* |
| | `use 844 13450` | dispel_region | Three aura required, current level is zero. |
| | `use 848` | detect_scry | One aura required, current level is zero. |

The bungler holds a blank scroll so that scribing gets past
`meets_requirements` to its start. Forest [13451], Greyfell's province, is
a safe haven.

## What `check.sh` asserts

1. `use:fail` in the turn's `--coverage` dump, and every skill's `fail`
   cell above in its `--use-coverage` dump.
2. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`use-scry-refused.lua` builds the scenario with `olyscript-g3`;
`build-scenario.sh` freezes it as `scenario.patch` over the shared base world.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
