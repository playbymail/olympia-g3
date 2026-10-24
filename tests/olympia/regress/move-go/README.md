# move-go — the GO order

Pins the `ok` outcome of `go` (issue #117, backlog parent #116). `go` runs the
same `v_move` as `move`, whose `ok` the main golden turn already covers through
NPC movement; this fixture pins `go` itself, through a player's order file, in
both of its forms.

## Scenario

One faction, **300** "Go Walkers", whose noble Walker One (peasants removed)
starts in the Forest province **13451** [bs51] around the port city Greyfell.
Its orders:

| Order | Form | Result |
|---|---|---|
| `go south` | direction | Plain 13551 [bt51], 7 days |
| `go 13451` | destination id | back to the Forest, 8 days |
| `go 57081` | sublocation id | into Greyfell, 1 day |

## What `check.sh` asserts

1. `go` reaches `ok` in the turn's `--coverage` dump.
2. The faction's report and unit state (`save/1/300`, `fact/300`) match
   `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.tgz (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
