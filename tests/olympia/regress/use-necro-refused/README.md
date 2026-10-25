# use-necro-refused — refused uses of the necromancy skills

Pins the `fail` cells of the Necromancy school, use group 7 (issue #214,
use backlog parent #180): `raise_corpses` (901), `write_necro` (903),
`undead_lord` (904), `renew_undead` (905), `banish_undead` (906),
`eat_dead` (907) and `aura_blast` (908). `absorb_blast` (909) has no
`fail`: `v_aura_reflect` always returns TRUE. The `fail` of the two
`v_implicit` rows, `summon_ghost` (902) and `transcend_death` (911), is
left to group 10.

## Scenario

Two factions, 300 Fumblers and 301 Novices, start in Greyfell (57081).
Magic may not be used in a safe haven, so the fumbler is poofed to Plain
[13450] and the novice to Graveyard [59022]. Each knows the Necromancy
school and starts with 200 gold. Each skill known adds one aura. Every use
below passes `v_use`'s shared checks and reaches its start:

| Noble | Order | Skill | Start's refusal |
|---|---|---|---|
| Fumbler One [4126] | `use 901 5` | raise_corpses | Corpses are found in graveyards. |
| | `use 903 841` | write_necro | [903] only allows Necromancy [900] spells to be scribed. |
| | `use 904 3` | undead_lord | Demon lords may only be summoned in graveyards. |
| | `use 905 4126` | renew_undead | [4126] is not a demon lord. |
| | `use 907 10` | eat_dead | [10] is not the dead body of a noble. |
| | `use 908 8651 2` | aura_blast | [8651] cannot be seen here. |
| Novice One [8651] | `use 906 4126` | banish_undead | Six aura required, current level is two. |

The fumbler knows every skill of the school and Scry location (841), of the
Scrying school, and holds the blank scroll Runes of Evil requires in
`lib/skill`, so `use 903` gets past `meets_requirements` to its start. The
novice knows only Banish demon lord, so it has 2 aura.

## What `check.sh` asserts

1. `use:fail` in the turn's `--coverage` dump, and every skill's `fail`
   cell above in its `--use-coverage` dump.
2. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`use-necro-refused.lua` builds the scenario with `olyscript-g3`;
`build-scenario.sh` freezes it as `scenario.patch` over the shared base world.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
