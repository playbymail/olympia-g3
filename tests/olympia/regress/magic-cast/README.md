# magic-cast — trancing, breeding and binding a storm

Pins the `ok` outcome of `trance`, `breed` and `bind` (issue #149, backlog
parent #116).

## Scenario

Three factions start in Greyfell (57081), a safe haven:

| Faction | Noble | Set up | Orders |
|---|---|---|---|
| 300 Trancers | Trancer One [4126] | knows Advanced sorcery [920] and Trance [921]; builds the empty Roundship [64623] on the dock | `trance` |
| 301 Breeders | Breeder One [8651] | knows Beastmastery [650] and Breed beasts [654]; one ox [76] | `breed 10 76` |
| 302 Binders | Binder One [8159] | knows six magic skills (6 aura); aboard Roundship [74170] in Greyfell; owns Rain [91520] over Forest [13451] | `bind 91520`, `move out`, `move 64623`, `bind 91520` |

- **trance.** `v_trance` needs only the skill. The trance takes 28 days, and
  on day 28 `d_trance` raises current aura to two thirds of the maximum. The
  trancer's 2 aura is already above that and its health is 100, so it
  reports "Current aura is now 2." and heals nothing. Trance is not cast
  through `use`, so the safe haven does not stop it.
- **breed.** A peasant and an ox breed a minotaur (`breed_tbl`) in 7 days.
  The breeding accidents and the offspring are draws on the social stream
  (`soc_breed`, see
  [doc/claude/rng-streams.md](../../../../doc/claude/rng-streams.md)). On
  day 7 the peasant is killed, and a minotaur is still produced. The hash
  pins both draws.
- **bind.** `oly.storm` (#170) raises Rain [91520], strength 6, over
  Greyfell's forest [13451] at build time and records the binder as its
  summoner. It spends the forest's rain cookie, as a summon would. `bind` is
  its own verb, not a spell cast through `use`, so the safe haven doesn't
  stop it. On day 7 `d_bind_storm` spends 3 aura and binds the storm to
  Roundship [74170]. On day 8 the binder steps out onto the dock and boards
  the empty Roundship [64623], and on day 14 it rebinds the storm there for
  its other 3 aura. Month end decays the storm to strength 5 and
  regenerates the binder's aura to 2.

The rebind pins the #169 fix. `d_bind_storm` records the ship on the storm
(`bind_storm`, `bs` in `lib/misc`) and adds the storm to the ship's
`bound_storms` (`bs` in `lib/ship`). A rebind looks up the old ship through
the storm's `bind_storm` and takes the storm off it. Before the fix,
`bind_storm` held the storm itself, so the lookup found nothing, and the
storm stayed on both ships' lists. `lib/ship` is in the manifest, so the
first ship's emptied list and the barge's entry are both hashed.

## What `check.sh` asserts

1. `trance`, `breed` and `bind` reach `ok` in the turn's `--coverage` dump.
2. Each faction's report and unit state (`save/1/30x`, `fact/30x`) and the
   ship file (`ship`) match `EXPECT.sha256`.
3. The post-turn `--state-export` snapshot matches `EXPECT.json`. Aura,
   health and storms aren't exported (#114), so the hashes carry them.

## Authored in Lua

`magic-cast.lua` builds the scenario with `olyscript-g3`.
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
