# stop-running — STOP on a running collect, make, repair and sail

Pins what a STOP does to an order an earlier turn left running (issue
#361): the interrupt callbacks `i_collect`, `i_make`, `i_repair` and
`i_sail`. The start and the natural finish of these orders are in other
fixtures (production-harvest, construction-build, use-crafts); this one
stops them part-way.

A STOP acts on day 0 only (`process_interrupted_units()`), and only on an
order still running from an earlier turn. So the scenario has a real turn
behind it, and is frozen whole as `scenario.tgz` (a patch over the base
world would be about 3 MB, since a month of play changes most of
`lib/loc`).

## Scenario

Eleven factions, 300–310, start in Greyfell (57081). `stop-running.lua`
sets nine of them going on orders that outlast turn 1, `olympia-g3` runs
turn 1, and `stop-running-stop.lua` queues a STOP and one more order for
each. The fixture runs turn 2.

| Faction | Noble | Turn 1 | Running when turn 1 ends | Turn 2: STOP, then |
|---|---|---|---|---|
| 300 Quarriers | Quarrier One [4126] | Mountain [13349], 1 worker: `collect 78 0 0` | 30 of the mountain's 50 stone quarried | `collect 78 2` |
| 301 Fisherfolk | Fisher One [8651] | a roundship on Ocean [13350], 2 sailors: `collect 87 0 0` | 22 fish caught; the fish are the ocean's, not the ship's | `wait time 1` |
| 302 Trainers | Trainer One [8159] | Greyfell, 125 peasants: `make 11 100` (one-day row) | 30 workers trained | `wait time 1` |
| 303 Wranglers | Wrangler One [7012] | Greyfell, 20 wild horses: `make 52 0` (3-day row) | 10 riding horses, the 11th under way | `wait time 1` |
| 304 Menders | Mender One [6947] | a tower, damage 10, 2 workers: `repair` | all 10 damage and 20 of 40 defense repaired | `wait time 1` |
| 305 Wallers | Waller One [8731] | a tower, no damage, 1 worker: `repair` | 15 defense repaired | `wait time 1` |
| 306 Patchers | Patcher One [8761] | a tower, damage 60, 2 workers: `repair` | 30 damage repaired | `wait time 1` |
| 307 Sailors | Sailor One [2294] | a roundship on Ocean [13350]: `wait day 28`, `sail north` | a 3-day leg begun on day 29 | `sail north` |
| 308 Pilots | Pilot One [3127] | the same: `wait day 28`, `use 601 north` | the same | `use 601 north` |
| 309 Idlers | Idler One [4821] | Forest [13451], 2 workers: nothing | `collect 77 0 0`, started by `oly.start` in turn 2's setup | `wait time 1` |
| 310 Loafers | Loafer One [7571] | a tower, 1 worker: nothing | `repair`, started by `oly.start` in turn 2's setup | `wait time 1` |

The towers are made by `oly.makeloc`, which leaves defense at 0 (a tower's
default is 40), and damaged by `oly.damage`. Two worker-days repair a
point.

What each STOP prints, after "Interrupt current order.":

- **collect**: the total so far, to the collector and, since quarrying and
  fishing are public, to the location: "Quarried 30 stone.", "Caught 22
  fish." (to the ocean, not the ship). With nothing collected it prints
  the harvest's "none now" line, here "All ready timber has already been
  cut this month.", although the forest has timber. The quarrier's next
  `collect` starts from zero.
- **make**: the one-day row prints its total ("Trained 30 workers."). The
  multi-day row prints nothing: each horse was reported as it was trained.
- **repair**: to the repairer and the tower (in Greyfell), both parts
  ("repaired ten damage and 20 defense"), one ("repaired 15 defense",
  "repaired 30 damage"), or nothing at all when nothing was repaired.
- **sail** and **use 601**: no message. The ship stops moving and stays
  where it was, so the next `sail north` leaves Ocean [13350] again and
  arrives on day 3.

`i_sail` also clears a ship's ferry horn, but a moving ship can't have one
sounded: `v_sail` clears the horn when the ship departs, and `ferry` is the
captain's order, so it can't run until the voyage is over. Running out of a
resource ends a collect on its own (the mountain's 50 stone, at three
workers, run out on day 17), so there is nothing for a STOP to interrupt.

## What `check.sh` asserts

1. `process_interrupted_units:interrupt` acted in the turn's
   `--phase-coverage` dump, and `collect:ok`, `sail:ok` and `use:ok` (the
   orders after the STOPs) in its `--coverage` dump.
2. Each faction's turn-2 report and unit state (`save/2/3xx`, `fact/3xx`)
   match `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`build-scenario.sh` runs `stop-running.lua` with `olyscript-g3` on the bare
map, runs turn 1 with `olympia-g3`, runs `stop-running-stop.lua` (which
reads the ids the first script wrote to `ids.lua`), and tars the lib as
`scenario.tgz`. Turn 1's reports and logs are left out: they are not turn
input. `oly.damage` was added for this fixture: no GM verb damages a
building.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.tgz (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
