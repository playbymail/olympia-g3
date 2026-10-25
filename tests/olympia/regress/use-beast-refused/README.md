# use-beast-refused — refused uses of the beastmastery skills

Pins the `fail` cells of the beastmastery skills, use group 3 (issue #194,
use backlog parent #180): `bird_spy` (651), `breed_beasts` (654),
`catch_horse` (655), `train_wild` (656), `train_warmount` (657),
`summon_savage` (658) and `keep_savage` (659). `breed_hound` (661) always
starts, so it cannot fail. `capture_beasts` (652) and `use_beasts` (653)
are `v_implicit` rows, left to group 10.

## Scenario

One faction, 300 Bunglers. Its noble, Bungler One [4126], knows the
beastmastery school and every skill below, has no animals and no drum, and
is poofed to Forest [13451], where no wild horses roam. Every use passes
`v_use`'s shared checks, reaches its start, and fails there:

| Order | Skill | Start's refusal |
|---|---|---|
| `use 651` | bird_spy | Specify what location the bird should spy on. |
| `use 654 51 51` | breed_beasts | Don't have any [51]. |
| `use 655 1` | catch_horse | Wild horses are found on the plains and in pastures. |
| `use 656 1` | train_wild | Don't have any wild horses [51]. |
| `use 657 1` | train_warmount | Don't have any wild horses [51]. |
| `use 658` | summon_savage | Must first make a drum with MAKE 98 1. |
| `use 659 4126` | keep_savage | [4126] is not a group of savages. |

## What `check.sh` asserts

1. `use:fail` in the turn's `--coverage` dump, and every skill's `fail`
   cell above in its `--use-coverage` dump.
2. The faction's report and unit state (`save/1/300`, `fact/300`) match `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`use-beast-refused.lua` builds the scenario with `olyscript-g3`;
`build-scenario.sh` freezes it as `scenario.patch` over the shared base world.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
