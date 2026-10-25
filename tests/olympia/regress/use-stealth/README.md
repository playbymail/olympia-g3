# use-stealth — use of the stealth skills

Pins the `ok` cells of the stealth skills in use group 2 (issue #192, use
backlog parent #180): `petty_thief` (631), `spy_inv` (632), `spy_skills`
(633), `spy_lord` (634), `find_rich` (636), `torture` (637), `hide_self`
(638) and `sneak_build` (639). `hide_lord` (635) is a `v_implicit` row,
left to group 10.

## Scenario

Five factions, 300–304, start in Greyfell (57081). Each noble with orders
knows the stealth school and the skills it uses:

| Faction | Noble | Place | Setup | Orders |
|---|---|---|---|---|
| 300 Cutpurses | Thief One [4126] | Greyfell | — | `use 631`, then `use 632`, `use 633`, `use 634` on the yielder |
| 301 Yielders | Yielder One [8651] | Greyfell | 1500 gold | `form` a hireling [8533], which `surrender`s to the captor |
| 302 Captors | Captor One [8159] | Greyfell | — | `wait time 10`, `use 637 8533` |
| 303 Gossips | Gossip One [7012] | an inn [67765] in Greyfell | — | `use 636` |
| 304 Shadows | Shadow One [6947] | a tower [60176] in Greyfell | no peasants | `use 638 1`, `use 639` |

Every start returns TRUE. The thief picks 78 gold from Greyfell's pockets,
then learns the yielder's inventory, skills and lord. The gossip hears that
the yielder carries a considerable amount of gold. As in stealth-hide, the
hireling's orders are queued before it exists and run once the 7-day form
makes it; it surrenders on day 8, and the captor tortures it (it refuses to
talk). The shadow hides, then sneaks out of its tower.

## What `check.sh` asserts

1. `use:ok` in the turn's `--coverage` dump, and every skill's `ok`
   cell above in its `--use-coverage` dump.
2. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`use-stealth.lua` builds the scenario with `olyscript-g3`;
`build-scenario.sh` freezes it as `scenario.patch` over the shared base world.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
