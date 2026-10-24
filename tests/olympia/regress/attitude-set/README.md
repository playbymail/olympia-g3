# attitude-set — attitude orders that start

Pins the `ok` outcome of the attitude-family verbs (issue #129, backlog
parent #116): `admit`, `contact`, `default`, `defend`, `hostile` and
`neutral`.

## Scenario

Two factions start in Greyfell (57081), a safe haven, so no hostile stance
can start a fight.

| Unit | Orders |
|---|---|
| Diplomat One [4126] (300 "Diplomats") | `admit 4126 8651`, `hostile 8651`, `defend 301`, `default 8651`, `neutral 8651`, `contact 8651` |
| Visitor One [8651] (301 "Visitors") | `wait time 1`, `stack 4126` |

Every start returns TRUE. `default 8651` clears the hostile stance before
`neutral 8651` sets a new one, so the diplomats' report ends with
`neutral 8651` and `defend 301` under "Declared attitudes", and
`admit 4126 8651` under "Admit permissions". The visitor's report gets
"Diplomat One contacted us", and its `stack` succeeds because of the admit.
The visitor waits a day so the admit is in place first.

The fixture reaches `stack` ok too, but does not claim that backlog cell; it
belongs to the stacking family.

## What `check.sh` asserts

1. Every attitude verb reaches `ok` in the turn's `--coverage` dump.
2. Both factions' reports and unit state (`save/1/30{0,1}`, `fact/30{0,1}`)
   match `EXPECT.sha256`. The attitude and admit lists are in `fact/300`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`. It shows
   the stack, but it does not export attitudes or admit lists yet (#114).

## Authored in Lua

`attitude-set.lua` builds the scenario with `olyscript-g3`.
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
