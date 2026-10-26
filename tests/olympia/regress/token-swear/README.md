# token-swear — an NPC token's units swear to its new holder

Pins the fix for issue #251. An NPC token (`sub_npc_token`) controls a few
NPC units, sworn to the faction of the character who holds it. When the
token changes hands, `move_item` calls `move_token` (`olympia/art.c`), and
if the faction changes, `swear_token_units` swears each of the token's
units to the new holder's faction with `set_lord`.

`swear_token_units` tested `subkind(i) == T_char`. `T_char` is a kind (2);
as a subkind it is `sub_forest`, which no character has, so the test never
passed and nobody was sworn. The units stayed with the old faction until
the month-end `check_token_units` noticed the mismatch, printed
`fixing token owner` on stderr and swore them over. The test is now
`kind(i) == T_char`.

## Scenario

Two factions start in Greyfell (57081):

| Faction | Noble | Before the turn | Turn |
|---|---|---|---|
| 300 Holders | Holder One [4126] | holds the Horn of the Savages [66159] (`oly.token`) | `wait time 7`, then `give 8651 66159 1` |
| 301 Takers | Taker One [8651] | — | `accept 4126 66159 1` |

Day 0's `check_token_units` adds the token's unit, a band of savages
[91968] sworn to the Holders, in the forest (13451). The accept runs on
day 1, so the give on day 8 is not refused. With the fix, the give swears
the band to the Takers on day 8: the Holders' report has `Received 0 NPs
for Savage [91968]` and the Takers' `Paid 0 NPs for Savage [91968]`, both
on day 8, and the misc log (`save/1/200`) has `swearing Savage [91968]`.
Month end finds nothing to fix.

Without the fix, the band is still the Holders' after the give. At month
end `check_token_units` prints `fixing token owner for Savage~[91968], ni
(300 to 301)`, and the reports have `Savage [91968] renounces loyalty.` /
`swears loyalty.` and the NP lines on day 30. `check.sh` prints four `NO`
lines.

## What `check.sh` asserts

1. The turn's stderr has no `fixing token owner`.
2. The Takers' report (`save/1/301`) pays for the band on day 8.
3. The Holders' report (`save/1/300`) has no `renounces loyalty`.
4. Both factions' reports and unit state (`save/1/300`, `save/1/301`,
   `fact/300`, `fact/301`) and the misc log (`save/1/200`) match
   `EXPECT.sha256`.

## Authored in Lua

`token-swear.lua` builds the scenario with `olyscript-g3`, using the
existing `oly.token` binding. `build-scenario.sh` runs it on the bare map
and freezes the result as `scenario.patch` over the shared base world,
taking `world.tgz`'s `lib/log` as `trade-opium` does.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
