# recruitment-raise — recruitment orders that start

Pins the `ok` outcome of the recruitment-family verbs `recruit`, `raise` and
`rally` (issue #130, backlog parent #116). `form` ok is already pinned by
`inventory-give`, and `train` is an alias of `make` (`production-harvest`).

## Scenario

Two factions start in Greyfell (57081) and are poofed to Plain [13450], a
province with peasants and a mob cookie.

| Unit | Orders |
|---|---|
| Recruiter One [4126] (300 "Recruiters") | `recruit 2` |
| Agitator One [8651] (301 "Agitators"), knows Raise and Rally peasant mob | `raise`, `rally 122602` |

`recruit` re-parses as `collect 10 2` and takes two of the plain's peasants.
`raise` takes seven days and creates Angry peasant [122602], a mob of 18.
`rally` then starts against it, and when it finishes the mob stacks beneath
the agitator.

The mob's id is minted during the turn (`new_ent` draws from the per-turn
`mint` stream), so `rally` names the id this frozen scenario gives it. If
an engine change moves the id, `check.sh` reports `rally` missing its `ok`
cell; read the new id from the agitator's report and update `MOB` in
`recruitment-raise.lua`.

## What `check.sh` asserts

1. `recruit`, `raise` and `rally` reach `ok` in the turn's `--coverage` dump.
2. Both factions' reports and unit state (`save/1/30{0,1}`, `fact/30{0,1}`)
   match `EXPECT.sha256`. The mob stacking beneath the agitator is in
   `save/1/301`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`. It lists
   the mob in Plain's `here`, but the mob belongs to the independent player,
   so its stack and loyalty are not exported (#114).

## Authored in Lua

`recruitment-raise.lua` builds the scenario with `olyscript-g3`.
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
