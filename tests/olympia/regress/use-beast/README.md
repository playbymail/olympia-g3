# use-beast — use of the beastmastery skills

Pins the `ok` cells of the beastmastery skills, use group 3 (issue #194, use
backlog parent #180): `bird_spy` (651), `breed_beasts` (654),
`catch_horse` (655), `train_wild` (656), `train_warmount` (657),
`summon_savage` (658), `keep_savage` (659) and `breed_hound` (661).
`capture_beasts` (652) and `use_beasts` (653) are `v_implicit` rows, left to
group 10.

## Scenario

Three factions, 300–302, start in Greyfell (57081). Each noble knows the
beastmastery school and the skills it uses:

| Faction | Noble | Place | Setup | Orders |
|---|---|---|---|---|
| 300 Wranglers | Wrangler One [4126] | Plain [13450] | 4 wild horses | `use 651 13451`, `use 654 51 51`, `use 655 2`, `use 656 1`, `use 657 1` |
| 301 Drummers | Drummer One [8651] | Plain [13450] | 1 drum; Savage [101396] beside it | `use 658`, `use 659 101396` |
| 302 Kennels | Kennel One [8159] | Greyfell | — | `use 661` |

Every start returns TRUE. The wrangler's bird reports on Forest [13451],
east of the plain. The wrangler then breeds two wild horses (and gets a
third), catches two more on the plain, and trains one each into a riding
horse and a warmount.

The drummer sounds a call to arms, then keeps Savage [101396], a band of 6
that `oly.savage` mints on the plain, bonded as an earlier call to arms
would leave it; it will remain for 5 months. (The savage this call brings,
[91968], arrives from the west only on day 7.)

`breed_hound` takes 28 days, so the kennel does nothing else that month.

## What `check.sh` asserts

1. `use:ok` in the turn's `--coverage` dump, and every skill's `ok` cell
   above in its `--use-coverage` dump.
2. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`use-beast.lua` builds the scenario with `olyscript-g3`;
`build-scenario.sh` freezes it as `scenario.patch` over the shared base world.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
