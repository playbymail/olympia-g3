# recruitment-refused — recruitment orders that fail or are refused

Pins the `fail` and `rejected` outcomes of the recruitment-family verbs
(issue #130, backlog parent #116): `recruit`, `form`, `raise` and `rally`.

## Scenario

One faction, **300** "Bunglers", whose noble Bungler One [4126] starts in
Greyfell (57081), builds a tower there and stands in it. It has no
recruitment skill.

The noble's orders all fail:

| Order | Outcome |
|---|---|
| `recruit 1` | fail: the tower has no peasants ("Peasants must be recruited in provinces.") |
| `form` | fail: nobles may only be formed in cities |
| `raise` | fail: requires Raise peasant mob |
| `rally 4126` | fail: requires Rally peasant mob |

The player entity issues the same four orders and each one is refused
(rejected): every recruitment verb is noble-only (`c`).

The skill is the first check in `v_raise` and `v_rally`, so their other
failures (no mob cookie here, no peasant mob to rally) aren't pinned.

## What `check.sh` asserts

1. Every cell above reaches its outcome in the turn's `--coverage` dump.
2. The faction's report and unit state (`save/1/300`, `fact/300`) match
   `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`recruitment-refused.lua` builds the scenario with `olyscript-g3`.
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
