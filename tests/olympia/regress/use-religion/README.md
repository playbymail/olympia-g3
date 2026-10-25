# use-religion — use of the religion skills

Pins the `ok` cells of the religion skills in use group 2 (issue #192, use
backlog parent #180): `reveal_vision` (751), `last_rites` (752), `pray`
(753), `resurrect` (754), `remove_bless` (755) and `vision_protect` (756).

## Scenario

Five factions, 300–304, start in Greyfell (57081). The nobles of 303 and
304 are killed with `oly.kill` (#192), which hands each dead body to the
priest that needs it. Each priest knows the religion school and the skills
it uses:

| Faction | Noble | Place | Setup | Orders |
|---|---|---|---|---|
| 300 Seers | Seer One [4126] | Greyfell | — | `use 751 57081`, `use 755`, `use 756` |
| 301 Healers | Healer One [8651] | Greyfell | Lazarus One's body [7012] | `use 753`, `use 754 7012` |
| 302 Mourners | Mourner One [8159] | Graveyard [59022] | Departed One's body [6947] | `use 752 6947` |
| 303 Risen | Lazarus One [7012] | — | killed | — |
| 304 Departed | Departed One [6947] | — | killed | — |

Every start returns TRUE. The seer fails to receive its vision (a 50%
draw), finds no blessed soldiers to unbless, and protects itself from
visions. The healer's prayer makes its next religious act succeed, and the
body's defense is above 50, so it brings Lazarus One back to life on day
13. The mourner lays Departed One to rest, and faction 304 gains the noble
points back.

### The bodies

No GM verb gives a character a dead body. `oly.kill` runs the `kill` verb
as the priest; `kill_char` turns the noble into a dead body item that keeps
its id and leaves it in the province, and the binding moves it to the
priest. See `doc/scripting-tool.md`.

## What `check.sh` asserts

1. `use:ok` in the turn's `--coverage` dump, and every skill's `ok`
   cell above in its `--use-coverage` dump.
2. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`use-religion.lua` builds the scenario with `olyscript-g3`;
`build-scenario.sh` freezes it as `scenario.patch` over the shared base world.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
