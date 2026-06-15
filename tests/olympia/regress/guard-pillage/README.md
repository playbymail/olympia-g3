# guard-pillage regression fixture

A small, self-contained scenario that drives a **guard-vs-pillager battle** and
pins the result. It is the first golden tree that exercises the **combat
resolution path** and, with it, the **per-battle keyed RNG** introduced for
issue #25 (`lib/rng.{c,h}`; `begin_battle()`/`crnd()` in `olympia/combat.c`).

## The scenario

Built by `build-scenario.sh` from the bare-map fixture
(`tests/olympia/fixtures/lib.tgz`) using the engine's own bootstrap:

- faction **300** "Pillager Horde" — noble **Warlord Grok** [2355], 50 soldiers,
  order `pillage 1`;
- faction **301** "Guard Order" — noble **Captain Vigil** [7700], 20 soldiers,
  `guard 1`;
- both in plain province **10113** (non-safe, has tax-cookie loot).

Running a turn drives `v_pillage → attack_guard_units → combat_top`, so the
battle's dice come from the per-battle stream keyed on (master seed, turn,
location). `check.sh` runs the turn and hashes the two faction reports
(`save/1/300`, `save/1/301`) plus final unit state (`fact/300`, `fact/301`)
against `EXPECT.sha256`.

## Run it

```bash
./tests/olympia/regress/guard-pillage/check.sh            # prints YES
./tests/olympia/regress/guard-pillage/check.sh --update   # re-baseline
OLYMPIA_PRESET=asan-ubsan ./tests/olympia/regress/guard-pillage/check.sh
```

`build-scenario.sh` regenerates `scenario.tgz` (a one-time authoring tool, not
run by the test). The frozen `scenario.tgz` is pure data, so the test —
extract, run a turn, diff report bytes — ports directly to a future engine.

## What this does NOT test: issue #4

This fixture was originally intended to pin the **issue #4** guard-dedup fix
(`combat.c`, the `l_a[j]->unit == i` membership scan). Investigation showed that
branch is **unreachable through the pillage path**:

- `attack_guard_units` builds `l_a = construct_fight_list(a, b, FALSE, FALSE)`
  with **`add_allies = FALSE`**, so `l_a` is only the pillager's own stack
  (leader + units stacked under it).
- `construct_guard_fight_list` finds guard candidates via
  `loop_here(province)`, which returns only **province-direct** occupants.
- A unit is either province-direct **or** stacked under the pillager — never
  both — so a guard found by the loop can never be in `l_a`. The `#4`
  membership check therefore never matches.

Confirmed empirically: building this scenario with the **fixed** and the
**buggy** `#4` code (the original `fights_lookup(l_a, (struct fight *)(long)i)`)
produces a **byte-identical** report. The `#4` fix is correct-on-principle
hardening of an unreachable branch; it has no observable effect for any
constructible game state, so no black-box fixture can distinguish it.
