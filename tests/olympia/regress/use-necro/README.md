# use-necro — use of the necromancy skills

Pins the `ok` cells of the Necromancy school, use group 7 (issue #214, use
backlog parent #180): `raise_corpses` (901), `write_necro` (903),
`undead_lord` (904), `renew_undead` (905), `banish_undead` (906),
`eat_dead` (907), `aura_blast` (908) and `absorb_blast` (909).
`summon_ghost` (902) and `transcend_death` (911) point at `v_implicit`, so
they have no `ok`.

## Scenario

Seven factions, 300–306, start in Greyfell (57081). Magic may not be used
in a safe haven, so the raiser and the summoner are poofed to Graveyard
[59022], the renewer to Graveyard [59095], and the rest to Plain [13450].
Each graveyard in the base world holds 15 corpses and an undead cookie.
The necromancers know the Necromancy school and all its skills; each skill
known adds one aura. The renewer's demon lord comes from `oly.undead`: one
summoned in the turn has an id minted in the turn, which no order can name.

| Faction | Noble | Setup | Orders |
|---|---|---|---|
| 300 Raisers | Raiser One [4126] | in Graveyard [59022], a blank scroll | `use 901 5`, `use 903 908` |
| 301 Summoners | Summoner One [8651] | in Graveyard [59022] | `use 904 3` |
| 302 Renewers | Renewer One [8159] | in Graveyard [59095], Demon lord [7012] | `use 905 7012`, `use 906 7012` |
| 303 Eaters | Eater One [7719] | ratspider venom, dead body [5846] | `use 907 5846` |
| 304 Blasters | Blaster One [6895] | | `use 908 2176 2` |
| 305 Absorbers | Absorber One [2176] | knows only Absorb aura blast | `use 909 0` |
| 306 Departed | Departed One [5846] | knows Shipcraft; killed with `oly.kill` before the turn, its body handed to the eater | |

Every start returns TRUE:

- The raiser raises five corpses, one a day, then scribes Aura blast onto
  its blank scroll in three weeks. Two of its corpses decompose at month
  end.
- The summoner spends 3 aura and summons Demon lord [1728] with 21 corpses,
  which stacks beneath it and spends the graveyard's cookie.
- The renewer renews its demon lord's bond for 3 aura ("will remain for 9
  months"), then banishes it for 6.
- The eater spends the venom and 5 aura, eats the departed's body, and
  learns Shipcraft from it. Its draw to die (one in three) misses.
- The blaster blasts the absorber with 2 aura. The absorber has set itself
  to absorb blasts, so it gains 1 aura instead of taking damage.

## What `check.sh` asserts

1. `use:ok` in the turn's `--coverage` dump, and every skill's `ok` cell
   above in its `--use-coverage` dump.
2. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`use-necro.lua` builds the scenario with `olyscript-g3`;
`build-scenario.sh` freezes it as `scenario.patch` over the shared base world.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
