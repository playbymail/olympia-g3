# magic-cast — trancing, breeding and binding a storm

Pins the `ok` outcome of `trance`, `breed` and `bind` (issue #149, backlog
parent #116).

## Scenario

Three factions start in Greyfell (57081), a safe haven:

| Faction | Noble | Set up | Orders |
|---|---|---|---|
| 300 Trancers | Trancer One [4126] | knows Advanced sorcery [920] and Trance [921] | `trance` |
| 301 Breeders | Breeder One [8651] | knows Beastmastery [650] and Breed beasts [654]; one ox [76] | `breed 10 76` |
| 302 Binders | Binder One [8159] | knows six magic skills (6 aura), aboard Roundship [74170] in Ocean [13351] | `use 825 3`, `bind 122602` |

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
- **bind.** Nothing in `oly` makes a storm, so the binder summons one in the
  turn. Magic may not be used in a safe haven, so the binder's ship is built
  at sea in Ocean [13351], north of Greyfell's forest, which holds a rain
  cookie. `use 825 3` spends 3 aura and on day 8 summons Rain [122602] with
  strength 6. The storm id comes from the turn's mint and was read from a
  run. `bind 122602` spends the other 3 aura, and on day 15 binds the storm
  to the ship. Month end decays the storm to strength 5 and regenerates the
  binder's aura to 2. Also on day 3, the ship strikes a coastal reef and
  takes minor damage (weather stream).

`d_bind_storm` appends the storm to the ship's `bound_storms` (`bs` in
`lib/ship`) but sets the storm's own `bind_storm` to the storm, not the
ship. Every Olympia generation has this line. The fixture takes the turn as
the engine runs it. `lib/ship` is in the manifest, so the ship's side of the
binding is hashed. The storm's side is in `lib/misc`, which is not hashed.

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

If a change moves the turn's mint, the summon mints a different storm id and
`bind` fails. Run the turn, read the new id from the Binders' report
("Summoned Rain [...]"), set `STORM` in `magic-cast.lua`, and rebuild.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
