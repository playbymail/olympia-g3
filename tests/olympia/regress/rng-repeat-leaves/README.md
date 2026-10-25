# rng-repeat-leaves — repeated skill commands draw independently

Pins the fix for #186, the follow-up to [`rng-repeat`](../rng-repeat/)
(#167). A keyed leaf returns the same roll for the same key. The command
leaves were keyed on the actor and a target or skill, with no day, so a
7-day command repeated in one turn replayed its first roll every time. They
now draw from a per-day child of their turn stream (see
[doc/claude/rng-streams.md](../../../../doc/claude/rng-streams.md)).

This fixture repeats two skill-stream (`skil`) commands. Other fixtures pin
more of the #186 fixes: [`magic-cast`](../magic-cast/) breeds twice,
[`combat-attack`](../combat-attack/)'s sick victim heals weekly, and
[`social-bribe`](../social-bribe/)'s prisoner checks for escape weekly.

## Scenario

Two factions start in Greyfell (57081):

| Faction | Noble | Set up | Orders |
|---|---|---|---|
| 300 Archers | Archer One [4126] | knows Combat [610] and Archery [615] | `use 615` ×4 |
| 301 Researchers | Researcher One [8651] | knows Stealth [630]; owns a tower [66159] (`oly.makeloc` + `oly.poof`) | `research 630` ×4 |

Each order takes 7 days, so the four finishes fall a week apart.

## What the fix changes

Run on the engine from before #186, and on this one:

| Action | Before #186 | Now |
|---|---|---|
| `use 615` ×4 (archery) | missile rating +3 every week: 53, 56, 59, 62 | +3, +10 (the 5% critical), +4, +5: 53, 63, 67, 72 |
| `research 630` ×4 | "Research uncovers no new skills." all four times | uncovers Learn of richest nearby noble [636] on day 8, then nothing on days 15, 22 and 29 |

The hashes pin the "now" column. Missile ratings and partly known skills
are not in the state export, so the hashes carry them.

## What `check.sh` asserts

1. `use` and `research` reach `ok` in the turn's `--coverage` dump.
2. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match
   `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`rng-repeat-leaves.lua` builds the scenario with `olyscript-g3`.
`build-scenario.sh` runs it on the bare map and freezes the result as
`scenario.patch` over the shared base world.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
