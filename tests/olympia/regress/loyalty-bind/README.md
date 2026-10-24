# loyalty-bind — binding nobles with gold, oaths and pledges

Pins the `ok` outcome of `honor` (and its alias `honour`), `oath` and
`pledge` (issue #143, backlog
parent #116). It also fires `form` and `give`, which the vassal needs to make
a noble that can be honored.

## Scenario

Two factions start in Greyfell (57081):

| Faction | Noble | Orders |
|---|---|---|
| 300 Vassals | Vassal One [4126] | `pledge 8651`, `form 1375 Hireling`, `give 1375 1 100`, `pledge 0` |
| 300 Vassals | Hireling [1375] | `honor 50`, `honour 25`, `oath 1`, `oath 2` |
| 301 Lords | Lord One [8651] | none |

A starting noble is already at oath-2, the maximum loyalty, so `honor` and
`oath` both fail on it (see `loyalty-refused`). A noble made by `form` starts
at contract-500, so the vassal forms the hireling [1375], the first id on its
faction's unformed list, and gives it 100 gold. The hireling's orders are
queued before it exists, as a player may order an unformed noble; they run
once the 7-day form makes it, on day 8, after the vassal's `give`:

| Order | Result | NP |
|---|---|---|
| `honor 50` | contract-550 | 0 |
| `honour 25` | contract-575 | 0 |
| `oath 1` | oath-1 | 1 |
| `oath 2` | oath-2 (from oath-1 it costs 1, not 2) | 1 |

With the form, the Vassals spend 3 NP (18 to 15).

`pledge 8651` reports "Lands are now pledged to Lord One~[8651]." to the
vassal and "Vassal One~[4126] pledges to us." to the Lords. `pledge 0` clears
it. A pledge only matters once land is ruled (governance), so the reports are
what pin it.

## What `check.sh` asserts

1. `honor`, `honour`, `oath` and `pledge` reach `ok` in the turn's `--coverage` dump.
2. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match
   `EXPECT.sha256`. The loyalty kind and rate are in `fact/300`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`loyalty-bind.lua` builds the scenario with `olyscript-g3`.
`build-scenario.sh` runs it on the bare map and freezes the result as
`scenario.patch` over the shared base world. The script never runs the `-a`
pass, so `build-scenario.sh` also swaps in `world.tgz`'s `lib/log`; a turn
deletes `lib/log` before it writes anything, so it is not turn input.

The hireling's orders need `oly.order` to accept an unformed noble (added in
#143): it queues them under the player whose unformed list holds the id.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
