# gm-credit — the GM player's turn orders

Pins the `ok` outcome of the gm family (issue #151, backlog parent #116):
`credit`, `emote` and `relore`.

These are `m` verbs: `check_allow` passes them only when
`player(c->who) == gm_player`. Unlike the `gm-immediate` verbs, which run only
under `-i`, they are turn orders read from the GM player's order file, so a
port that runs a turn must run them too.

## Scenario

One faction, **300** "Guild", whose noble Herald One [4126] starts in
Greyfell (57081). Before the turn, `oly.know` teaches the herald Shipcraft
[600] and `oly.seen` marks its lore sheet as already delivered to the
faction.

The GM player, The Fates [200], has no units. Its own orders:

| Order | Outcome |
|---|---|
| `credit 4126 5` | ok: five gold (no item given means gold) |
| `credit 4126 7 12` | ok: seven soldiers |
| `credit 300 3 np` | ok: three Noble Points to the faction |
| `credit 4126` | ok: no amount, so the Times pays the herald 25 gold, once per faction |
| `emote 4126 "The Fates smile on %s."` | ok: the message goes to the herald, with `%s` replaced by its name |
| `relore 600` | ok: Shipcraft's lore sheet goes again to every faction with a unit that knows it |

Each `credit` and the `emote` reports to the herald or the faction. The
Times' pay reports only to the herald, and `emote` and `relore` report
nothing to the GM.

`relore` calls `queue_lore` with `anyway` set. Without the `oly.seen`, the
herald's faction would not know Shipcraft yet. The turn's
`scan_char_skill_lore` would then deliver the sheet whether or not `relore`
ran, and the order would have no visible effect. With it, the sheet (16 report
lines) is in `save/1/300` only because of the `relore`.

The message `emote` sends is the format string for a `wout` whose one argument
is the target's name. A message that has no `%s` prints as written. Any other
conversion is undefined behavior, so the fixture uses exactly one `%s`.

## What `check.sh` asserts

1. `credit`, `emote` and `relore` reach `ok` in the turn's `--coverage` dump.
2. The GM's report, the faction's report and the faction's unit state
   (`save/1/200`, `save/1/300`, `fact/300`) match `EXPECT.sha256`. NP, the
   Times' pay and lore are not in the state export.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`gm-credit.lua` builds the scenario with `olyscript-g3`. `build-scenario.sh`
runs it on the bare map and freezes the result as `scenario.patch` over the
shared base world. The script never runs the `-a` pass, so `build-scenario.sh`
also swaps in `world.tgz`'s `lib/log`. A turn deletes `lib/log` before it
writes anything, so it is not turn input.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
