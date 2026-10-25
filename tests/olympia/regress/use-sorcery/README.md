# use-sorcery — use of the advanced sorcery skills

Pins the `ok` cells of the Advanced sorcery school, use group 8 (issue
#216, use backlog parent #180): `trance` (921) and `teleport_item` (922).
There is no refused fixture, because neither `fail` cell is reachable:

- `v_teleport_item` always returns TRUE. Its checks are all in
  `d_teleport_item`, and the use dump counts outcomes at start time.
- `v_trance` refuses a noble that doesn't know Trance. `v_use` lets a noble
  use a skill it doesn't know only when it holds an item whose `may_use`
  lists the skill (`may_use_skill`), and no engine code makes one:
  `d_write_spell` and the quest scrolls set `may_study`.

## Scenario

Two factions, 300 Trancers and 301 Teleporters, start in Greyfell (57081).
Magic may not be used in a safe haven, so the trancer is poofed to Forest
[13449] and the teleporter to Plain [13450], two provinces of the same
region. Each knows the Advanced sorcery school and starts with 200 gold.
Each skill known adds one aura.

| Faction | Noble | Setup | Orders |
|---|---|---|---|
| 300 Trancers | Trancer One [4126] | in Forest [13449], knows Trance, sick (`oly.sick`) | `use 921` |
| 301 Teleporters | Teleporter One [8651] | in Plain [13450], knows Trance and Teleport items, 3 aura | `use 922 4126 1 50` |

Both starts return TRUE:

- The teleporter spends 3 aura (gold weighs nothing) and teleports 50 gold
  to the trancer on day 4. A character always accepts gold.
- The trancer's trance finishes on day 28. Its aura is already above two
  thirds of its maximum, so it stays at 2, and the trance heals its
  sickness ("is fully healed").

## What `check.sh` asserts

1. `use:ok` in the turn's `--coverage` dump, and both skills' `ok` cells in
   its `--use-coverage` dump.
2. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`use-sorcery.lua` builds the scenario with `olyscript-g3`;
`build-scenario.sh` freezes it as `scenario.patch` over the shared base world.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
