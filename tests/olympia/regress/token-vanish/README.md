# token-vanish — a regular player is told when its NPC token vanishes

Pins the fix for #355. When an NPC token's last unit dies, `kill_char`
(`olympia/u.c`) destroys the token and tells the character holding it,
`<token> vanishes.`, if that character belongs to a regular player. The test
was `player(who_has) == sub_pl_regular`: a faction id against a subkind
(49), which only a faction numbered 49 could pass, so the holder was never
told. The test is now `subkind(player(who_has)) == sub_pl_regular`.

## Scenario

One faction starts in Greyfell (57081):

| Faction | Noble | Before the turn | Turn |
|---|---|---|---|
| 300 Holders | Holder One [4126] | holds the Horn of the Savages [61319] (`oly.token`) | — |

`oly.token_units` adds the token's unit, a band of savages [99374], before
the turn, and the band is put on deep ocean [10100] with no ship, so it is
flying. On day 15 its flight can no longer be maintained, and it plunges
into the sea and dies. It was the token's last unit, so the token is
destroyed, and the Holders' report has `Horn of the Savages~[c319]
vanishes.` on day 15. Before the fix it did not.

## What `check.sh` asserts

1. The Holders' report (`save/1/300`) has the band plunging on day 15.
2. It has the token vanishing on day 15.
3. The Holders' report and unit state (`save/1/300`, `fact/300`) match
   `EXPECT.sha256`.

## Authored in Lua

`token-vanish.lua` builds the scenario with `olyscript-g3`, using
`oly.token` and the `oly.token_units` binding (#355), which runs
`check_token_units` before the turn so the band's id can be named.
`build-scenario.sh` freezes it as `scenario.patch` over the shared base
world.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
