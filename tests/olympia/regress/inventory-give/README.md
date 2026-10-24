# inventory-give — moving items between units

Pins the `ok` outcome of every inventory-family verb (issue #127, backlog
parent #116): `give`, `get`, `take`, `discard`, `drop`, `pay`, `accept`,
`claim` and `reclaim`. It also fires `form` (recruitment family), which the
keeper needs to get a second unit.

## Scenario

Three factions start in Greyfell (57081):

| Faction | Noble | Orders |
|---|---|---|
| 300 Keepers | Keeper One [4126] | `form 1375 Porter`, `give 1375 10 6`, `take 1375 10 2`, `get 1375 10 2`, `give 8651 10 3`, `pay 8651 25`, `claim 1 100`, `discard 10 1`, `drop 10 1` |
| 301 Traders | Trader One [8651] | `accept 4126 10 3` |
| 302 Leavers | Leaver One [8159] | `reclaim` |

`get` and `take` only take from units of the issuer's own faction (or its
prisoners), so the keeper first forms the porter [1375], the first id on its
faction's unformed list. The form takes 7 days, and the rest of the keeper's
orders run on day 8.

The trader's `accept` runs on day 1. On day 8 the keeper's `give` of three
peasants is let through by it (`will_accept`); without it the trader would
refuse them, as in `inventory-refused`. Gold is always accepted, so `pay`
needs no `accept`. `claim` takes gold from the Keepers' player entity, which
every new faction is given 5000 of.

`reclaim` disperses the leaver, so faction 302 ends the turn with no units.

## What `check.sh` asserts

1. Every cell above reaches `ok` in the turn's `--coverage` dump.
2. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match
   `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`inventory-give.lua` builds the scenario with `olyscript-g3`. It reads the
porter's id from the `unformed` list `oly.add_player` returns, which was added
for this fixture. `build-scenario.sh` runs the script on the bare map and
freezes the result as `scenario.patch` over the shared base world. The script
never runs the `-a` pass, so `build-scenario.sh` also swaps in `world.tgz`'s
`lib/log`; a turn deletes `lib/log` before it writes anything, so it is not
turn input.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
