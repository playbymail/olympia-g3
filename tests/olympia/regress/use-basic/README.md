# use-basic — use of the basic magic skills

Pins the `ok` cells of the Magic school, use group 4 (issue #196, use
backlog parent #180): `meditate` (801), `mage_menial` (802),
`appear_common` (803), `view_aura` (804), `heal` (805), `write_basic`
(806), `reveal_mage` (807), `tap_health` (808), `shroud_abil` (809),
`detect_abil` (811), `dispel_abil` (812), `adv_med` (813) and
`hinder_med` (814).

## Scenario

Three factions, 300–302, start in Greyfell (57081) and are poofed to Plain
[13450]: magic may not be used in a safe haven, and Greyfell and its forest
are safe. Each noble knows the Magic school and the skills it uses. Each
skill known adds one aura.

| Faction | Noble | Aura | Setup | Orders |
|---|---|---|---|---|
| 300 Adepts | Adept One [4126] | 7 | a blank scroll | `use 803 1`, `use 805 8651`, `use 804 1`, `use 807 8651 800 1`, `use 806 801` |
| 301 Patients | Patient One [8651] | 5 | sick (`oly.sick`) | `use 801`, `use 808 1`, `use 813`, `use 811` |
| 302 Shrouders | Shrouder One [8159] | 5 | — | `use 809 1`, `use 812 4126`, `use 814 8651 1`, `use 802` |

Every start returns TRUE. The adept appears common, tries to heal the
patient (the spell fails its roll), views the aura of the three mages,
reveals the patient's Magic spells and scribes Meditate onto its blank
scroll (two weeks, so it doesn't finish this turn). The patient meditates,
taps its health for an aura, meditates again (advanced) and practices
ability scry detection; it recovers from its illness on its own.

The shrouder shrouds its abilities (so the adept sees its aura as `???`),
dispels the adept's shroud (there is none), hinders the patient's
meditation and earns 50 gold working at common magic on the plain.

`heal` starts only on a sick target, and nothing before the turn makes one,
so the patient is marked sick with `oly.sick`. Scribing needs a blank scroll
[84], a `meets_requirements` check made before the start.

## What `check.sh` asserts

1. `use:ok` in the turn's `--coverage` dump, and every skill's `ok` cell
   above in its `--use-coverage` dump.
2. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`use-basic.lua` builds the scenario with `olyscript-g3`;
`build-scenario.sh` freezes it as `scenario.patch` over the shared base world.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
