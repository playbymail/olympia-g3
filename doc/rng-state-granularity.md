# RNG-state granularity — survey & recommendation (issue #25)

Status: **in progress.** Groundwork for Project Ultron
([agentic-project-ultron.md](agentic-project-ultron.md)). The seam
(`lib/rng.{c,h}`) is wired into four subsystems so far — combat, pillage,
economy/market, and NPC spawning (see the consumer sections below); the
remaining subsystems in the [distribution map](#recommended-subsystem-distribution)
are still on the global `rnd()`.

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

**Known residual coupling (now cleared).** The mob's *troop count* draw lives in
the shared `do_cookie_npc()` (`npc.c`), which also backs undead / storm / savage
spawning — so it stayed on the global `rnd()` at the time of the pillage
migration. A pillage that *forms a mob* therefore still had one globally-coupled
draw. That residual was **absorbed by the NPC migration** (the fourth consumer,
below): `do_cookie_npc`'s troop count now draws from the per-location `npcs`
stream keyed on `(cookie, entity)`. The pillage-specific draws (form, attack,
name) were already fully isolated.

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

## Third consumer: economy/market seeding

The economy/market subsystem is the third migrated, and the **first that was
not byte-neutral** on the main manifest. It is a sibling of combat and pillage
under the same turn root, with its own tag:

```
turn seed
  ├─ (location, TAG_COMBAT)  → combat_rng   (battle resolution)
  ├─ (location, TAG_PILLAGE) → pillage_rng  (loot/mob draws)
  └─ (market,   TAG_ECONOMY) → economy_rng  (city trade seeding, market restock)
```

`begin_economy(where)` (`olympia/buy.c`) reseeds `economy_rng` per market, and
the market rolls use **keyed leaf draws** (`rng_keyed`) rather than the
sequential `rng_draw` combat/pillage used — the leaf key is `(item, where,
purpose)`, with `purpose` a 4-char tag (`pick`/`stok`/`qnty`/`cost`/`expr`)
exposed through small named helpers (`econ_pick`/`econ_stock`/`econ_qty`/
`econ_cost`/`econ_expire`). So an inserted draw between two market rolls cannot
move either, and the same `(item, where)` always yields the same value
regardless of how many other rolls preceded it. This generalizes the
already-keyed `md5_int()` buyer test the doc pointed at as the template.

Migrated draws: `seed_city_trade()` (`olympia/seed.c`, the staple/faery-good
choices and the riding-horse/hide/iron/lumber qty & cost), the per-turn
suffuse-ring restock (`trade_suffuse_ring`), and the FIND SELL/BUY trade-good
draws (`new_tradegood`, `d_find_sell`, `d_find_buy`).

**Deliberately left on the global `rnd()`** (not market-specific, the
`do_cookie_npc` precedent): the city *skill*-teaching and *prominence* seeding
(`seed_city_skill` / `choose_city_prominence`), the city *garrison* count
(`add_city_garrisons`), and the production/skill player commands in
`produce.c` (mining, harvest, mage-menial flavor). `buy.c`'s `md5_int()` buyer
test stays as-is: it is already a keyed leaf and is intentionally
turn-INDEPENDENT (the set of buyer cities must be stable across turns), so it
must *not* move onto the turn-keyed `economy_rng`.

### Why this one moved the manifest (combat/pillage did not)

Combat and pillage were byte-neutral because the bare-map standard turn has no
characters and never reached them. Economy/market seeding is different:
`seed_city_trade()` runs at **INIT** (`seed_initial_locations`, re-run during
the standard `./run/olympia-g3.sh` turn — verified via the `INIT:
seed_initial_locations()` stage) for every city across all four regions.
Removing those draws from the global serial stream realigns every global draw
that follows — so this migration required a **deliberate one-time re-baseline of
the 206-file main manifest** (it shrank to 204 files: the special-region entity
ids are minted on the still-global stream, so they shifted).

It also moved the **guard-pillage golden tree**, for a subtler reason worth
recording: the battle dice are keyed and unchanged, but `check-lua.sh` rebuilds
the scenario from the bare map via `olyscript-g3`, which re-runs INIT seeding and
**saves a different `randseed`** (economy draws no longer advance the global
stream during the build). That different saved seed becomes the next turn's
master seed, so the still-global mint/loot draws shift. The frozen `scenario.tgz`
(used by `check.sh`, `init=1` so it never re-seeds) was therefore stale; it was
regenerated with `build-scenario.sh` and `EXPECT.sha256` re-baselined so both the
C and Lua twins agree again. This coupling through the saved `randseed` → master
seed disappears once the `mint` subsystem (last in the map) is migrated.

## Fourth consumer: NPC spawning

NPC spawning is the fourth subsystem migrated, and the **second to move the main
manifest** (after economy). It is a sibling of the others under the turn root,
with its own tag, and — like economy — uses **keyed leaf draws**:

```
turn seed
  ├─ (location, TAG_COMBAT)  → combat_rng   (battle resolution)
  ├─ (location, TAG_PILLAGE) → pillage_rng  (loot/mob draws)
  ├─ (market,   TAG_ECONOMY) → economy_rng  (city trade seeding, market restock)
  └─ (location, TAG_NPC)     → npc_rng      (savage attacks, monster spawn qty, mob behavior)
```

`begin_npc(where)` (`olympia/npc.c`) reseeds `npc_rng` per location; the draws go
through small keyed helpers `npc_spawn` / `npc_qty` / `npc_behavior`
(`rng_keyed` on a `(k1, k2, purpose)` key, `purpose` a 4-char tag
`spwn`/`qnty`/`bhvr`), exposed through `proto.h` so `savage.c` can call them — the
same cross-file pattern as `begin_economy`/`econ_*`.

Migrated draws:

- **`init_savage_attacks`** (`savage.c`) — the per-fort `rnd(1,100)` savage-attack
  check, keyed on the fort. This is the one NPC draw the bare-map standard turn
  reaches (243 build-locs, once each, every turn via `queue_npc_orders`), so it
  is why this migration moved the main manifest.
- **`do_cookie_npc`** troop count (`npc.c`) — the mob/undead spawn quantity, keyed
  on `(cookie, entity)`. **This absorbs the pillage troop-count residual** (#44)
  and the same coupling for undead summoning. Storm cookies carry `man_kind == 0`
  and never reach the draw, so the later weather migration splits cleanly.
- **savage spawn/behavior** (`savage.c`) — `create_savage` stack quantity,
  `call_savage` / `auto_savage` wait-times.
- **autonomous NPC behavior** (`npc.c`) — `choose_npc_direction` (keep-direction),
  `auto_unsworn` (wander), `auto_mob` (disperse / wait).

**Why this one moved the manifest.** Like economy, an NPC draw fires on the
standard turn: `init_savage_attacks` draws once per build-loc every turn (243
draws on the bare map, none of which spawned a savage). Removing those from the
global serial stream realigns every global draw that follows, so this migration
took a **deliberate one-time re-baseline of the main manifest** (still 204 files;
only content shifted — the still-global entity-id mint draws moved). The other
migrated draws (`do_cookie_npc`, savage spawn, mob behavior) are unreached by the
bare-map turn and so were byte-neutral on the main manifest.

It also moved the **guard-pillage golden tree** (the pillage forms its mob via
`do_cookie_npc`, whose troop count is now keyed, and the turn also runs
`init_savage_attacks`): the pillage *reports* `save/1/{300,301}` shifted, while
`fact/{300,301}` and the battle dice were unchanged. Unlike economy, the frozen
`scenario.tgz` did **not** go stale — the migrated draws fire only during a turn
or cookie consumption, never during the `-s`/`-a`/`-i` world-init that
`build-scenario.sh` bakes, so the pre-turn saved `randseed` is unchanged. Both
`check.sh` and `check-lua.sh` produce identical post-turn hashes; only
`EXPECT.sha256` was re-baselined (no `scenario.tgz` regeneration).

**Deliberately left on the global `rnd()`** (documented residuals, the
`do_cookie_npc`/storm precedent):

- **Hades / faery bandits** (`npc.c` `create_hades_bandit` / `create_faery_bandit`
  / `hades_attack_check` / `faery_attack_check`) — region-environmental ambushes;
  they belong to the later `region:hades` / `region:faery` migration (tags
  `hads`/`faer`), not generic NPC infra. Byte-neutral now (unreached on the bare
  turn).
- **`storm.c`** environmental draws — the **weather** subsystem (tag `wthr`).
  `do_cookie_npc` passes storm cookies through without a troop-count draw, so
  there is no entanglement to unwind.
- **`hades.c`** `auto_hades` / `create_hades_nasty` — `region:hades`.
- **`swear.c`** social/loyalty rolls (bribe success, terrorize severity,
  persuade-oath, gift-thanks, incite-riot rumor/failure) and **`beast.c`**
  breeding-accident rolls — these are player-command social/skill draws, not NPC
  spawn/behavior. The one spawn coupling in `swear.c` (an incited mob is *created*
  via `do_cookie_npc`) already rides the migrated troop-count draw.

## Recommended subsystem distribution

The map below is the canonical target the remaining migrations work against. It
realizes the five-tier hierarchy from [Recommendation](#recommendation)
(`master → turn → subsystem → scenario → leaf`): the **root-level systems** are
the subsystem tier. Each gets a 4-char ASCII tag packed to `uint32` (like the
landed `TAG_TURN`/`TAG_COMBAT`/`TAG_PILLAGE`), is derived order-independently via
`rng_stream_of(turn, key, TAG)`, and migrates its hottest paths to keyed leaf
draws via `rng_keyed(stream, k1, k2, tag, lo, hi)` so an inserted draw between
two siblings cannot perturb either.

The tree is **sorted by recommended order of implementation** — top to bottom is
the order to migrate, chosen by blast-radius payoff (cheapest/highest-leverage
first; the byte-heaviest, most order-sensitive last).

```
master seed                                  rng_seed(randseed bytes)
└─ turn          key(master, turn#,  "turn") rng_stream_of  ← time tier
   │
   ├─ combat     key(turn, location, "comb")  [LANDED]   combat.c (begin_battle/crnd)
   │     └─ leaf key(round, attacker<<16|defender, "hit"/"dmg"/"morale"/"flee")
   │
   ├─ pillage    key(turn, location, "pill")  [LANDED]   combat.c (begin_pillage/prnd), npc.c
   │     └─ leaf key(0, 0, "form"/"name"/"attack")        troop-count residual absorbed by npc, below
   │
   ├─ economy    key(turn, market,   "econ")  [LANDED]   buy.c (begin_economy/econ_*), seed.c (seed_city_trade)
   │     └─ leaf key(item, where, "pick"/"stok"/"qnty"/"cost"/"expr")  ← keyed via rng_keyed
   │
   ├─ npc        key(turn, location, "npcs")  [LANDED]   npc.c (begin_npc/npc_*), savage.c
   │     └─ leaf key(cookie/fort, entity, "spwn"/"qnty"/"bhvr")  ← absorbed the pillage residual
   │             (hades/faery bandits -> region; swear/beast social -> residual on global)
   │
   ├─ weather    key(turn, location, "wthr")  [proposed] storm.c, day.c (environmental damage)
   │     └─ leaf key(where, 0, "storm"/"wreck"/"decay")
   │
   ├─ upkeep     key(turn, entity,   "upkp")  [proposed] day.c (healing, loyalty/structure decay, NPC orders)
   │     └─ leaf key(noble, 0, "heal"/"loyalty"/"sicken")
   │
   ├─ quest      key(turn, quest_id, "qest")  [proposed] quest.c
   │     └─ leaf key(stage, actor, "reward"/"branch"/"encounter")
   │
   ├─ explore    key(turn, actor,    "expl")  [proposed] tunnel.c, stealth.c
   │     └─ leaf key(where, dir, "find"/"detect"/"hide")
   │
   ├─ skills     key(turn, actor,    "skil")  [proposed] c1.c, c2.c, basic.c, use.c, alchem.c, art.c
   │     └─ leaf key(skill, target, "success"/"yield"/"crit")
   │
   ├─ magic      key(turn, actor,    "magc")  [proposed] scry.c, necro.c, relig.c
   │     └─ leaf key(spell, target, "scry"/"summon"/"piety")
   │
   ├─ worldgen   key(turn, location, "wgen")  [proposed] seed.c (region/sublocation/feature seeding)
   │     └─ leaf key(where, feature_id, "terrain"/"gate"/"resource")
   │
   ├─ region:faery  key(turn, location, "faer")  [proposed] faery.c
   ├─ region:hades  key(turn, location, "hads")  [proposed] hades.c
   ├─ region:cloud  key(turn, location, "clud")  [proposed] cloud.c
   │     └─ leaf key(where, entity, "encounter"/"reward"/"gate")
   │
   └─ mint       key(turn, new_id,   "mint")  [last]     z.c, pw.c (passwords / entity ids)
         └─ leaf key(entity, slot, "pw"/"id")             ← order-sensitive today; keyed fixes it
```

| Order | Root system | Tag | Scenario key | Status | Primary files |
|-------|-------------|-----|--------------|--------|---------------|
| 1 | combat | `comb` | location | **landed** | `combat.c` |
| 2 | pillage | `pill` | location | **landed** | `combat.c`, `npc.c` |
| 3 | economy | `econ` | market | **landed** | `buy.c`, `seed.c` |
| 4 | npc | `npcs` | location | **landed** | `npc.c`, `savage.c` |
| 5 | weather | `wthr` | location | proposed | `storm.c`, `day.c` |
| 6 | upkeep | `upkp` | entity | proposed | `day.c` |
| 7 | quest | `qest` | quest id | proposed | `quest.c` |
| 8 | explore | `expl` | actor | proposed | `tunnel.c`, `stealth.c` |
| 9 | skills | `skil` | actor | proposed | `c1.c`, `c2.c`, `basic.c`, `use.c`, `alchem.c`, `art.c` |
| 10 | magic | `magc` | actor | proposed | `scry.c`, `necro.c`, `relig.c` |
| 11 | worldgen | `wgen` | location | proposed | `seed.c` |
| 12 | regions | `faer`/`hads`/`clud` | location | proposed | `faery.c`, `hades.c`, `cloud.c` |
| 13 | mint | `mint` | entity id | last | `z.c`, `pw.c` |

### Why this order

- **economy was the cheapest first proposed migration** (now landed) —
  `buy.c:1442` already drew with `md5_int(...)`, the exact keyed-leaf model, so it
  was a clean template; the migrated draws use `rng_keyed` on a `(item, where,
  purpose)` key. Unlike combat/pillage it ran on the standard turn (`seed_city_trade`
  at INIT), so it took a one-time main-manifest re-baseline — see
  [Third consumer](#third-consumer-economymarket-seeding).
- **npc came next, deliberately** (now landed) — the pillage troop-count residual
  lived in the shared `do_cookie_npc()` (also backing undead/storm/savage
  spawning), so it belonged under `npc`, not `pillage`. Migrating this one stream
  cleared the residual *and* the same coupling at once; the region-flavored
  hades/faery bandit spawns and the `swear.c`/`beast.c` social rolls were left as
  documented residuals (region / social subsystems). Like economy it ran on the
  standard turn (`init_savage_attacks`), so it took a one-time main-manifest
  re-baseline — see [Fourth consumer](#fourth-consumer-npc-spawning).
- **weather/upkeep next** — `day.c` is a 28-draw hot spot split across
  environmental events (location-keyed) and per-noble upkeep (entity-keyed);
  splitting it removes a large slice of global coupling.
- **mint is last** — `z.c` password/id generation is *creation-order* sensitive
  today, so keying it on the minted entity id is what most directly enables small
  fixtures, but it touches the most golden bytes; stage it after everything else.
- Each step is **byte-neutral on the main manifest** wherever the bare-map
  standard turn does not exercise it (as combat and pillage were), otherwise a
  one-time re-baseline of just that subsystem's tree.

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
