# use-alchemy-refused — refused uses of the alchemy skills

Pins the `fail` cells of the alchemy skills in use group 2 (issue #192, use
backlog parent #180): `record_skill` (692) and `lead_to_gold` (697). The
other `fail` cells are `n/a`: the three brews start with `v_brew`, which
always returns TRUE, and `extract_venom` (693) has no start. `collect_elem`
(695) is a `v_implicit` row, left to group 10.

## Scenario

One faction, 300 Bunglers. Its noble, Bungler One [4126], stays in
Greyfell (57081), knows the alchemy school, `record_skill` and
`lead_to_gold`, and has the blank scroll `record_skill` requires (without
it, `meets_requirements` would stop the use before its start), but no
farrenstone or lead:

| Order | Skill | Start's refusal |
|---|---|---|
| `use 692 600` | record_skill | Bungler One does not know [600]. |
| `use 697` | lead_to_gold | Requires one farrenstone. |

## What `check.sh` asserts

1. `use:fail` in the turn's `--coverage` dump, and every skill's `fail`
   cell above in its `--use-coverage` dump.
2. The faction's report and unit state (`save/1/300`, `fact/300`) match `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`use-alchemy-refused.lua` builds the scenario with `olyscript-g3`;
`build-scenario.sh` freezes it as `scenario.patch` over the shared base world.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
