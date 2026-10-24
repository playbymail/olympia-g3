# construction-build — building, improving and repairing

Pins the `ok` outcome of `build`, `improve` and `repair` (issue #147,
backlog parent #116).

## Scenario

Three factions start in Greyfell (57081). `oly.makeloc` makes a castle,
Castle [74170], and a tower, Tower [71524], in the city:

| Faction | Noble | Set up | Orders |
|---|---|---|---|
| 300 Builders | Builder One [4126] | Greyfell; knows Construction [680]; 100 workers, 100 stone | `build tower` |
| 301 Improvers | Improver One [8651] | in the castle; 100 workers, 50 stone | `improve` |
| 302 Repairers | Repairer One [8159] | in the tower; 10 workers | `repair` |

- **build.** A tower is the cheapest Construction structure: 3 workers and
  20 stone to start, 2000 worker-days, and 20 stone for each fifth of the
  work. The new tower's id is minted (`new_ent(T_unform)`, the `mint`
  stream), New tower [7036]. With 100 workers (100 worker-days a day) the
  builder uses its 100 stone over days 1–16 and finishes the tower on
  day 20.
- **improve.** Level one costs 50 stone, applied at the start, and 1000
  worker-days. The improver's 100 workers take ten days: the castle is at
  level one, defense 5, on day 10.
- **repair.** `v_makeloc` does not set a building's defense, so a tower it
  makes has defense 0, under the tower default of 40 (`fort_default_defense`)
  and repairable without any damage. Nothing in `oly` damages a building,
  and this is the reason no binding was needed. A tower point costs 2
  worker-days, so 10 workers restore 5 a day. The repairer starts on day 2
  and the tower is fully repaired (40 defense) on day 9.

## What `check.sh` asserts

1. `build`, `improve` and `repair` reach `ok` in the turn's `--coverage`
   dump.
2. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match
   `EXPECT.sha256`. Building progress, castle level and defense are not in
   the state export (#114); the reports pin them.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`construction-build.lua` builds the scenario with `olyscript-g3`.
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
