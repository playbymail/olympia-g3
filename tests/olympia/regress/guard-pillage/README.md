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
output is preserved bit-for-bit. How RNG-derived state (passwords, minted ids)
is kept byte-identical is its own subsection below; two more byte-match
mechanics worth flagging:

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

### Determinism & the hashed passwords

The Lua build's pass/fail gate is byte-identity to the *committed* baseline, and
that constraint quietly decides how scenario-time RNG is handled. It is worth
spelling out, because it is the one place the prototype deviates from the letter
of [`doc/scripting-tool.md`](../../../../doc/scripting-tool.md) §3.2/§9.5.

**What the gate hashes.** Not the pre-turn `lib` — `check-lua.sh` runs a turn and
hashes `save/1/{300,301}` (the reports) plus `fact/{300,301}` (final faction +
noble state). And `fact/300` contains, among other things:

```
 pw IBjpkEtd                     <- random password
 un 2355                         <- noble id
 uf 3014 8402 5801 5533 1692     <- "unformed" entity ids
```

**Every one of those is a product of the process-global `rnd()` stream**
(`lib/rnd.c`), drawn during `add_new_player()` in a fixed order: one `rnd()` for
the noble slot (`new_ent` → `2355`), eight for the password (`IBjpkEtd`), one for
the starting-city pick (`rnd(1,6)`), then the `uf` draws. The password is stored
in the player entity and survives the turn unchanged into the hashed `fact/300`.

**The conflict.** §3.2 wants scenario-time allocation routed *off* the global
stream (explicit / #25-keyed) so build order can't perturb ids. But every draw
advances the same digest in place, so **removing or rerouting the noble draw
shifts the eight password draws that follow** — the password changes, `fact/300`
changes, the hash breaks. The committed baseline was built *on* the global
stream, and the password is in the hash, so "byte-identical to the existing
baseline" and "fully decouple allocation from the global stream" cannot both
hold. The DoD makes byte-identity the gate, so byte-identity wins.

**How it's resolved.** Keep the global-stream draws *exactly*, and take the
determinism win where it is free and real:

- `scenario_add_player()` mirrors `make_new_players_sup` step-for-step
  (`alloc_box(pl)` then `add_new_player()`), so the noble / password / city /
  `uf` draws happen in the identical order — `IBjpkEtd`, `2355`, … are
  reproduced bit-for-bit.
- The **faction box is the genuine deterministic allocation**: players `300`/`301`
  come from explicit `alloc_box(id, T_player, …)` — *zero* `rnd()` draws,
  reorder-stable — which is byte-neutral because `alloc_box` never touched the
  stream in the legacy flow either.
- The **registry removes the `awk` step**: the noble is still minted by
  `new_ent` (so it is `2355`), but the host *captures* that id and binds it to the
  author's name (`grok`). The author writes `pil.noble`, never `2355`. The build
  no longer depends on *recovering* a stream-derived number, even though the
  number is still stream-derived.
- Truly moving the password / `uf` / noble draws onto a keyed stream would change
  those values and force a re-baseline — **deferred**, out of scope for the
  prototype.

**Why one process reproduces three.** The legacy flow is three `oly` runs
(`-s`, `-a`, `-i`), each re-reading `lib/randseed` at startup. Collapsing them
into one process does not move the draw sequence, because the `-s` pass draws no
`rnd()` and does **not** save (`-S` absent), so its world-init draws are
discarded and `randseed` on disk is unchanged; the `-a` pass re-runs the same
init from the same seed before its add-player draws; and the `-i` pass loads that
saved seed with init already marked done (no re-draw). A single
`load → extract_startlocs (no rnd) → add_player → sculpt` process therefore lands
on the same stream state at every draw — which is why the passwords, ids, and
`uf` lists come out identical without reproducing the process boundaries.

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
