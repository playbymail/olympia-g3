# combat-refused — combat orders that fail or are refused

Pins the `fail` and `rejected` outcomes of the combat-family verbs (issue
#128, backlog parent #116): `attack`, `behind`, `guard`, `pillage`,
`surrender`, `execute` and `raze`.

## Scenario

One faction, **300** "Pacifists", whose noble Pacifist One [4126] starts in
Greyfell (57081), a safe haven.

The noble's orders all fail:

| Order | Outcome |
|---|---|
| `attack 4126` | fail: combat is not permitted in safe havens |
| `pillage` | fail: pillaging is not permitted in safe havens |
| `surrender 4126` | fail: can't surrender to oneself |
| `execute 4126` | fail: no such prisoner |
| `raze` | fail: not in a building |

`behind` and `guard` always return TRUE, so their `fail` cells are `n/a`.

The player entity issues all seven verbs and each one is refused
(rejected): every combat verb is for nobles (`c`, plus `r` for `attack`,
`behind`, `execute`, `pillage` and `raze`).

## What `check.sh` asserts

1. Every cell above reaches its outcome in the turn's `--coverage` dump.
2. The faction's report and unit state (`save/1/300`, `fact/300`) match
   `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`combat-refused.lua` builds the scenario with `olyscript-g3`.
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
