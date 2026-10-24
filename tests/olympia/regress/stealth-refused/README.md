# stealth-refused — stealth orders that fail or are refused

Pins the `fail` and `rejected` outcomes of `hide`, `sneak` and `torture`
(issue #145, backlog parent #116).

## Scenario

Three factions start in Greyfell (57081):

| Faction | Noble | Set up |
|---|---|---|
| 300 Bunglers | Bungler One [4126] | no stealth skill; 25 peasants |
| 301 Crowds | Crowd One [8651] | knows Hide self [638] and Torture [637]; 25 peasants |
| 302 Loners | Loner One [8159] | no peasants; made a tower [74170] but stays outside it |

Every failure is instant, on day 1 or 2:

| Unit | Order | Fails with |
|---|---|---|
| bungler | `hide 1` | Requires Conceal self. |
| bungler | `hide 0` | Requires Conceal self. (unhiding needs the skill too) |
| bungler | `torture 8651` | Requires Torture prisoner. |
| bungler | `sneak 74170` | Must be alone in order to sneak. (its peasants count) |
| crowd | `hide 1` | Must be alone to hide. |
| crowd | `torture 4126` | [4126] is not a prisoner of Crowd One. |
| loner | `sneak` | Not in a structure. |
| loner | `sneak north` | May only sneak into buildings and ships. |

Rejected: all three verbs are for nobles (`c`), so the Bunglers' player
entity orders `hide`, `sneak` and `torture`, and `check_allow()` refuses
each.

Not reached: torturing an NPC, sneaking out onto the ocean or over an
impassable route or onto a ship underway, and a prisoner dying under
torture. A prisoner who refuses to talk fails in `d_torture`, after the
start, so it is not a `fail` cell.

## What `check.sh` asserts

1. Each of the three verbs reaches `fail` and `rejected` in the turn's
   `--coverage` dump.
2. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match
   `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`.

## Authored in Lua

`stealth-refused.lua` builds the scenario with `olyscript-g3`.
`build-scenario.sh` runs it on the bare map and freezes the result as
`scenario.patch` over the shared base world. The script never runs the `-a`
pass, so `build-scenario.sh` also swaps in `world.tgz`'s `lib/log`; a turn
deletes `lib/log` before it writes anything, so it is not turn input.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
