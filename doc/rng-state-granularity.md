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

## The prototype seam — `lib/rng.{c,h}`

This change commits a small, **MD5-backed, intentionally unwired** layer that
codifies the recommended API:

```c
typedef struct { uint32_t seed[4]; uint32_t counter; } rng_stream;

rng_stream rng_seed(const uint32_t master[4]);
rng_stream rng_stream_of(const rng_stream *parent, int key, uint32_t tag);
int        rng_draw(rng_stream *s, int low, int high);                 /* sequential */
int        rng_keyed(const rng_stream *s, int k1, int k2, uint32_t tag,
                     int low, int high);                               /* keyed leaf */
```

Range reduction (mask + rejection) mirrors legacy `rnd()` exactly, so
distribution semantics are unchanged — only the *addressing* differs. Nothing
links against these symbols yet, so the golden manifest is byte-identical. The
standalone check `tests/rng/check.sh` asserts the three properties that make the
approach worth adopting: determinism, keyed independence (an inserted draw does
not move a sibling), and order-independent stream derivation.

## Migration & re-baseline cost

- **Stageable, not a flag day.** Migrate one subsystem at a time. Each migration
  is its own deliberate, one-time golden re-baseline of *that subsystem's* tree
  — which is the whole point: the blast radius is finally contained.
- **Combat is the natural first proving ground** — it ties back to #4 (the
  guard-path fix that still has no regression fixture) and currently has no
  coverage. A combat migration would let us add the focused fixture #4 needs.
- Keep `rnd()` / `md5_int()` available until the last consumer is migrated.

## References

- `lib/rnd.c` — `rnd()` (:301), `md5_int()` (:319), `load_seed`/`save_seed`,
  global `digest[]` (:275).
- `olympia/io.c:2740` (load) / `olympia/io.c:2894` (save).
- `tests/olympia/golden/manifest.sha256` — the 206-file all-or-nothing manifest.
- `lib/rng.{c,h}`, `tests/rng/` — the prototype seam and its self-check.
- #4 — combat guard fix; the output-neutral-only-because-uncovered example.
- [agentic-project-ultron.md](agentic-project-ultron.md) — the coverage
  initiative this unblocks.
