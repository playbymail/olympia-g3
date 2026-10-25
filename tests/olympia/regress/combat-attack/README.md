# combat-attack — battle, prisoners and razing

Pins the `ok` outcome of the combat-family verbs (issue #128, backlog parent
#116): `attack`, `behind`, `guard`, `surrender`, `execute` and `raze`.
(`pillage` is pinned by `guard-pillage`.)

## Scenario

Five factions are poofed into plain province 10113, which is not a safe
haven, so combat is allowed:

| Faction | Noble | Orders |
|---|---|---|
| 300 Raiders | Raider One [4126], 50 soldiers | `behind 1`, `attack 8651` |
| 301 Victims | Victim One [8651] | `guard 1` |
| 302 Yielders | Yielder One [8159] | `surrender 7012` |
| 303 Captors | Captor One [7012] | `wait time 2`, `execute 8159` |
| 304 Razers | Razer One [6947], in Tower [67765] | `raze` |

On day 1 the raider wins the battle. The victim loses its 25 peasants, is
wounded to health 78 and falls ill, but is not taken prisoner; it loses ten
health a week for the rest of the turn. The battle draws from the per-battle
`begin_battle()` stream, keyed on the place, both leaders and the day (see
`doc/claude/rng-streams.md`), so the result is pinned by the hashes.

The yielder surrenders to the captor on day 1. The captor waits two days so
the prisoner is already held, then executes it on day 3. Yielder One dies,
and faction 302 ends the turn with no units.

The tower is made with `oly.makeloc` and the razer is poofed into it; the
first character inside a building is its owner, which `raze` requires. With
26 men and 2 men per point, the tower collapses on day 9.

## What `check.sh` asserts

1. Every cell above reaches `ok` in the turn's `--coverage` dump.
2. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match
   `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

The state export has no prisoner, `behind` or `guard` fields; only the
hashes pin those.

## Authored in Lua

`combat-attack.lua` builds the scenario with `olyscript-g3`.
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
