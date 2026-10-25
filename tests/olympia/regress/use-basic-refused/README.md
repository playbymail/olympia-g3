# use-basic-refused — refused uses of the basic magic skills

Pins the `fail` cells of the Magic school, use group 4 (issue #196, use
backlog parent #180): `mage_menial` (802), `appear_common` (803),
`view_aura` (804), `heal` (805), `write_basic` (806), `reveal_mage` (807),
`detect_abil` (811), `dispel_abil` (812) and `hinder_med` (814).
`meditate` (801), `tap_health` (808), `shroud_abil` (809) and `adv_med`
(813) always start, so they cannot fail.

## Scenario

Two factions, 300 Bunglers and 301 Paupers, start in Greyfell (57081) and
are poofed to Forest [13550], which is not a safe haven and has no work at
common magic. Each noble knows the Magic school and the skills it uses.
Each skill known adds one aura. Every use below passes `v_use`'s shared
checks and reaches its start:

| Noble | Order | Skill | Start's refusal |
|---|---|---|---|
| Bungler One [4126] | `use 802` | mage_menial | No work at common magic can be found here. |
| | `use 805 8651` | heal | Pauper One [8651] is not sick. |
| | `use 806 801` | write_basic | Bungler One [4126] does not know [801]. |
| | `use 807 8651 0` | reveal_mage | 0 is not a valid skill category. |
| Pauper One [8651] | `use 803 99` | appear_common | 99 aura required, current level is six. |
| | `use 803 6` | appear_common | *(starts: spends all six aura)* |
| | `use 804 1` | view_aura | One aura required, current level is zero. |
| | `use 811` | detect_abil | One aura required, current level is zero. |
| | `use 812 4126` | dispel_abil | Three aura required, current level is zero. |
| | `use 814 4126 1` | hinder_med | One aura required, current level is zero. |

The bungler holds a blank scroll so that scribing gets past
`meets_requirements` to its start. Appear common charges its aura as it
starts, so the pauper's second use leaves it none for the rest.

## What `check.sh` asserts

1. `use:fail` in the turn's `--coverage` dump, and every skill's `fail`
   cell above in its `--use-coverage` dump.
2. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`use-basic-refused.lua` builds the scenario with `olyscript-g3`;
`build-scenario.sh` freezes it as `scenario.patch` over the shared base world.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
