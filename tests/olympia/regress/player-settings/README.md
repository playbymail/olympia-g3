# player-settings — faction and report settings

Pins the faction and report settings verbs of the player family (issue #118,
backlog parent #116): the `ok` outcome of `banner`, `flag`, `name`,
`realname`, `stop`, `format`, `notab` and `public`, the `fail` outcome of
`banner`, `flag`, `name`, `realname`, `public` and `split`, and the
`rejected` outcome of `banner` and `flag`.

## Scenario

One faction, **300** "Settings Guild", whose noble Herald One [4126] starts
in Greyfell (57081). The noble's orders:

| Order | Outcome |
|---|---|
| `banner Argent a chevron sable` | ok: banner set |
| `banner xxx…` (51 characters) | fail: longer than 50 |
| `flag ready` | ok |
| `flag ready` | fail: already signalled this month |
| `name Herald Prime` | ok: renamed |
| `name` | fail: no new name |
| `realname Pat Q Player` | ok: the player's full name |
| `realname` | fail: no new name |
| `stop` | ok |
| `split 2000 20000` | fail: no longer supported |

The player entity's orders:

| Order | Outcome |
|---|---|
| `format 1` | ok |
| `notab 1` | ok |
| `public` | ok: 100 CLAIM gold |
| `public` | fail: already a public turn |
| `banner Or plain` | rejected: a noble-only order |
| `flag ready` | rejected: a noble-only order |

`split`'s start always returns 0, so its `ok` cell is `n/a`. The starts of
`format`, `notab` and `stop` always return TRUE, so their `fail` cells are
`n/a` too. Their `rejected` cells stay `todo`: every faction noble and player
may issue them, and only a character under restricted control can be refused.

## What `check.sh` asserts

1. Every cell above reaches its outcome in the turn's `--coverage` dump.
2. The faction's report and unit state (`save/1/300`, `fact/300`) match
   `EXPECT.sha256`. Most of these verbs change only the report and the
   faction's settings, which the state export does not show.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`player-settings.lua` builds the scenario with `olyscript-g3`.
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
