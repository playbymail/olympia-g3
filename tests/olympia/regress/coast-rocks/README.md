# coast-rocks — a ship next to a mountain strikes submerged rocks

Pins the fix for #254. `near_rocky_coast()` (`olympia/day.c`) tells
`ship_coastal_damage()` what kind of coast a ship at sea is near. It did
this:

```c
if (subkind(l[i]->destination == sub_mountain))
	return 2;
```

The parenthesis was misplaced: it took `subkind()` of the comparison's
result (box 0 or 1) instead of comparing the destination's subkind with
`sub_mountain`. Neither box has a subkind, so the test was always false and
the function never returned 2. The "dangerous coast" case, a 1-in-50 daily
roll for 6–9 damage on submerged rocks, could not happen. A ship next to a
mountain rolled for the ordinary coastal reef instead (1 in 75, 3–5 damage).

Now the test is `subkind(l[i]->destination) == sub_mountain`.

The draws are keyed `wthr_wreck` leaves on (ship, day × 16 + slot), and the
reef and rocks cases use their own slots (0/1 and 2/3). So the fix changes
only ships next to a mountain, and no other draw moves.

## Scenario

Six factions, 300–305, start in Greyfell (57081). Each noble gives up its
peasants, is poofed out to an ocean province, builds a roundship there with
`makeloc` and goes aboard. Nobody has orders, so the ships sit at sea all
month.

| Faction | Ship | Ocean | Land next to it | Rocks | Reef | Before the fix |
|---|---|---|---|---|---|---|
| 300 Rocks One | [c319] | 13235 | mountain | 2 (days 4, 6) | 0 | 1 reef (day 12) |
| 301 Rocks Two | [n557] | 13244 | mountain | 2 (days 18, 30) | 0 | nothing |
| 302 Rocks Three | [g623] | 13249 | mountain | 1 (day 21) | 0 | 1 reef (day 20) |
| 303 Rocks Four | [a359] | 13377 | mountain | 0 | 0 | nothing |
| 304 Reef One | [g660] | 13245 | plain | 0 | 1 (day 8) | same |
| 305 Reef Two | [d335] | 13351 | forest | 0 | 0 | same |

Before the fix no ship struck rocks. 304 and 305 are controls: a coast with
no mountain rolls for the reef either way. 303's rolls miss either way.

## What `check.sh` asserts

1. Each faction's report holds the number of "struck some submerged rocks."
   and "struck a coastal reef." lines in the table above.
2. `ship_coastal_damage:damage` in the turn's `--phase-coverage` dump.
3. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match
   `EXPECT.sha256`.
4. The post-turn `--state-export` snapshot matches `EXPECT.json`.

Without the fix, check 1 fails for factions 300, 301 and 302 on both
presets.

## Authored in Lua

`coast-rocks.lua` builds the scenario with `olyscript-g3`;
`build-scenario.sh` freezes it as `scenario.patch` over the shared base
world.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
