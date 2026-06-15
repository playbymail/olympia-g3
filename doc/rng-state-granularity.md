# RNG-state granularity — survey & recommendation (issue #25)

Status: **design / exploration.** Groundwork for Project Ultron
([agentic-project-ultron.md](agentic-project-ultron.md)). The prototype seam
described here (`lib/rng.{c,h}`) is committed but **unwired** — no engine code
calls it yet, so golden output is unchanged.

## The problem

`lib/rnd.c` (and the engine's copy, `olympia/rnd.c`) keep **one process-global
RNG stream**:

```c
static word32 digest[4];                 /* the entire RNG state   (rnd.c:275) */

int rnd(int low, int high) {             /* rnd.c:301                          */
    ...
    MD5(digest, digest, sizeof(digest)); /* advance the single global stream   */
    num = digest[0] & mask;
    ...
}
```

`digest[]` is loaded from `lib/randseed` at startup (`load_seed`, via
`io.c:2740`) and written back at turn end (`save_seed`, via `io.c:2894`). Every
subsystem — combat, market/city seeding, monster movement, weather, quests,
NPCs — draws from this **one linear sequence, strictly in call order**
(`combat.c`, `buy.c`, `day.c`, `quest.c`, `tunnel.c`, `npc.c`, … ~264 `rnd()`
sites across 32 files).

Because the stream is global and serial, **adding, removing, or reordering a
single `rnd()` call anywhere shifts every draw after it.** One perturbation
re-bakes the entire **206-file golden manifest**
(`tests/olympia/golden/manifest.sha256`). The #4 combat fix is the canonical
example: it only stayed golden-neutral because the turn-1 fixtures never reach
the guard path and so never perturb the stream — the moment a fixture *does*
exercise new combat, the whole manifest moves.

That all-or-nothing blast radius is the single biggest tax on landing behavior
changes, and it is the **blocker for Project Ultron**: the coverage plan needs
small, independently re-baselineable fixtures (a combat fixture, a market
fixture, …) so that a change to one subsystem re-bakes only *that subsystem's*
golden tree. There is no small tree to capture while one global stream couples
everything.

### The seam already in the tree

`lib/rnd.c:319` already has a **stateless, position-independent** primitive:

```c
int md5_int(int a, int b, int c, int d);   /* keyed hash; no global state */
```

used e.g. at `buy.c:1442` (`md5_int(city_sold, where, item, 0xb05c0e) & 1`).
This is exactly the "derive randomness from a key, not from stream position"
model that the recommendation below generalizes.

## Options

| # | Approach | Blast-radius win | Call-site churn |
|---|----------|------------------|-----------------|
| 1 | **Keyed / stateless draws** — replace order-dependent `rnd()` with draws keyed on stable inputs, `hash(entity, turn, purpose, sub_index)`. A draw no longer depends on how many draws preceded it. | **Largest** — true fix; reordering other code can't move a draw. | **Largest** — every migrated call site changes. |
| 2 | **Per-subsystem / per-stream state** — keep `rnd()` stateful but split `digest` into named streams (combat, market, weather, …) seeded from master + a stream tag. | Partial — reordering *within* a stream still perturbs it, but subsystem A no longer moves subsystem B. | Smaller — mostly threading a stream handle. |
| 3 | **Per-entity / per-turn reseed checkpoints** — snapshot/reseed at well-defined boundaries (per noble, per location, per turn-phase). | Coarse — partitions the golden tree along those seams only. | Smallest — no per-draw change. |

Each option requires a **one-time, deliberate golden re-baseline** when it lands
(it changes the stream once). The win is that *subsequent* changes stop
re-baking everything.

## Recommendation

**A hierarchy of deterministic seeds with keyed leaf draws** — option 1, with
option 2's stream handles as the carrier. Derive seeds from stable keys rather
than by consuming a shared stream, so creation order is irrelevant:

```
master seed
  └─ turn seed            = hash(master, turn)
      └─ subsystem seed   = hash(turn,   "combat")
          └─ scenario seed= hash(combat, location, battle_id)
              └─ leaf draw = hash(scenario, round, attacker, defender, "hit")
```

- **Subsystem/scenario seeds** are derived by key (`hash(parent, key, tag)`), so
  initializing combat before or after market yields identical seeds for each.
- **Leaf draws are keyed**, so inserting a new morale check between the hit and
  damage rolls cannot move either one.
- **Replay becomes addressable**: a battle re-runs from
  `(master, turn, "combat", location, battle_id)` alone — independent of how many
  draws any other subsystem made.

### Generator: keep MD5 as the hash, defer PCG32

Two *separate* concerns: (a) how randomness is **addressed/partitioned**, and
(b) **which generator** produces values. (a) is the one that solves the
blast-radius problem; do it first, alone.

- **Now:** use the existing `MD5()` as the tuple→seed hash (it is already
  deterministic, portable, and depended upon). This is what the prototype does.
- **Later, optional, separate track:** replace MD5-per-draw with a lightweight
  stream generator — **PCG32** is the recommended candidate (tiny state, fast,
  explicit stream support; xoshiro is a fine alternative). Roll it out gradually
  behind the same `rng_*` seam, subsystem by subsystem; never big-bang. This
  only becomes easy *after* the addressing model is no longer tied to one global
  stream.

## The seam — `lib/rng.{c,h}`

A small, **MD5-backed** layer codifies the recommended API:

```c
typedef struct { uint32_t seed[4]; uint32_t counter; } rng_stream;

rng_stream rng_seed(const uint32_t master[4]);
rng_stream rng_stream_of(const rng_stream *parent, int key, uint32_t tag);
int        rng_draw(rng_stream *s, int low, int high);                 /* sequential */
int        rng_keyed(const rng_stream *s, int k1, int k2, uint32_t tag,
                     int low, int high);                               /* keyed leaf */
```

Range reduction (mask + rejection) mirrors legacy `rnd()` exactly, so
distribution semantics are unchanged — only the *addressing* differs. The
standalone check `tests/rng/check.sh` asserts the three properties that make the
approach worth adopting: determinism, keyed independence (an inserted draw does
not move a sibling), and order-independent stream derivation.

## First consumer: combat resolution

Combat is the first subsystem migrated onto the seam. The immutable master seed
is captured at `load_seed()` time (`rng_master_seed()`, defined alongside the
legacy `rnd()` in each target's `rnd.c`). At the single battle chokepoint
`combat_top()`, `begin_battle(where)` derives a **per-battle stream** from
`(master seed, turn, location)`; the ~13 resolution-stage draws now go through
`crnd()` (`rng_draw` on that stream) instead of global `rnd()`. A battle's dice
are thus addressable and independent of how many global draws preceded them.

Because the standard turn-1 fixtures run **no combat** (the bare map has zero
characters), this migration is **byte-neutral on the 206-file main manifest** —
it required no re-baseline. The new behavior is pinned by its own small golden
tree, `tests/olympia/regress/guard-pillage/` (a pillager-vs-guard battle).

This first migration used **per-stream isolation** (sequential `rng_draw` within
a battle), not fully keyed leaf draws — the smaller-churn option that already
delivers cross-subsystem isolation. Keyed leaf draws (`rng_keyed`) remain a
future refinement.

## Second consumer: pillage loot/mob path

The pillage path (`d_pillage`) is the next subsystem migrated. It is a sibling of
the combat stream, derived under the same turn root but with a distinct tag:

```
turn seed
  ├─ (location, TAG_COMBAT)  → combat_rng  (battle resolution)
  └─ (location, TAG_PILLAGE) → pillage_rng (loot/mob draws)
```

`begin_pillage(where)` reseeds `pillage_rng` at the top of `d_pillage` (after the
men/loot early-outs); `prnd()` (`rng_draw` on that stream) replaces the two
mob-formation `rnd()` calls (does a peasant mob form, does it queue an attack).
The mob's **name** draw — in `create_peasant_mob()` (`olympia/npc.c`), which has
exactly one caller — was migrated too: the function now takes the pillage stream
as a parameter (`create_peasant_mob(where, &pillage_rng)`) and draws via
`rng_draw`. Distinct tags mean a pillage and a battle at the **same**
`(turn, location)` draw from independent streams.

**Known residual coupling.** The mob's *troop count* draw lives in the shared
`do_cookie_npc()` (`npc.c:508`), which also backs undead / storm / savage
spawning — so it stays on the global `rnd()` for now. A pillage that *forms a
mob* therefore still has one globally-coupled draw; full hermeticity folds into a
later NPC/cookie-creation migration. The pillage-specific draws (form, attack,
name) are fully isolated.

Like combat, this is **byte-neutral on the 206-file main manifest** (the bare-map
standard turn runs no pillage). It moved the pillage *reports* in the
`guard-pillage` tree (`save/1/300`, `save/1/301`) — a deliberate one-time
re-baseline of that subsystem's own golden tree; final faction state
(`fact/300`, `fact/301`) and the battle dice were unchanged.

Threading `struct rng_stream *` into a `proto.h` prototype required naming the
formerly-anonymous `rng_stream` struct tag (`lib/rng.h`) and forward-declaring
`struct rng_stream;` in `proto.h` (which `oly.h` includes before any TU pulls in
`rng.h`) — pointer-only, matching proto.h's existing private-struct forward-decl
convention.

### Aside: issue #4 is unreachable, not just uncovered

The combat migration was paired with an attempt to pin issue #4 (the guard-dedup
fix). It turned out the #4 branch is **unreachable** through the only caller:
`attack_guard_units` builds `l_a` with `add_allies = FALSE` (the pillager's
stack only), while guards are found via `loop_here(province)` (province-direct
only) — so a guard can never be both. An A/B build (fixed vs buggy #4) yields a
byte-identical battle report. The #4 fix is correct-on-principle hardening of
dead code; no black-box fixture can distinguish it. See
`tests/olympia/regress/guard-pillage/README.md`.

## Migration & re-baseline cost

- **Stageable, not a flag day.** Migrate one subsystem at a time. Each migration
  is its own deliberate, one-time golden re-baseline of *that subsystem's* tree
  (combat happened to be free — see above).
- Keep `rnd()` / `md5_int()` available until the last consumer is migrated.

## References

- `lib/rnd.c` — `rnd()` (:301), `md5_int()` (:319), `load_seed`/`save_seed`,
  global `digest[]` (:275).
- `olympia/io.c:2740` (load) / `olympia/io.c:2894` (save).
- `tests/olympia/golden/manifest.sha256` — the 206-file all-or-nothing manifest.
- `lib/rng.{c,h}`, `tests/rng/` — the seam and its self-check.
- `olympia/combat.c` — `begin_battle()`/`crnd()` (combat) and
  `begin_pillage()`/`prnd()` (pillage), the first two consumers;
  `olympia/npc.c` `create_peasant_mob()` (pillage name draw).
- `tests/olympia/regress/guard-pillage/` — the combat golden tree (and the
  #4-unreachability write-up).
- [agentic-project-ultron.md](agentic-project-ultron.md) — the coverage
  initiative this unblocks.
