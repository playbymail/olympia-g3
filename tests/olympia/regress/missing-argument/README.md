# missing-argument — orders with a missing argument

Pins the fix for the turn-order half of issue #366: orders that read an
argument slot the order didn't fill. The GM console half is in
[gm-immediate-missing](../gm-immediate-missing/README.md).

Each unit's `struct command` keeps one parse vector for all its orders.
`parse_line()` resets the vector's length but not its slots, and
`oly_parse_cmd()` frees the previous order's line first. So a slot past the
order's last word is NULL, if no order filled it, or points into an
earlier order's freed line. `attack`, `use` and Summon fog read such a slot:

- `attack` with no target went to `parse_exit_dir()`, which matched slot 1
  as a direction. When slot 1 was NULL, `i_strcmp()` dereferenced it and the
  **turn crashed** (SIGSEGV, on debug and release). Now `v_attack` refuses
  first: "Must specify what to attack."
- `use` with nothing to use printed slot 1 ("... is not a valid skill to
  use."): freed text, or `(null)` from `printf("%s", NULL)`. Now `v_use`
  refuses first, "Must specify what to use.", and the use dump still counts
  it under `invalid` / `checks`.
- `use 826` (Summon fog) with no name took the storm's name from slot 2,
  which `v_use`'s `cmd_shift` leaves alone, so after a longer order the new
  storm was named with freed bytes, which were saved to the DB. Now
  `d_summon_fog` names the storm only when `numargs(c) >= 2`, as
  `d_summon_rain` and `d_summon_wind` do.

## Scenario

Five factions, 300–304, start in Greyfell (57081). The longer order,
`promote 9999 aaaa bbbb cccc`, fails at once and fills slots 1–4.

A unit's command line is also saved with the DB (the `li` line of its `CO`
section) and parsed again at load, which fills the slots too. The build
script's commands leave each noble with the last command it ran as that
noble: `be <next noble>` for all but the last, which keeps `save`, a
single word. So the striker is made last; it is the unit whose slot 1 is
NULL.

| Faction | Noble | Where | Orders | Before the fix | Now |
|---|---|---|---|---|---|
| 300 Raiders | Raider One [4126] | Plain [13450] | the longer order, `attack` | slot 1 freed: matched as a direction | fail: must specify what to attack |
| 301 Fumblers | Fumbler One [8651] | Plain [13450] | `use` | slot 1 freed (from its saved `be`): printed | fail: must specify what to use |
| 302 Dabblers | Dabbler One [8159] | Plain [13450] | the longer order, `use` | slot 1 freed: printed | fail: must specify what to use |
| 303 Foggers | Fogger One [7012] | Forest [13550], knows the Weather school (6 aura) | the longer order, `use 826` | slot 2 freed: copied into the storm's name | ok: summons Fog [122602], with its default name |
| 304 Strikers | Striker One [6947] | Plain [13450] | `attack` | slot 1 NULL: **the turn crashed** (SIGSEGV) | fail: must specify what to attack |

Run against the engine before the fix, `check.sh` stops at the crash
(`NO (olympia-g3 turn failed: exit 139)`).

## What `check.sh` asserts

1. `attack:fail`, `use:fail` and `use:ok` in the turn's `--coverage` dump,
   and `invalid:0:checks` and `skill:826:ok` in its `--use-coverage` dump.
2. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match
   `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`missing-argument.lua` builds the scenario with `olyscript-g3`.
`build-scenario.sh` runs it on the bare map and freezes the result as
`scenario.patch` over the shared base world.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
