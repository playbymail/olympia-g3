# stacking-refused — stacking orders that fail or are refused

Pins the `fail` and `rejected` outcomes of the stacking-family verbs (issue
#141, backlog parent #116): `stack`, `unstack` and `promote`.

## Scenario

Two factions start in Greyfell (57081): Loner One [4126] (300 "Loners")
and Stranger One [8651] (301 "Strangers"). The loner orders:

| Order | Fails with |
|---|---|
| `stack 4126` | Can't stack beneath oneself. |
| `stack 8651` | Stranger One refuses to let us stack (no `admit`). |
| `unstack` | Not stacked under anyone. |
| `unstack 8651` | 8651 is not stacked beneath us. |
| `promote` | Must specify which character to promote. |
| `promote 4126` | Can't promote oneself. |

The stranger's report gets "Refused to let Loner One stack with us."

The player entity orders `stack 4126`, `unstack` and `promote 4126`: each
is rejected, since all three verbs are for nobles (`cr`).

## What `check.sh` asserts

1. Every verb reaches both `fail` and `rejected` in the turn's
   `--coverage` dump.
2. Both factions' reports and unit state (`save/1/30{0,1}`, `fact/30{0,1}`)
   match `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`stacking-refused.lua` builds the scenario with `olyscript-g3`.
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
