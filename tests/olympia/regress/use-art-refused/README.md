# use-art-refused — refused uses of the artifact construction skills

Pins the `fail` cells of the Artifact construction school, use group 6
(issue #204, use backlog parent #180): `forge_aura` (881), `write_art`
(882), `forge_weapon` (883), `forge_armor` (884), `forge_bow` (885),
`curse_noncreat` (886), `show_art_creat` (887), `show_art_reg` (888),
`destroy_art` (889), `cloak_creat` (891), `cloak_reg` (892),
`rem_art_cloak` (893) and `forge_palantir` (894).

## Scenario

Two factions, 300 Fumblers and 301 Novices, start in Greyfell (57081) and
are poofed to Plain [13450], since magic may not be used in a safe haven.
Each knows the Artifact construction school and starts with 200 gold. Each
skill known adds one aura. Every use below passes `v_use`'s shared checks
and reaches its start:

| Noble | Order | Skill | Start's refusal |
|---|---|---|---|
| Fumbler One [4126] | `use 881` | forge_aura | No aura-level specified. |
| | `use 882 841` | write_art | [882] only allows Artifact construction [880] spells to be scribed. |
| | `use 883 1` | forge_weapon | Requires 500 gold. |
| | `use 884 20` | forge_armor | 20 aura required, current level is 15. |
| | `use 885 1` | forge_bow | Requires 500 gold. |
| | `use 886 10` | curse_noncreat | The curse can not be applied to peasant [10]. |
| | `use 887 83` | show_art_creat | Fumbler One [4126] has no [83]. |
| | `use 888 82 99` | show_art_reg | 99 aura required, current level is 15. |
| | `use 889 10` | destroy_art | Cannot destroy peasant [10] with this spell. |
| | `use 891 83` | cloak_creat | Fumbler One [4126] does not have [83]. |
| | `use 892 83` | cloak_reg | Fumbler One [4126] does not have [83]. |
| | `use 893 83` | rem_art_cloak | Fumbler One [4126] does not have [83]. |
| Novice One [8651] | `use 894` | forge_palantir | Eight aura required, current level is two. |

The fumbler knows every skill of the school and Scry location (841), of the
Scrying school, so it has 15 aura. It holds 5 mithril and a blank scroll, and
no gate crystal [83]. The novice knows only Forge palantir, so it has 2 aura,
and holds a mithril and a gate crystal. The items are what the skills'
requirements ask in `lib/skill`, so each use gets past `meets_requirements`
to its start: a blank scroll for scribing and destroying, 100 gold and 5
mithril for cloaking the creator, and a mithril and a gate crystal for a
palantir.

## What `check.sh` asserts

1. `use:fail` in the turn's `--coverage` dump, and every skill's `fail`
   cell above in its `--use-coverage` dump.
2. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`use-art-refused.lua` builds the scenario with `olyscript-g3`;
`build-scenario.sh` freezes it as `scenario.patch` over the shared base world.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
