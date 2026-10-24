# loyalty-refused — loyalty orders that fail or are refused

Pins the `fail` and `rejected` outcomes of `honor` (and its alias
`honour`), `oath`, `pledge` and `swear` (issue #143, backlog parent #116).

## Scenario

Two factions start in Greyfell (57081): Sworn One [4126] (300 "Oathbound")
and Liege One [8651] (301 "Lieges"). A starting noble is at oath-2.

| Unit | Order | Fails with |
|---|---|---|
| Sworn One | `honor` | Must specify an amount of gold to use as a gift. |
| Sworn One | `honor 10` | Sworn One~[4126] graciously declines the offer. (oath-bound) |
| Sworn One | `honour 10` | the same |
| Sworn One | `oath 1` | Sworn One~[4126] already is at oath-2, the maximum loyalty. |
| Sworn One | `pledge 4126` | Can't pledge to yourself. |
| Sworn One | `pledge 57081` | 57081 is not a character. |
| Sworn One | `pledge 1009` | May not pledge land to 1009. (Catchclaw's garrison, an NPC) |
| Sworn One | `swear 8651` | The SWEAR order has been removed from the game. |
| Sworn One | `wait day 2`, `pledge 8651` | Cannot pledge to Liege One~[8651] since Liege One is pledged to you. |
| Hireling [1375] | `honor 50` | Do not have 50~gold. |

Liege One orders `pledge 4126` on day 1 (ok), so Sworn One's pledge back on
day 3 would be circular. Sworn One then forms the Hireling, a contract-500
noble that has no gold, so its `honor` gets past the oath check and fails
the charge. Its order is queued before it exists, as in `loyalty-bind`.

The player entity orders `honor 10`, `honour 10`, `oath 1`, `pledge 4126`
and `swear 4126`: each is rejected, since every loyalty verb is for nobles
(`c`).

`swear` has no `ok` outcome: `v_swear` prints the removal message and
returns FALSE before any check, so its backlog cell is `n/a`. `oath`'s
"has no Noble Points" failure is not reached: a new faction has 18 NP, the
maximum-loyalty check runs first, and no binding sets a faction's NP.

## What `check.sh` asserts

1. All five verbs reach both `fail` and `rejected` in the turn's
   `--coverage` dump.
2. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match
   `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`loyalty-refused.lua` builds the scenario with `olyscript-g3`.
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
