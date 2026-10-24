# recruitment-raise — recruitment orders that start

Pins the `ok` outcome of the recruitment-family verbs `recruit`, `raise` and
`rally` (issue #130, backlog parent #116). `form` ok is already pinned by
`inventory-give`, and `train` is an alias of `make` (`production-harvest`).

## Scenario

Three factions start in Greyfell (57081) and are poofed to provinces with
peasants and a mob cookie.

| Unit | Where | Orders |
|---|---|---|
| Recruiter One [4126] (300 "Recruiters") | Plain [13450] | `recruit 2` |
| Agitator One [8651] (301 "Agitators"), knows Raise peasant mob | Plain [13450] | `raise` |
| Rallier One [8159] (302 "Ralliers"), knows Rally peasant mob | Forest [13449] | `rally 101396` |

`recruit` re-parses as `collect 10 2` and takes two of the plain's peasants.
`raise` takes seven days and creates Angry peasant [122602], a mob of 18.
Mob [101396] is seeded in the forest before the turn by `oly.mob` (#139),
so `rally` starts against it and, when it finishes, the mob stacks beneath
the rallier. Seeding the mob spends the forest's mob cookie, which is why the
agitator raises on the plain instead.

## What `check.sh` asserts

1. `recruit`, `raise` and `rally` reach `ok` in the turn's `--coverage` dump.
2. The three factions' reports and unit state (`save/1/30{0,1,2}`,
   `fact/30{0,1,2}`) match `EXPECT.sha256`. The mob stacking beneath the
   rallier is in `save/1/302`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`. It lists
   both mobs in their province's `here`, but they belong to the independent
   player, so their stacks and loyalty are not exported (#114).

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
