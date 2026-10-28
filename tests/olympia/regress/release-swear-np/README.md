# release-swear-np — a new owner who can't pay a unit's NPs is an engine bug

Pins the fix for #352. `set_lord` (`olympia/swear.c`) moves a unit to a new
faction and charges that faction the unit's NPs (`char_np_total`). Every
caller that can move a unit for a charge checks the NPs first
(`enough_np_to_acquire`, or `player_np` in the potion and the token code), so
a failed `deduct_np` is an engine bug. It was only logged (`assert fail:
...` in the code log): the unit moved anyway, its old faction got its NPs
back, and the new one was told `Paid 2 NPs` without paying. The disabled
`assert(FALSE)` is now live.

`swear_token_units` doesn't check, but an NPC token's units cost no NPs. The
one unchecked caller that can fail is `drop_stack` (`olympia/stack.c`) freeing a
prisoner marked `swear_on_release`, who swears to whoever freed it. No
engine code sets that flag; only a loaded DB does. This fixture sets it with
the `oly.prisoner` binding.

## Scenario

Two factions start in Greyfell (57081):

| Faction | Noble | Before the turn | Turn |
|---|---|---|---|
| 300 Captives | Captive One [4126] | prisoner of Captor One, `swear_on_release` (`oly.prisoner`) | — |
| 301 Captors | Captor One [8651] | 0 NPs (`oly.noble_points`) | `wait time 1`, `unstack 4126` |

On day 2 the captor frees the captive. The keyed release draw swears it to
the Captors (on day 1 it would have spat and vanished), oath 1, for 2 NPs
they don't have. The turn fails the assertion and exits 134. Before the
fix it exited 0, with `Paid 2 NPs for Captive One [4126].` in the
Captors' report.

## What `check.sh` asserts

1. The turn exits 134.
2. stderr reports the assertion failure in `swear.c`.
3. No AddressSanitizer or UBSan report on stderr.

No EXPECT files: the checks are inline.

## Authored in Lua

`release-swear-np.lua` builds the scenario with `olyscript-g3`, using the
`oly.prisoner` and `oly.noble_points` bindings (#352). `build-scenario.sh`
freezes it as `scenario.patch` over the shared base world.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
```
