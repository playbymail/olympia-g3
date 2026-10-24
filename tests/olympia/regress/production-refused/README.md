# production-refused — production orders that fail or are refused

Pins the `fail` and `rejected` outcomes of every production-family verb
(issue #126, backlog parent #116): `make`, `train`, `quarry`, `stone`,
`collect`, `wood`, `yew`, `mallorn`, `opium`, `catch` and `fish`.

## Scenario

One faction, **300** "Bunglers", whose noble Bungler One [4126] starts in
Greyfell (57081) with no production skill. Its 25 peasants are taken away.

The noble's orders all fail:

| Order | Outcome |
|---|---|
| `make 11 1`, `train 11 1` | fail: no peasants to make workers from |
| `quarry 1`, `stone 1`, `collect 78 1` | fail: requires Stone quarrying |
| `wood 1` | fail: requires Harvest lumber |
| `yew 1` | fail: requires Harvest yew |
| `mallorn 1` | fail: requires Harvest mallorn wood |
| `opium 1` | fail: requires Harvest opium |
| `catch 1` | fail: requires Catch wild horses |
| `fish 1` | fail: requires Fishing |

The player entity issues the same eleven orders and each one is refused
(rejected): every production verb is noble-only (`c`).

The harvest skill is the first check in `v_generic_harvest`, so the place
doesn't matter here. The other harvest failures (no workers or sailors, or
nothing left to take) come after it, and aren't pinned.

## What `check.sh` asserts

1. Every cell above reaches its outcome in the turn's `--coverage` dump.
2. The faction's report and unit state (`save/1/300`, `fact/300`) match
   `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`production-refused.lua` builds the scenario with `olyscript-g3`.
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
