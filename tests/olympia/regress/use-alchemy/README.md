# use-alchemy — use of the alchemy skills

Pins the `ok` cells of the alchemy skills in use group 2 (issue #192, use
backlog parent #180): `brew_heal` (691), `record_skill` (692),
`extract_venom` (693), `brew_slave` (694), `brew_death` (696) and
`lead_to_gold` (697). `collect_elem` (695) is a `v_implicit` row, left to
group 10.

## Scenario

Two factions, 300 and 301, stay in Greyfell (57081). Each noble knows the
alchemy school, the skills it uses, and has what each skill requires:

| Faction | Noble | Setup | Orders |
|---|---|---|---|
| 300 Brewers | Brewer One [4126] | an avinia leaf, ratspider venom, lana bark, a ratspider | `use 691`, `use 694`, `use 696`, `use 693` |
| 301 Scholars | Scholar One [8651] | a farrenstone, 5 lead, a blank scroll | `use 697 5`, `use 692 697` |

Every start returns TRUE. The brews share `v_brew` and make three potions,
minted as unique items. `extract_venom` has no start: `v_use` hands it to
`skill_produce` on day 25, and it is still running at turn end. The scholar
turns its 5 lead into 50 gold, then starts scribing `lead_to_gold` onto the
scroll, a four-week job.

## What `check.sh` asserts

1. `use:ok` in the turn's `--coverage` dump, and every skill's `ok`
   cell above in its `--use-coverage` dump.
2. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`use-alchemy.lua` builds the scenario with `olyscript-g3`;
`build-scenario.sh` freezes it as `scenario.patch` over the shared base world.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
