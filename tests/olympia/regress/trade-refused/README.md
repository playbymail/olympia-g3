# trade-refused — trade orders that fail or are refused

Pins the `fail` and `rejected` outcomes of `buy` and `sell`, and the
`rejected` outcome of `fee` (issue #142, backlog parent #116).

## Scenario

One faction starts in Greyfell (57081): Trader One [4126] (300 "Traders").
The trader orders each of `buy` and `sell` four times:

| Arguments | Fails with |
|---|---|
| `4126 1 1` | [4126] is not an item. |
| `1 1 1` | Can't buy or sell gold. |
| `77 5 14 0 1` | Must have 731 to conceal trades. |
| `77 5` | No price given. |

The player entity orders `buy 77 1 14`, `sell 77 1 7` and `fee 1`: each is
rejected, since all three verbs are for nobles (`c`).

`fee` has no `fail` outcome: `v_fee` sets the boarding fee and always
returns TRUE, so its backlog cell is `n/a`.

## What `check.sh` asserts

1. `buy` and `sell` reach both `fail` and `rejected`, and `fee` reaches
   `rejected`, in the turn's `--coverage` dump.
2. The faction's report and unit state (`save/1/300`, `fact/300`) match
   `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`trade-refused.lua` builds the scenario with `olyscript-g3`.
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
