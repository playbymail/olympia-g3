# use-scry — use of the scrying skills

Pins the `ok` cells of the Scrying school, use group 4 (issue #196, use
backlog parent #180): `scry_region` (841), `write_scry` (842),
`shroud_region` (843), `dispel_region` (844), `bar_loc` (845), `unbar_loc`
(846), `locate_char` (847), `detect_scry` (848), `proj_cast` (849),
`save_proj` (851) and `banish_corpses` (852).

## Scenario

Three factions, 300–302, start in Greyfell (57081) and are poofed to Plain
[13450], since magic may not be used in a safe haven. Each noble knows the
Scrying school and the skills it uses; each skill known adds one aura.

| Faction | Noble | Aura | Setup | Orders |
|---|---|---|---|---|
| 300 Barriers | Barrier One [4126] | 5 | a blank scroll | `use 845 1`, `use 846 0 1`, `use 841 13550 1`, `use 842 841` |
| 301 Shrouders | Shrouder One [8651] | 7 | — | `use 843 1`, `use 844 13450`, `use 847 4126 1`, `use 848` |
| 302 Projectors | Projector One [8159] | 6 | — | `use 849 13550`, `use 851`, `use 852` |

Every start returns TRUE:

- The barrier mage puts an aura-one barrier over the plain, tries to remove
  it (the attempt fails its roll, and the barrier dissipates at month end),
  scries Forest [13550], to the south, and spends three weeks scribing Scry
  location, which does not finish this turn.
- The shrouder cloaks the plain in an aura-two shroud, dispels it, locates
  the barrier mage and practices location scry detection.
- The projector projects its next cast to the forest, saves that state as a
  magic potion and banishes the undead here (there are none).

`unbar_loc` starts only over a barrier, and `save_proj` only with a projected
cast active, so each follows the use that sets it up, by the same noble.

## What `check.sh` asserts

1. `use:ok` in the turn's `--coverage` dump, and every skill's `ok` cell
   above in its `--use-coverage` dump.
2. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`use-scry.lua` builds the scenario with `olyscript-g3`;
`build-scenario.sh` freezes it as `scenario.patch` over the shared base world.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
