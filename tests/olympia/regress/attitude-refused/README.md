# attitude-refused — attitude orders that fail or are refused

Pins the `fail` and `rejected` outcomes of the attitude-family verbs (issue
#129, backlog parent #116): `admit`, `contact`, `default`, `defend`,
`hostile` and `neutral`.

## Scenario

One faction, **300** "Strangers", whose noble Stranger One [4126] starts in
Greyfell (57081).

- The noble orders `admit` with no target: fail, "Must specify an entity
  for admit."
- `contact`, `default`, `defend`, `hostile` and `neutral` always return
  TRUE (a bad target only gets a message), so their `fail` cells are `n/a`.
- The player entity orders `contact 4126`: rejected, since `contact` is
  for nobles (`cr`).
- The other five verbs are `cpr`, so a player can issue them. The garrison
  of Catchclaw [58706], garrison 1009 (seeded by `oly.load`), orders all
  five and each is rejected. Its messages go to the garrison player's
  report, so only the coverage check pins them.

## What `check.sh` asserts

1. Every cell above reaches its outcome in the turn's `--coverage` dump.
2. The faction's report and unit state (`save/1/300`, `fact/300`) match
   `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`attitude-refused.lua` builds the scenario with `olyscript-g3`.
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
