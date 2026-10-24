# inventory-refused — inventory orders that fail or are refused

Pins the `fail` and `rejected` outcomes of the inventory-family verbs
(issue #127, backlog parent #116): `give`, `get`, `take`, `pay`, `claim`,
`discard` and `drop` fail and are rejected, and `reclaim` and `accept` are
rejected.

## Scenario

Two factions start in Greyfell (57081): **300** "Fumblers", with Fumbler One
[4126], and **301** "Strangers", with Stranger One [8651]. The stranger has no
orders and has accepted nothing.

The fumbler's orders all fail:

| Order | Outcome |
|---|---|
| `give 8651 10 1` | fail: the stranger refuses peasants it hasn't accepted |
| `get 8651 10 1`, `take 8651 10 1` | fail: may only take from units in your faction |
| `pay 8651 10 9999` | fail: keeping 9999 gold back, but it has only 200 |
| `claim 87 1` | fail: the faction has no fish to claim |
| `discard 87 1`, `drop 87 1` | fail: the fumbler has no fish |

The player entity issues the same seven orders and `reclaim`, and each one is
refused (rejected): `claim`, `discard` and `reclaim` are noble-only (`c`), and
the rest are `cr`, which a player entity may not issue either.

The garrison [1009] of Catchclaw (58706) orders `accept 0 0 0`.
`accept` is `cpr`, so the player entity may issue it, but a garrison (`g`) may
not, and it is rejected. `oly.load` seeds the city garrisons, and the script
finds this one with `oly.garrison`. The rejection goes to the garrison
player's report, so only the coverage dump pins it.

`accept` and `reclaim` always return TRUE, so their `fail` cells are `n/a`.

## What `check.sh` asserts

1. Every cell above reaches its outcome in the turn's `--coverage` dump.
2. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match
   `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`inventory-refused.lua` builds the scenario with `olyscript-g3`.
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
