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

## Same scenario, authored as one Lua script (issue #31)

`guard-pillage.lua` + `check-lua.sh` rebuild the *exact same* pre-turn `lib` with
the `olyscript-g3` scenario-scripting host (the embedded-Lua prototype, see
[`doc/scripting-tool.md`](../../../../doc/scripting-tool.md) §8–§9) instead of
the six-tool `build-scenario.sh` dance, and assert the post-turn manifest is
**byte-identical to the same committed `EXPECT.sha256`**:

```bash
./tests/olympia/regress/guard-pillage/check-lua.sh                 # prints YES
OLYMPIA_PRESET=asan-ubsan ./tests/olympia/regress/guard-pillage/check-lua.sh
```

It is the prototype's pass/fail gate: one readable, error-checked script
replaces the tar + `oly -s` + hand-written `Join-g3` + `oly -a` +
`awk`-recover-ids + piped `oly -i` + hand-written orders flow, and the engine
output is preserved bit-for-bit. Determinism notes:

- A single deterministic process loading the fixed `randseed` reproduces the
  legacy three-process `rnd()` draw sequence exactly (the `-s` pass's world-init
  draws are discarded unsaved, so one process is equivalent). Faction boxes are
  allocated at explicit ids (no `rnd()`); the nobles are minted by the engine and
  **named** via the host registry, so the `awk` id-recovery step is gone.
- `add_player` replays the `-a` pass's in-place item-list sort
  (`scenario_sort_items`, mirroring `report.c`'s `inv_item_comp`), since the host
  issues no reports; and the entity ops replay the `-i` `be/.../save` stream so
  per-entity command state matches.
- Surfaced (and fixed for the host build only) a latent stack-buffer-overflow in
  `add.c`'s `get_city_id` — `atoi()` on an unterminated `strncpy` buffer — which
  ASan flags the first time the add-player path runs under sanitizers. The
  standard turn never reaches it, so the engine build is left byte-for-byte
  unchanged.

Both `build-scenario.sh`/`check.sh` (the frozen `scenario.tgz`) and the Lua pair
are kept side by side — the rollout is incremental; `-i`/`-a` stay load-bearing.

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
