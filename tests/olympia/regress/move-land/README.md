# move-land — compass moves, enter/exit, and flight

Pins the `ok` outcome of the land movement verbs, their aliases, and `fly`
(issue #117, backlog parent #116).

## Scenario

Three factions, one noble each (peasants removed), all starting in the Forest
province **13451** [bs51] around the port city Greyfell (57081):

| Faction | Noble | Orders |
|---|---|---|
| 300 "Long Walkers" | Walker One | `enter`, `exit`, `s`, `north`, `west`, `east` |
| 301 "Short Walkers" | Walker Two | `in`, `out`, `south`, `n`, `w`, `e` |
| 302 "Sky Riders" | Rider One, 1 winged horse | `fly south`, `fly north` |

The walkers go into Greyfell and back out, then south to the Plain 13551
[bt51] and back, then west to the Plain 13450 [bs50] and back (1+1+7+7+7+7 =
30 days). The rider flies to the Plain 13551 and back in 3 + 4 days. Every
order starts within the month, so every verb reaches `ok`.

The two walkers run the same route so the long verbs and their aliases are
covered by identical moves. `s`, not `south`, is the primary verb in
`cmd_tbl`, so Walker One uses `s`.

## What `check.sh` asserts

1. Each of `enter exit s north west east in out south n w e fly` reaches `ok`
   in the turn's `--coverage` dump.
2. The three factions' reports and unit state (`save/1/30{0,1,2}`,
   `fact/30{0,1,2}`) match `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
