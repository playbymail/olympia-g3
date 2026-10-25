# use-checks — the shared use checks and the v_implicit skills

Pins use group 10 (issue #224, use backlog parent #180): the `fail` cells of
the 10 `v_implicit` skills, and every shared check in `v_use` and
`v_use_item` that fails before a start runs. The dump counts those under
`checks`, which has no backlog column; this fixture asserts a `checks` cell
for each.

## Scenario

Three factions, 300 to 302, start in Greyfell (57081). The implicit and
checker nobles are poofed to Plain [13450], which is not a safe haven; the
havener stays in Greyfell, which is.

| Faction | Noble | Setup | Orders |
|---|---|---|---|
| 300 Implicits | Implicit One [4126] | the 10 `v_implicit` skills and their 7 schools | `use` 617, 635, 652, 653, 676, 695, 704, 706, 902, 911 |
| 301 Checkers | Checker One [8651] | Combat (610), Survive fatal wound (611), Construct catapult (613), Petty thievery (631) without Stealth | `use` 99999, 13450, 610, 611, 603, 631, 613, 69, 1 |
| 302 Haveners | Havener One [8159] | Basic magic (800), Meditate (801), an orb (`oly.orb`) | `use` 801, `use` orb 13449 |

Each of the implicit noble's uses reaches `v_implicit`, which always fails
("No direct USE function exists"). Every other use fails a shared check:

| Use | Check | Dump row |
|---|---|---|
| 99999 | not a box | `invalid` |
| 13450 | a location: neither skill nor item | `invalid` |
| 610 | a skill school | `invalid` |
| 611 | known, but no `use_tbl` entry ("Internal error.") | `invalid` |
| 603 | the skill not known | skill 603 |
| 631 | the school (Stealth) not known | skill 631 |
| 613 | no three wood (`meets_requirements`) | skill 613 |
| 69 | the elfstone not held | item 8 |
| 1 | gold has no use key ("Nothing special happens.") | `invalid` |
| 801 | magic in a safe haven | skill 801 |
| orb | a magic item in a safe haven | item 9 |

Survive fatal wound (611) is a passive skill in the world's `lib/skill` with
no `use_tbl` row, as are 705 and 731. Using one prints "Internal error." to
the player and "v_use: no use table entry" to stderr. The fixture pins that
as it is.

## What `check.sh` asserts

1. `use:fail` in the turn's `--coverage` dump; in its `--use-coverage` dump,
   the `fail` cells of the 10 `v_implicit` skills and the `checks` cells
   `invalid:0`, `skill:603`, `skill:631`, `skill:613`, `skill:801`, `item:8`
   and `item:9`.
2. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`use-checks.lua` builds the scenario with `olyscript-g3`;
`build-scenario.sh` freezes it as `scenario.patch` over the shared base world.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
