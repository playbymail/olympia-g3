# use-art — use of the artifact construction skills

Pins the `ok` cells of the Artifact construction school, use group 6 (issue
#204, use backlog parent #180): `forge_aura` (881), `write_art` (882),
`forge_weapon` (883), `forge_armor` (884), `forge_bow` (885),
`curse_noncreat` (886), `show_art_creat` (887), `show_art_reg` (888),
`destroy_art` (889), `cloak_creat` (891), `cloak_reg` (892),
`rem_art_cloak` (893) and `forge_palantir` (894).

`rem_art_cloak` joined with #205: `v_rem_art_cloak` used to return FALSE
after its "Attempt to remove all cloaking spells" message, so the spell never
ran. The dispeller was added for it; every other faction's report changed
only because the dispeller is now seen on the plain.

## Scenario

Five factions, 300–304, start in Greyfell (57081) and are poofed to Plain
[13450], since magic may not be used in a safe haven. Each noble knows the
Artifact construction school and all its skills; each skill known adds one
aura, so each has 14. The curator's, the curser's and the dispeller's
palantirs come from `oly.palantir`: a palantir forged in the turn has an id
minted in the turn, which no order can name.

| Faction | Noble | Setup | Orders |
|---|---|---|---|
| 300 Forgers | Forger One [4126] | 1525 gold, 3 mithril, a mallorn wood, a gate crystal | `use 883 1`, `use 884 1`, `use 885 1`, `use 894` |
| 301 Auramakers | Auramaker One [8651] | 525 gold, a mithril, a blank scroll | `use 881 1`, `use 882 887` |
| 302 Curators | Curator One [8159] | Palantir [74170], 5 mithril | `use 887 74170`, `use 888 74170`, `use 891 74170`, `use 892 74170` |
| 303 Cursers | Curser One [7719] | Palantir [73052], a blank scroll | `use 886 73052`, `use 889 73052` |
| 304 Dispellers | Dispeller One [9463] | Palantir [72332], 5 mithril | `use 891 72332`, `use 892 72332`, `use 893 72332` |

Every start returns TRUE:

- The forger forges an enchanted sword, armor and bow at one aura each,
  for 500 gold and a mithril or mallorn wood apiece, then starts a palantir
  on day 22, which does not finish this turn.
- The auramaker forges an auraculum of one aura (a Gold ring), which also
  teaches it Advanced sorcery, then scribes Reveal creator of artifact.
- The curator learns that it made its palantir itself, in Provinia, then
  cloaks its creator and its region of creation at one aura each.
- The curser lays a noncreator curse of one aura on its palantir, then
  destroys it and gets a gate crystal from the shards.
- The dispeller cloaks its palantir's creator and region at one aura each,
  then dispels both cloaks for 8 aura; the dispel takes 10 days and
  finishes on day 25. (The curator's month is full: four 7-day uses.)

Each noble starts with 200 gold. The forger and the auramaker get 25 gold
beyond their forging, so they can pay their month-end upkeep. Cloaking the
creator needs 100 gold and 5 mithril in hand, scribing and destroying a
blank scroll, and a palantir a mithril and a gate crystal; none of these
requirements is spent at the start.

## What `check.sh` asserts

1. `use:ok` in the turn's `--coverage` dump, and every skill's `ok` cell
   above in its `--use-coverage` dump.
2. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`use-art.lua` builds the scenario with `olyscript-g3`;
`build-scenario.sh` freezes it as `scenario.patch` over the shared base world.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
