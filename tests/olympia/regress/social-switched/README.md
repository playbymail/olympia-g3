# social-switched — bribing a noble that just switched lords

Pins `bribe`'s "just switched employers" refusal, at the finish (`d_bribe`)
and at the start (`v_bribe`) (issue #160, a follow-up to #146; backlog
parent #116).

## Scenario

Four factions start in Greyfell (57081):

| Faction | Noble | Set up | Orders |
|---|---|---|---|
| 300 Formers | Former One [4126] | | `form 1375 Hireling` |
| 301 Rivals | Rival One [8651] | knows Bribe noble [671]; 500 more gold | `wait day 9`, `bribe 1375 500` |
| 302 Winners | Winner One [8159] | knows Bribe noble [671]; 500 more gold | `wait day 9`, `bribe 1375 500` |
| 303 Latecomers | Latecomer One [7012] | knows Bribe noble [671] | `wait day 17`, `bribe 1375 100` |

`p_char(who)->new_lord` is set only by `unit_deserts()`, when a unit
deserts within the turn: a bribe that comes out SWITCH or HEAD_FOR_HILLS,
`persuade`, or a prisoner who gives in to `terrorize`. This fixture uses a
won bribe.

| Day | Unit | What happens |
|---|---|---|
| 7 | Hireling [1375] | formed, contract-500, stacked beneath Former One |
| 10 | Winner One, Rival One | both bribes start (`ok`) |
| 16 | Winner One | finishes first: 500 reaches the contract-500 threshold and the draw comes out SWITCH. The hireling renounces the Formers and pledges fealty to the Winners (1 NP each way); `new_lord` is set |
| 16 | Rival One | finishes second: refused, "Hireling [1375] just switched employers this month, and is not looking for a new one so soon." No gold is charged |
| 18 | Latecomer One | the same refusal at the start (`fail`) |

- **Finish order.** The evening phase runs finishes in order of the units'
  position in their location (`exec_precedence`). Each new noble goes to
  the head of Greyfell's list, so Winner One, added after Rival One, stands
  ahead of it and finishes first.
- **The draw.** A bribe that reaches the threshold rolls 1–100 on the
  social stream (`socl`, see
  [doc/claude/rng-streams.md](../../../../doc/claude/rng-streams.md)): ≤ 35
  SWITCH, ≤ 65 pocket, ≤ 90 report, else HEAD_FOR_HILLS. It is keyed on
  (briber, target) under a per-day child of the stream (#186). The ids and
  the day 16 finish make it land SWITCH. Waiting for day 8 instead, both
  bribes pocket and nothing switches.

## What `check.sh` asserts

1. `bribe` reaches `ok` and `fail` in the turn's `--coverage` dump.
2. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match
   `EXPECT.sha256`. The Rivals' and Latecomers' reports hold the two
   refusals, so the hashes pin the message.
3. The post-turn `--state-export` snapshot matches `EXPECT.json` (the
   hireling is now a Winners unit).

## Authored in Lua

`social-switched.lua` builds the scenario with `olyscript-g3`.
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
