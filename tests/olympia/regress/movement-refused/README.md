# movement-refused — movement orders that fail or are refused

Pins the `fail` and `rejected` outcomes of the movement-family verbs (issue
#152, backlog parent #116): `go`, `move`, `north`, `n`, `east`, `e`, `s`,
`south`, `west`, `w`, `enter`, `in`, `exit`, `out`, `fly`, `board`, `ferry`,
`sail` and `unload`.

## Scenario

Two factions, one noble each, moved out of Greyfell (57081) by `poof`. Every
order fails at once, so no order takes a day.

**300** "Walkers": Walker One [4126] stands in the Forest **13451** [bs51],
Greyfell's province, with ocean to the north and east.

| Order | Fails with |
|---|---|
| `go` | Specify direction or destination to MOVE. |
| `move nowhere`, `enter nowhere`, `in nowhere` | Unknown direction or destination 'nowhere'. |
| `north`, `n`, `east`, `e` | A sea-worthy ship is required for travel across water. |
| `exit`, `out` | No visible out route from Forest [bs51]. |
| `fly` | Specify direction or destination to FLY. |
| `fly south` | Walker One is too overloaded to fly. (no flying capacity) |
| `board 57081` | [d21] is not a ship. |
| `sail` | Must be on a sea-worthy ship to sail. |
| `ferry`, `unload` | Walker One is not the captain of a ship. |

**301** "Rovers": Rover One [8651] stands in the Plain **13482**, with ocean
to the south and west. `s`, `south`, `west` and `w` each fail: "A sea-worthy
ship is required for travel across water."

`enter`, `exit` and the compass verbs re-parse as `move` and run `v_move`,
but the coverage hook counts the verb as typed, so each spelling (and each
alias) is ordered separately.

**Rejected:** every movement verb is `c` or `cr`, so the Walkers' player
entity [300] orders all nineteen and `check_allow()` refuses each: "Walkers
[300] may not issue that order."

## What `check.sh` asserts

1. Every verb above reaches both `rejected` and `fail` in the turn's
   `--coverage` dump.
2. The factions' reports and unit state (`save/1/30{0,1}`, `fact/30{0,1}`)
   match `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`movement-refused.lua` builds the scenario with `olyscript-g3`.
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
