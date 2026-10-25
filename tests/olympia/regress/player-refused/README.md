# player-refused — player orders that fail or are refused

Pins the `rejected` outcomes of the player-family verbs, and the `fail` of
`wait` (issue #152, backlog parent #116): `format`, `message`, `name`,
`notab`, `post`, `press`, `public`, `realname`, `rumor`, `split`, `stop`,
`times` and `wait`.

## Scenario

One faction, **300** "Strangers", whose noble Stranger One [4126] starts in
Greyfell (57081).

- The noble orders `wait` with no condition: fail, "Must say what condition
  to wait for."
- The player entity orders `post 1` and `wait time 1`: rejected, since
  `post` is for nobles (`c`) and `wait` for nobles and the GM (`crm`).
- The other eleven verbs are `cp` or `cpr`, so a player can issue them. The
  garrison of Catchclaw [58706], garrison 1009 (seeded by `oly.load`),
  orders all eleven and each is rejected. Its messages go to the garrison
  player's report, so only the coverage check pins them.

The other player-family `fail` cells are pinned by `player-settings` and
`player-press`, or are `n/a`: `format`, `notab`, `stop` and `times` always
return TRUE.

## What `check.sh` asserts

1. Every cell above reaches its outcome in the turn's `--coverage` dump.
2. The faction's report and unit state (`save/1/300`, `fact/300`) match
   `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`player-refused.lua` builds the scenario with `olyscript-g3`.
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
