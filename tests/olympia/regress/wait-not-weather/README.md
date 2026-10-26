# wait-not-weather — `wait not rain` under a strong storm

Pins the fix for #247. Cases 11–13 of `check_wait_conditions()`
(`olympia/c1.c`), `rain`, `fog` and `wind`, did this:

```c
cond = (weather_here(province(c->who), sub_rain));
cond = not - cond;
```

`weather_here()` (`olympia/storm.c`) returns the summed strength of the
matching storms over the province, not 0/1. With `not` set and a storm of
strength 6, `cond = 1 - 6 = -5`, which is true, so `wait not rain` ended at
once and reported "it is not raining." while it was raining. Fog and wind
had the same bug. It showed only when the strength was 2 or more: at
strength 1, `1 - 1 = 0`. The plain forms worked, since `0 - sum` is nonzero
exactly when there is weather.

Now each case compares the sum with zero (`weather_here(...) > 0`), as the
other cases compare booleans.

## Scenario

Five factions, 300–304, start in Greyfell (57081) and are poofed out to the
storms `oly.storm` (#170) raises, each of strength 6 with no owner: Rain
[82126] and Fog [127789] over Forest [13550], and Wind [112143] over Plain
[13450].

| Faction | Noble | Place | Order | Wait finished |
|---|---|---|---|---|
| 300 Rainy | Rainy One [3743] | Forest [13550] | `wait not rain time 3` | three days have passed. |
| 301 Foggy | Foggy One [8078] | Forest [13550] | `wait not fog time 3` | three days have passed. |
| 302 Windy | Windy One [6087] | Plain [13450] | `wait not wind time 3` | three days have passed. |
| 303 Wet | Wet One [9236] | Forest [13550] | `wait rain time 3` | it is raining. |
| 304 Dry | Dry One [4940] | Forest [13449], no weather | `wait not rain time 3` | it is not raining. |

Before the fix, 300, 301 and 302 finished on day 1 with "it is not
raining.", "it is not foggy." and "it is not windy.". 303 and 304 are
controls: the forms that already worked end at once either way.

## What `check.sh` asserts

1. Each noble's `Wait finished:` line in its report gives the reason in the
   table above.
2. `wait:ok` in the turn's `--coverage` dump.
3. Each faction's report and unit state (`save/1/30x`, `fact/30x`) match
   `EXPECT.sha256`.
4. The post-turn `--state-export` snapshot matches `EXPECT.json`.

Without the fix, check 1 fails for factions 300, 301 and 302 on both
presets.

## Authored in Lua

`wait-not-weather.lua` builds the scenario with `olyscript-g3`;
`build-scenario.sh` freezes it as `scenario.patch` over the shared base
world.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./build-scenario.sh                     # regenerate scenario.patch (authoring only)
./check.sh --update                     # re-baseline after a deliberate change
```
