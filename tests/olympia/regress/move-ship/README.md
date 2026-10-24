# move-ship — ships and ferries

Pins the `ok` outcome of `board`, `unload`, `ferry` and `sail` (issue #117,
backlog parent #116), and of `fee` from the trade family along the way.

## Scenario

Two factions in the port city Greyfell (57081), peasants removed:

- **300** "Ferry Line": Captain One knows Shipcraft (600) and Sailing (601),
  carries 8 sailors (a roundship's full crew, so there is no delay), and
  captains a roundship built in Greyfell with the GM `makeloc` tool.
- **301** "Travellers": Passenger One, on the dock.

The measured turn is a one-passenger ferry trip:

| Captain | Passenger |
|---|---|
| `fee 1` (boarding fee per 100 weight) | `wait ferry <ship>` |
| `ferry` (sound the horn) | `board <ship>` (pays 1 gold) |
| `wait time 1` | |
| `sail east` to Ocean [bs52] | |
| `sail west` back to Greyfell | |
| `unload` (passenger goes ashore) | |

## What `check.sh` asserts

1. Each of `board unload ferry sail fee` reaches `ok` in the turn's
   `--coverage` dump.
2. Both factions' reports and unit state (`save/1/30{0,1}`, `fact/30{0,1}`),
   plus the ship file (`ship`), match `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

The state export has no ship state yet: the ship shows up as a location with
no exits. Ship fields are on the #114 list. Until then the hashed `ship` file
and the captain's report are what pin the voyage.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
