# use-gate — use of the gatecraft skills

Pins the `ok` cells of the Gatecraft school, use group 5 (issue #202, use
backlog parent #180): `detect_gates` (861), `jump_gate` (862),
`write_gate` (863), `seal_gate` (864), `unseal_gate` (865),
`notify_unseal` (866), `rem_seal` (867), `reveal_key` (868),
`notify_jump` (869), `teleport` (871) and `rev_jump` (872).

## Scenario

Four factions, 300–303, start in Greyfell (57081) and are poofed to gates
the base world already has, since magic may not be used in a safe haven.
Each noble knows the Gatecraft school and all its skills; each skill known
adds one aura. No binding is needed: the gates of the hidden ring of stones
[64135] on Plain [12239] are sealed in the base world.

| Faction | Noble | Where | Aura | Setup | Orders |
|---|---|---|---|---|---|
| 300 Jumpers | Jumper One [4126] | Mountain [13344] | 13 | a gate crystal, no peasants | `use 869 70456`, `use 862 70456`, `use 872 70456`, `use 871 13450` |
| 301 Sealers | Sealer One [8651] | Forest [13343] | 12 | a blank scroll | `use 861`, `use 864 60605 123`, `use 865 60605 123`, `use 863 861` |
| 302 Keyfinders | Keyfinder One [8159] | ring [64135] | 12 | — | `use 868 59070` |
| 303 Watchers | Watcher One [7012] | ring [64135] | 13 | — | `use 866 59070 237`, `use 867 59070` |

Every start returns TRUE:

- The jumper has itself told of jumps through Gate [70456], jumps it to
  Swamp [10896], jumps back the wrong way to the mountain (each jump is
  reported to it) and teleports to Plain [13450], spending its crystal.
  Jumping costs one aura per 250 weight and teleporting one per 50, so the
  jumper leaves its 25 peasants behind: its stack weighs 101 and its uses
  cost 6 + 1 + 2 + 3 aura.
- The sealer detects Gate [60605], to Ocean [13353], seals it with key 123,
  unseals it with that key, and spends two weeks scribing Detect gates,
  which does not finish this turn.
- The keyfinder learns that the key to Gate [59070] is 237.
- The watcher has itself told when Gate [59070] is unsealed, then breaks
  the seal and is told.

Skill 863 is named Language of the Ancients in the database.

## What `check.sh` asserts

1. `use:ok` in the turn's `--coverage` dump, and every skill's `ok` cell
   above in its `--use-coverage` dump.
2. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`use-gate.lua` builds the scenario with `olyscript-g3`;
`build-scenario.sh` freezes it as `scenario.patch` over the shared base world.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
