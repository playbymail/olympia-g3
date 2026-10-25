# use-gate-refused — refused uses of the gatecraft skills

Pins the `fail` cells of the Gatecraft school, use group 5 (issue #202, use
backlog parent #180): `detect_gates` (861), `jump_gate` (862),
`write_gate` (863), `seal_gate` (864), `unseal_gate` (865),
`notify_unseal` (866), `rem_seal` (867), `reveal_key` (868),
`notify_jump` (869), `teleport` (871) and `rev_jump` (872).

## Scenario

Two factions, 300 Drainers and 301 Fumblers, start in Greyfell (57081) and
are poofed to Mountain [13344], since magic may not be used in a safe
haven. The mountain holds Gate [70456], unsealed, to Swamp [10896]. Each
noble knows the Gatecraft school and all its skills; each skill known adds
one aura. Every use below passes `v_use`'s shared checks and reaches its
start:

| Noble | Order | Skill | Start's refusal |
|---|---|---|---|
| Drainer One [4126] | `use 869 70456` | notify_jump | *(starts: six of its twelve aura)* |
| | `use 869 70456` | notify_jump | *(starts: the other six)* |
| | `use 861` | detect_gates | One aura required, current level is zero. |
| Fumbler One [8651] | `use 862 60605` | jump_gate | There is no gate [60605] here. |
| | `use 863 841` | write_gate | [863] only allows Gatecraft [860] spells to be scribed. |
| | `use 864 70456 0` | seal_gate | Must specify a key to seal the gate with. |
| | `use 865 70456 1` | unseal_gate | The gate is not sealed. |
| | `use 866 70456 1` | notify_unseal | The gate is not sealed. |
| | `use 867 70456` | rem_seal | The gate is not sealed. |
| | `use 868 70456` | reveal_key | Gate [70456] is not sealed. |
| | `use 869 60605` | notify_jump | There is no gate [60605] here. |
| | `use 871 13450` | teleport | Teleportation requires one gate crystal [83]. |
| | `use 872 70456` | rev_jump | No gate [70456] leads here. |

Gate [60605] is on Forest [13343]. The fumbler also knows Scry location
(841), of the Scrying school, and holds a blank scroll so that scribing gets
past `meets_requirements` to its start.

## What `check.sh` asserts

1. `use:ok` and `use:fail` in the turn's `--coverage` dump, and every
   skill's `fail` cell above in its `--use-coverage` dump.
2. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`use-gate-refused.lua` builds the scenario with `olyscript-g3`;
`build-scenario.sh` freezes it as `scenario.patch` over the shared base world.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
