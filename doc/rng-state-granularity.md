# RNG-state granularity — survey & recommendation (issue #25)

Status: **in progress.** Groundwork for Project Ultron
([agentic-project-ultron.md](agentic-project-ultron.md)). The seam
(`lib/rng.{c,h}`) is wired into ten subsystems so far — combat, pillage,
economy/market, NPC spawning, weather, upkeep, quest, explore, skills, and magic
(the last two **command core only** — the crafting/aura/alchemy draws and the
turn-auto curse-erode / autonomous-undead draws are deferred; see the consumer
sections below); the remaining subsystems in the
[distribution map](#recommended-subsystem-distribution) are still on the global
`rnd()`.

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

| # | Approach                                                                                                                                                                                           | Blast-radius win                                                                                       | Call-site churn                                 |
|---|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------|-------------------------------------------------|
| 1 | **Keyed / stateless draws** — replace order-dependent `rnd()` with draws keyed on stable inputs, `hash(entity, turn, purpose, sub_index)`. A draw no longer depends on how many draws preceded it. | **Largest** — true fix; reordering other code can't move a draw.                                       | **Largest** — every migrated call site changes. |
| 2 | **Per-subsystem / per-stream state** — keep `rnd()` stateful but split `digest` into named streams (combat, market, weather, …) seeded from master + a stream tag.                                 | Partial — reordering *within* a stream still perturbs it, but subsystem A no longer moves subsystem B. | Smaller — mostly threading a stream handle.     |
| 3 | **Per-entity / per-turn reseed checkpoints** — snapshot/reseed at well-defined boundaries (per noble, per location, per turn-phase).                                                               | Coarse — partitions the golden tree along those seams only.                                            | Smallest — no per-draw change.                  |

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

## Fifth consumer: weather

Weather is the fifth subsystem migrated, and the **largest manifest-mover** of
any consumer so far — it removes **~76,700 draws per turn** from the global serial
stream (vs npc's 243, economy's per-city handful). It is a sibling of the others
under the turn root, tag `"wthr"`:

```
turn seed
  ├─ (location, TAG_COMBAT)  → combat_rng   (battle resolution)
  ├─ (location, TAG_PILLAGE) → pillage_rng  (loot/mob draws)
  ├─ (market,   TAG_ECONOMY) → economy_rng  (city trade seeding, market restock)
  ├─ (location, TAG_NPC)     → npc_rng      (savage attacks, monster spawn qty, mob behavior)
  └─ (0,        TAG_WEATHER) → weather_rng  (storm generation, schedule, environmental damage)
```

### The structural divergence: one per-turn stream, seeded once

Unlike combat/npc/economy — which reseed a **fresh per-scenario** stream at each
chokepoint (`begin_battle(where)`, `begin_npc(where)`, `begin_economy(where)`) —
weather's reached draws are **Fisher-Yates province shuffles**
(`ilist_shuffle`), which are inherently *sequential* and span the **whole turn**:
the day-1 `weather_days` schedule shuffle, then the `natural_weather()` province
shuffles on each later weather-day. A shuffle cannot be expressed as a keyed leaf
draw (each swap's range depends on position), so the stream must carry a
**persistent counter** across the turn.

So `begin_weather()` (`olympia/storm.c`) is **turn-guarded** — it seeds
`weather_rng = master → turn → (0, TAG_WEATHER)` **once per turn** (scenario key
`0`, i.e. turn-global weather) and is a no-op on subsequent calls that turn. The
counter advances monotonically across all the shuffles. Cross-subsystem isolation
still holds (no non-weather draw moves); only *within* weather does draw order
matter — which is exactly the granularity #25 wants. This is documented as a
deliberate divergence in the `storm.c` header.

### Hybrid draw model

- **Sequential generation path (reached, ~76.7k draws/turn):** `wthr_shuffle()`
  (a thin wrapper over the new `ilist_shuffle_rng(ilist, struct rng_stream *)` in
  `lib/ilist.c`) for the `weather_days` schedule shuffle (`day.c`) and the
  `create_some_storms` province shuffles (`storm.c`); plus the per-province
  storm-strength roll `wthr_storm(province, day*256+kind, 2, 3)` — keyed on
  `(province, day, kind)` so a chosen province's aura is addressable independent
  of how the surrounding shuffle ordered the list.
- **Keyed acute path (UNREACHED on the bare-map turn, byte-neutral):**
  `wthr_wreck(where, sub, lo, hi)` (`rng_keyed`, purpose `"wrck"`) for ship
  coastal damage, mine calamities, and inn calamities (`day.c`), plus the
  death-fog flavor `wthr_storm()` (`storm.c` `fog_excuse`). `sub = day*16 + slot`
  disambiguates the several draws within one calamity and across days. These sit
  inside `n>0` / `sub_mine` / `sub_inn` branches the bare map never enters, so
  their keying is free design space for future Ultron fixtures.

The cross-file helpers (`begin_weather`, `wthr_shuffle`, `wthr_storm`,
`wthr_wreck`) live in `storm.c` and are exposed via `proto.h` so `day.c` can call
them — the same pattern as `begin_economy`/`econ_*` and `begin_npc`/`npc_*`. The
helpers self-seed via the turn-guarded `begin_weather()`, so a player
weather-spell command (`d_death_fog`) firing during the day's command loop —
before `daily_events()` reaches its first weather draw — cannot read an unseeded
stream.

### Why this one moved the manifest (and by how much)

`daily_events()` runs every day of the standard turn, and its weather path fires
heavily on the bare map: the `weather_days` schedule shuffle (29 draws, day 1),
**8** `create_some_storms` calls each shuffling a province list of ~7.5k–10k
(~70k draws), and **6608** `new_storm` strength rolls. Removing all of that from
the global serial stream realigns every global draw that follows, so this
migration took a **deliberate one-time re-baseline of the main manifest** (still
204 files; only content shifted — the still-global entity-id mint draws moved).

The **acute damage paths draw nothing on the bare map** (no rocky-coast ships, no
mines, no inns — their `rnd` lives inside branches never entered), so migrating
them is byte-neutral; they were migrated anyway for future fixture addressability.

It also moved the **guard-pillage golden tree** (its turn runs `daily_events`):
the pillage *reports* `save/1/{300,301}` shifted while `fact/{300,301}` and the
battle dice were unchanged — the same signature as the npc migration. As with npc,
the frozen `scenario.tgz` did **not** go stale (weather draws fire only during a
turn, never during the `-s`/`-a`/`-i` world-init `build-scenario.sh` bakes), so
both `check.sh` and `check-lua.sh` agree on the re-baselined `EXPECT.sha256` and
no `scenario.tgz` regeneration was needed.

**Reserved-but-unused: the `"decay"` purpose.** The distribution map proposed a
`"decay"` leaf for storm lifecycle. In fact `storm_decay()` / `storm_move()`
(`day.c` `post_month`) **draw nothing** — a storm's strength is a pure decrement
and its move uses a stored direction — so weather has no decay draw. The tag is
left documented for symmetry but wired to nothing.

**Deliberately left on the global `rnd()`** (documented residuals): the
`daily_events` day-picks `curse_erode_day` (magic), `faery_day` (region:faery,
step 12), `dog_bark_day` (detection/stealth); the **upkeep** routines
(`heal_char_sup`, `loyalty_decay`, `men_starve`, `animal_deaths`, `corpse_decay`
— step 6, `"upkp"`); `inn_income` (per-structure income → economy/upkeep); and the
`post_month` gradual decays (link/relic/pillage/hide_mage/ghost_warrior/
dead_body_rot/collapsed_mine). Storm *summoning* via `do_cookie_npc` already
passes through without a draw (storm cookies carry `man_kind == 0`), so there was
no entanglement to unwind.

## Sixth consumer: upkeep

Upkeep — the per-noble gradual-maintenance half of `day.c` — is the sixth
subsystem migrated, and the **first since combat/pillage to be byte-neutral on
*both* golden trees**. It is a sibling of the others under the turn root, tag
`"upkp"`:

```
turn seed
  ├─ (location, TAG_COMBAT)  → combat_rng   (battle resolution)
  ├─ (location, TAG_PILLAGE) → pillage_rng  (loot/mob draws)
  ├─ (market,   TAG_ECONOMY) → economy_rng  (city trade seeding, market restock)
  ├─ (location, TAG_NPC)     → npc_rng      (savage attacks, monster spawn qty, mob behavior)
  ├─ (0,        TAG_WEATHER) → weather_rng  (storm generation, schedule, environmental damage)
  └─ (0,        TAG_UPKEEP)  → upkeep_rng   (healing, loyalty/starvation, animal/corpse decay)
```

### One per-turn stream, all keyed leaves

Like weather (its sibling in `day.c`), upkeep uses **one per-turn stream seeded
once** — `begin_upkeep()` (`olympia/day.c`) is turn-guarded, scenario key `0` —
rather than the fresh per-scenario reseed of combat/npc/economy. The reason is
different from weather's, though: weather needs a persistent counter because its
reached draws are *sequential* shuffles; upkeep's draws are all **keyed leaves**
(`rng_keyed`, which never advances the counter), so the single stream is
effectively stateless and draw order within upkeep is irrelevant. The choice is
forced by *placement*, not sequencing: the upkeep draws are scattered across
several `loop_char` passes in `post_month()`/`daily_events()` with **no single
per-entity chokepoint**, so a per-entity `begin_upkeep(who)` reseed would mean
threading a seed call into every loop body. Carrying the entity in the **leaf
key** instead gives identical per-`(entity, purpose)` addressability for free.
This is a deliberate refinement of the map's literal "scenario key = entity"
(the entity lands in the leaf `k1` rather than the scenario seed), the same way
weather refined "per-scenario reseed" into "one per-turn stream".

The helpers are **static in `day.c`** — no `proto.h` exposure — because every
draw site is in this file. The one cross-file entry point (`garr.c`'s
`garrison_gold()` → `charge_maint_sup()` → `men_starve()`) reaches the draw
*inside* `men_starve()`, which lives here; the turn-guarded `begin_upkeep()` means
whichever upkeep routine fires first that turn seeds the stream.

Migrated draws (all keyed leaves via small named helpers, purpose a 4-char tag):

- **`heal_char_sup`** (`up_heal`, `"heal"`) — the sick-recovery check `rnd(1,100)`
  (sub 0) and the heal/lose amount `rnd(3,15)` (sub 1), keyed on the char.
- **`loyalty_decay`** (`up_loyal`, `"loyl"`) — the contract-desertion (sub 0) and
  fear-desertion (sub 1) `rnd(1,2)` checks, keyed on the char.
- **`men_starve`** (`up_starve`, `"sckn"`) — the left-service-vs-deserted flavor
  `rnd(1,2)`, keyed on `(char, item type)`. Reached via `charge_maint_costs` and
  `garr.c`'s `garrison_gold`.
- **`animal_deaths`** (`up_animal`, `"dier"`) — the per-individual death Bernoulli
  `rnd(1,1000)`, keyed on `(char, animal index)` with the item type folded into
  the purpose tag so each `(char, item)` pair gets an independent per-individual
  sequence (overflow-free for any herd size).
- **`corpse_decay`** (`up_corpse`, `"corp"`) — the `rnd(0,2)` decomposition count,
  keyed on the char.

### Why this one is byte-neutral on both trees (the inverse of weather)

Unlike economy/npc/weather (each fires on the standard turn), **every upkeep
draw is unreached on both golden trees** — measured empirically (instrument each
site, build, count, revert):

- **Bare-map standard turn: 0 upkeep draws.** No player characters
  (`charge_maint_costs`/`animal_deaths` filter `sub_pl_regular`; `loop_char` heal
  finds none wounded), no inns, no corpses.
- **guard-pillage turn: also 0 upkeep draws** — which corrected a prior
  expectation that its 70 soldiers would exercise upkeep. State diagnostics show
  why: **soldiers are inventory items, not chars**, so only the two commanders
  reach `charge_maint_sup` (one `cost=71, have=450` affords it; the other
  `cost=0`), no char is `LOY_contract`/`LOY_fear`/`LOY_summon` (the 462 NPCs are
  `LOY_npc`, the 2 nobles `LOY_oath` — all skipped), no noble is wounded into
  0–99 health on a `day%7` heal tick, and there are no animals/corpses/inns.

So the migration is **byte-neutral on both manifests** (the combat/pillage
profile, not weather's): no re-baseline of the main manifest *or* the
guard-pillage tree, and `scenario.tgz` is untouched (upkeep fires only during a
turn). Its value is purely future Ultron-fixture addressability.

**Deliberately left on the global `rnd()`** (documented residuals): `inn_income`
(per-structure income — deferred to a future income subsystem, not per-noble
upkeep) and the `daily_events` day-picks (`curse_erode`/`faery`/`dog_bark`).
`temple_income` and the `post_month` gradual decays
(`relic`/`pillage`/`hide_mage`/`ghost_warrior`/`dead_body_rot`/
`collapsed_mine`/`link`/`quest`/`storm_decay`/`storm_move`) draw **no `rnd()`**
at all — nothing to migrate.

## Seventh consumer: quest

Quest — the QUEST player command and its sublocation guardian/loot generation —
is the seventh subsystem migrated, tag `"qest"`. It is a sibling of the others
under the turn root:

```
turn seed
  ├─ (location, TAG_COMBAT)  → combat_rng   (battle resolution)
  ├─ (location, TAG_PILLAGE) → pillage_rng  (loot/mob draws)
  ├─ (market,   TAG_ECONOMY) → economy_rng  (city trade seeding, market restock)
  ├─ (location, TAG_NPC)     → npc_rng      (savage attacks, monster spawn qty, mob behavior)
  ├─ (0,        TAG_WEATHER) → weather_rng  (storm generation, schedule, environmental damage)
  ├─ (0,        TAG_UPKEEP)  → upkeep_rng   (healing, loyalty/starvation, animal/corpse decay)
  └─ (where|who,TAG_QUEST)   → quest_rng    (quest monster/loot generation; skull relic use)
```

### Fresh per-scenario sequential stream (the combat model)

Unlike weather/upkeep (one turn-guarded per-turn stream), quest reseeds a
**fresh per-scenario** stream at its chokepoint — the `begin_battle()` model,
not the `begin_weather()` one — because the quest path is an **ordered run of
draws building one outcome**: the QUEST command picks a monster, rolls its
troops, picks a treasure class, then assembles gold / a relic / an artifact
(kind + bonus + a name from a prefix-or-`of`-name template) / a teach-book / a
pegasus, and finally hands off to the (already-keyed) combat stream via
`attack`. That whole chain is sequential, so `begin_quest(key)` seeds the stream
and the ~20 draws go through `qrnd()` (`rng_draw`), exactly as combat's
`begin_battle()`/`crnd()`. A change to an unrelated subsystem can't perturb a
quest result, and within quest the draw order is what #25 wants to preserve.

There is **no first-class quest entity**, so the scenario key is the natural
context of each of the **two** entry points (reconciling the map's nominal
"quest_id"):

- **`d_quest`** (the QUEST command, `glob.c` priority 7) — `begin_quest(where)`,
  keyed on the sublocation being quested in. Seeded after the early-outs (safe
  haven / not stack leader / no quests here / recently quested all return before
  any draw), so an invalid quest never seeds. Drives the whole generation chain
  (`make_subloc_monster` → `new_monster`/`choose_quest_monster`,
  `random_unassigned_relic`, `new_artifact`, `make_teach_book`).
- **`v_use_bta_skull`** (USE the Skull of Bastrestric, `use.c`) —
  `begin_quest(c->who)`, keyed on the actor; its two draws (the death/survive
  check and the aura granted to a surviving magician) go through `qrnd()`.

`make_teach_book`'s skill-scramble — formerly `ilist_scramble()` on the global
`rnd()` — now shuffles via `ilist_shuffle_rng(list, &quest_rng)` (the same
stream-taking Fisher-Yates the weather migration added to `lib/ilist.c`), so it
rides the quest stream like every other quest draw. `begin_quest`/`qrnd` are
exposed via `proto.h` (the `begin_economy`/`begin_npc`/`begin_weather`
convention); `quest_rng` stays file-static in `quest.c`.

### Why this one is byte-neutral on both trees (the upkeep profile)

Like upkeep, **every quest draw is unreached on both golden trees** — measured
empirically (instrument each entry point, build, count, revert):

- **Bare-map standard turn: 0 quest draws.** No player characters, so no QUEST
  or USE command is ever issued.
- **guard-pillage turn: 0 quest draws.** Its factions issue `pillage`/`guard`,
  never `quest`/`use`.
- **World-init (`-s`/`-a`/`-i`): 0 quest draws.** The only quest call at
  world-init is `create_relics()` (`io.c`), which mints three fixed relics and
  **draws no `rnd()`** — confirmed by counting it firing (twice, at INIT) while
  emitting zero draws. So the frozen `scenario.tgz` is **not** stale.

So the migration is **byte-neutral on both manifests** (combat/pillage/upkeep
profile, not the economy/npc/weather one): no re-baseline of the main manifest
*or* the guard-pillage tree, and `scenario.tgz` is untouched. Its value is
purely future Ultron-fixture addressability (a quest fixture can now be
re-baselined in isolation).

**Deliberately left on the global `rnd()`** (shared infra, other subsystems'
draws reached indirectly on the quest path): `new_char` / `gen_item` /
`create_unique_item(_alloc)` / `new_orb` / `create_npc_token` / `kill_char` —
item/character/mint primitives migrated under their own tracks (the
`do_cookie_npc` precedent). The post-month `quest_decay()` (`day.c`) draws **no
`rnd()`** at all (a pure `quest_late` decrement loop) — nothing to migrate.

## Eighth consumer: explore

Explore — the EXPLORE player command and the SEEK detect rolls — is the eighth
subsystem migrated, tag `"expl"`. It is a sibling of the others under the turn
root:

```
turn seed
  ├─ (location, TAG_COMBAT)  → combat_rng   (battle resolution)
  ├─ (location, TAG_PILLAGE) → pillage_rng  (loot/mob draws)
  ├─ (market,   TAG_ECONOMY) → economy_rng  (city trade seeding, market restock)
  ├─ (location, TAG_NPC)     → npc_rng      (savage attacks, monster spawn qty, mob behavior)
  ├─ (0,        TAG_WEATHER) → weather_rng  (storm generation, schedule, environmental damage)
  ├─ (0,        TAG_UPKEEP)  → upkeep_rng   (healing, loyalty/starvation, animal/corpse decay)
  ├─ (where|who,TAG_QUEST)   → quest_rng    (quest monster/loot generation; skull relic use)
  └─ (0,        TAG_EXPLORE) → explore_rng  (explore find/detect rolls; actor in the leaf key)
```

### One per-turn stream, keyed leaves (the upkeep model)

Like upkeep, explore uses **one per-turn stream seeded once** — `begin_explore()`
(`olympia/c1.c`) is turn-guarded, scenario key `0` — with all draws being
**keyed leaves** (`rng_keyed`, which never advances a counter). This is *not*
the map's literal "scenario key = actor": the draws are scattered across several
independent player commands in **two files** (`c1.c`, `stealth.c`) with no single
per-actor chokepoint, and one actor may issue EXPLORE *and* SEEK in the same turn
— so a per-command `begin_explore(who)` sequential reseed on `(turn, actor)` would
collide across commands. Carrying the actor in the **leaf key** (`k1 = who`)
instead of the scenario seed gives identical per-`(actor, context)`
addressability for free and is collision-free across commands. This is the same
refinement upkeep made (entity in the leaf key, one per-turn stream), forced by
placement rather than sequencing.

Migrated draws (all keyed leaves via small named helpers, purpose a 4-char tag):

- **`find_lost_items`** (`expl_find`, `"find"`) — the unique-item recovery check
  `rnd(1,100)`, keyed on `(who, where)`. (Called twice on the EXPLORE path — once
  for the build loc, once for the surrounding ocean on a ship — distinguished by
  the `where` key.)
- **`d_explore`** — the success gate `rnd(1,100)` (`expl_gate`, `"gate"`), the
  "something is hidden here" flavor `rnd(1,4)` (`expl_flavor`, `"flav"`), and the
  hidden-exit choice `rnd(1,hidden_exits)` (`expl_pick`, `"pick"`), all keyed on
  `(who, where)`.
- **`d_seek`** (`stealth.c`) — the targeted detect roll `rnd(1,10)` (`expl_seek`,
  `"seek"`, keyed on `(who, target)`) and the per-candidate hidden-noble scan
  `rnd(1,100)` (`expl_detect`, `"dtct"`, keyed on `(who, candidate)`).

`begin_explore()` and the `c1.c`-local helpers are static; only `expl_seek` /
`expl_detect` are exposed via `proto.h` so `stealth.c`'s `d_seek` draws from the
same stream (the `begin_economy`/`econ_*` cross-file convention). The helpers
self-seed via the turn-guarded `begin_explore()`, so whichever explore/detect
draw fires first that turn seeds the stream.

### Why this one is byte-neutral on both trees (the quest/upkeep profile)

Like quest and upkeep, **every explore draw is unreached on both golden trees** —
measured empirically (instrument each site, build, run, count, revert):

- **Bare-map standard turn: 0 explore draws.** No player characters, so no
  EXPLORE or SEEK command is ever issued.
- **guard-pillage turn (both `check.sh` and `check-lua.sh`): 0 explore draws.**
  Its factions issue `pillage`/`guard`, never `explore`/`seek`.
- **World-init (`-s`/`-a`/`-i`): 0 explore draws.** None of the migrated draws
  fire at world-init.

So the migration is **byte-neutral on both manifests** (the quest/upkeep
profile): no re-baseline of the main manifest *or* the guard-pillage tree, and
`scenario.tgz` is untouched. Its value is purely future Ultron-fixture
addressability.

### The boundary: explore-command vs stealth-skill vs worldgen

The map's `explore` row nominally lists `tunnel.c, stealth.c`, but the actual
EXPLORE command lives in `c1.c` (`d_explore`/`find_lost_items`), and the file
list conflates three distinct reachability profiles. The boundary was drawn as:

- **Migrated now (`expl`):** the genuine explore/detect rolls — `c1.c`
  `find_lost_items`/`d_explore` and `stealth.c` `d_seek` — matching the map's
  literal `"find"`/`"detect"` leaf names.
- **Deferred to worldgen (step 11, `"wgen"`):** `tunnel.c` dungeon/subworld
  generation. These are **pure world-gen** draws that fire at INIT (`create_tunnels`
  ← `io.c`, init-guarded `if (tunnel_region == 0)`), have **no actor** (explore
  keys on the actor; a dungeon keys on `(where, feature)` — exactly worldgen's
  proposed leaf), and are the **single largest draw set in the engine: ~409,727
  `rnd()` calls per fresh world build** (≈5× weather). `tunnel.c` sits in the same
  `io.c` world-init block as `create_faery`/`create_hades`, which the map already
  defers to regions (step 12) — direct precedent. Migrating it would force a
  main-manifest re-baseline **plus** a `scenario.tgz` regeneration +
  `EXPECT.sha256` re-baseline (it fires inside `build-scenario.sh`/`check-lua.sh`
  world-init — the economy precedent) for **zero** command-fixture benefit.
- **Deferred to skills (step 9, `"skil"`):** `stealth.c` TORTURE and PETTY THIEF.
  Both are **skill commands** (`sk_torture`, `sk_petty_thief` registered in
  `use.c`), so they belong with the skills subsystem keyed on the actor, not with
  explore. **These have now landed** under the skills migration (the ninth
  consumer, below) — they draw from the per-turn `skills_rng` (tag `skil`) via
  `skil_torture`/`skil_petty`. `d_explore`/`find_lost_items` in `c1.c` (nominally
  a "skills" file) stay on `expl` as a documented cross-reference (the
  npc→`swear.c`/`beast.c` split precedent).

**Draw nothing / dead code (nothing to migrate):** `d_hide`, `d_sneak`, and the
`spy_*` commands draw no `rnd()`; the map's `"hide"` leaf has no draw.
`equip_new_noble` (`c1.c`) is inside `#if 0` — never compiled.

## Ninth consumer: skills (command core)

Skills is the ninth subsystem migrated, tag `"skil"`, and — unlike every
consumer before it — it is a **deliberate partial**. Only the unambiguous,
mundane, command-only skill draws land here; everything that straddles magic,
alchemy, or artifact crafting is **explicitly deferred** to the magic step (10)
and a crafting follow-up, so a small, byte-neutral slice lands cleanly while the
murky magic boundary is settled separately. It is a sibling of the others under
the turn root:

```
turn seed
  ├─ … (combat … explore)
  └─ (0,        TAG_SKILLS)  → skills_rng   (weapon training, study/research, torture/petty)
```

### One per-turn stream, keyed leaves (the explore/upkeep model)

Like explore and upkeep, skills uses **one per-turn stream seeded once** —
`begin_skills()` (`olympia/use.c`) is turn-guarded, scenario key `0` — with all
draws being **keyed leaves** (`rng_keyed`, which never advances a counter). The
**actor goes in the leaf key `k1`**, not the map's literal "scenario key =
actor": the draws are scattered across several independent skill commands in
**three files** (`c2.c`, `use.c`, `stealth.c`) with no single per-actor
chokepoint, and one actor may issue several skill commands in a turn. Carrying
the actor in the leaf key gives identical per-`(actor, context)` addressability
for free and is collision-free across commands — the explore precedent. The
stream + `begin_skills()` + the helpers live in `use.c` (the skill-command hub,
`use_tbl`); `begin_skills` and the `use.c`-local helpers
(`skil_study`/`skil_research`/`skil_research_pick`) are static, while
`skil_crit`/`skil_bonus` (for `c2.c`) and `skil_torture`/`skil_petty` (for
`stealth.c`) are exposed via `proto.h` (the `begin_economy`/`expl_seek`
cross-file convention).

Migrated draws (all keyed leaves via small named helpers, purpose a 4-char tag):

- **weapon training** (`c2.c` `d_archery`/`d_defense`/`d_swordplay`) — the 5%
  crit gate `rnd(1,100)` (`skil_crit`, `"crit"`) and the rating bonus
  `rnd(3,5)`/`rnd(1,3)` (`skil_bonus`, `"yiel"`), keyed on `(who, weapon skill)`
  (`sk_archery`/`sk_defense`/`sk_swordplay`) — matching the map's `crit`/`yield`
  leaf names.
- **STUDY** (`use.c` `v_study`) — the 1-in-4 scroll/book consume check `rnd(1,4)`
  (`skil_study`, `"stdy"`), keyed on `(who, skill)`. The two mutually-exclusive
  code paths (fast-study vs normal) share the key — only one fires per command.
- **RESEARCH** (`use.c` `d_research`/`research_notknown`) — the success gate
  `rnd(1,100)` (`skil_research`, `"rsch"`) and the unknown-skill pick
  `rnd(0,len-1)` (`skil_research_pick`, `"rpik"`), keyed on `(who, skill)`. The
  pick is keyed (not sequential), so its firing in both `v_research` (validation)
  and `d_research` (execution) now yields the same skill instead of two
  independent global draws.
- **TORTURE** (`stealth.c` `d_torture`, inherited from explore step 8) — the
  prisoner talk-chance `rnd(1,100)` (`skil_torture`, `"tort"`), keyed on
  `(who, target)`.
- **PETTY THIEF** (`stealth.c` `d_petty_thief`, inherited from explore step 8) —
  the command's ~8-draw run (caught check, beating/report/rumor flavor, damage,
  amount stolen) via a single generic `skil_petty(who, where, sub, lo, hi)`
  (`"ptty"`), keyed on `(who, where)` with a per-site `sub` folded into the leaf
  key (`where*16 + sub`) — the weather `day*16+slot` / upkeep animal-index
  precedent. The report sub-cases recur in two mutually-exclusive branches, so a
  shared `sub` never double-draws within one invocation.

### Why this one is byte-neutral on both trees (the quest/explore profile)

Like quest and explore, **every skill-command draw is unreached on both golden
trees** — measured empirically (instrument each command handler, build, run,
count, revert):

- **Bare-map standard turn: 0 skill draws.** No player characters, so no skill
  command is ever issued.
- **guard-pillage turn (both `check.sh` and `check-lua.sh`): 0 skill draws.** Its
  factions issue `pillage`/`guard`, never a skill command.
- **World-init (`-s`/`-a`/`-i`): 0 skill draws.** None of these fire at
  world-init (the Lua world-build, the byte-equivalent of `-s`/`-a`/`-i`, also
  draws zero).

So the migration is **byte-neutral on both manifests** (the quest/upkeep/explore
profile): no re-baseline of the main manifest *or* the guard-pillage tree, and
`scenario.tgz` is untouched. Its value is purely future Ultron-fixture
addressability.

### Explicitly deferred (named residuals — the partial boundary)

This slice **stops at the magic boundary**. Each deferred group straddles a
not-yet-migrated subsystem and stays on the global `rnd()`:

- **`basic.c` meditation/aura + heal** — `d_meditate`, `d_adv_med`,
  `hinder_med_omen`, and `d_heal` are **aura/spell draws** (they
  `charge_aura()`, scale on aura level, print "casts Heal"); deferred to **magic**
  (step 10). **Now landed** under magic (the tenth consumer, below) — they draw
  from the per-turn `magic_rng` (tag `magc`) via `magc_med`/`magc_omen`/`magc_heal`.
- **`alchem.c`** — `new_potion`, `v_use_heal`, `v_use_slave` (potion brew/use) —
  alchemy/magic-adjacent; deferred to **magic**. **Now landed** under magic via
  `magc_potion`.
- **`art.c`** — `d_forge_aura`, `new_orb`/`v_use_orb`, `create_npc_token`,
  `new_suffuse_ring`/`v_suffuse_ring` (artifact/magic-item crafting) — deferred to
  a **follow-up after magic** because it has three overlaps to settle first: (i)
  `new_orb`/`create_npc_token` are quest-left shared-infra residuals; (ii) suffuse
  rings overlap economy (`trade_suffuse_ring`); (iii) a **world-init mint risk**
  (orbs/tokens/rings may be minted during `-s`/`-a`/`-i`, which would flip this to
  the expensive economy profile with a `scenario.tgz` regen). **Now partly landed**
  under magic (the crafting follow-up below): the three **command-path** draws
  (`d_forge_aura` kind+weight, `v_use_orb`, `v_suffuse_ring`) draw from `magc` via
  `magc_forge`/`magc_orb`/`magc_ring`; the three **shared-infra minters** stay
  deferred (i = quest, ii = economy). The empirical world-init check came back **0
  art.c draws** at `-s`/`-a`/`-i` — overlap (iii) did not materialize.
- **`produce.c`** mining/harvest/mage-menial — left global by the economy
  migration; an **economy** residual.

`d_hide`/`d_sneak`/`spy_*` draw nothing; `equip_new_noble` (`c1.c`) is `#if 0`
dead code — nothing to migrate either way.

## Tenth consumer: magic (command core)

Magic is the tenth subsystem migrated, tag `"magc"`, and — like skills before it
— it is a **deliberate partial**. Only the unambiguous, player-cast spell draws
land here: scrying, religion gates, necromancy eat-dead/skill-transfer, the
meditation/aura + heal spells, and the alchemy potion brew/use draws (the last
two **inherited from the skills step-9 deferral**). The turn-auto curse-erode
day-pick and the autonomous-undead draw are **explicitly deferred** so a small,
byte-neutral slice lands cleanly. It is a sibling of the others under the turn
root:

```
turn seed
  ├─ … (combat … skills)
  └─ (0,        TAG_MAGIC)   → magic_rng    (scry/piety/necro/meditation/alchemy spell + art.c crafting draws)
```

### One per-turn stream, keyed leaves (the explore/skills model)

Like explore and skills, magic uses **one per-turn stream seeded once** —
`begin_magic()` (`olympia/basic.c`) is turn-guarded, scenario key `0` — with all
draws being **keyed leaves** (`rng_keyed`, which never advances a counter). The
**actor goes in the leaf key `k1`**, not the map's literal "scenario key =
actor": the draws are scattered across **six files** (`scry.c`, `relig.c`,
`necro.c`, `basic.c`, `alchem.c`, `art.c` — the last added by the crafting
follow-up below) with no single per-actor chokepoint, and one actor may cast
several spells in a turn. Carrying the actor in the leaf key gives
identical per-`(actor, context)` addressability for free and is collision-free
across spells — the explore/skills precedent. The stream + `begin_magic()` + the
helpers live in `basic.c` (the core-spell file); `begin_magic` and the basic.c
meditation/heal helpers (`magc_med`/`magc_omen`/`magc_heal`) are static, while
`magc_scry`/`magc_piety`/`magc_eat`/`magc_learn`/`magc_potion` plus the crafting
helpers `magc_forge`/`magc_orb`/`magc_ring` are exposed
through `proto.h` so the other five files draw from the same stream (the
`begin_economy`/`skil_crit` cross-file convention).

Migrated draws (all keyed leaves via small named helpers, purpose a 4-char tag):

- **scrying** (`scry.c` `d_locate_char`/`d_unbar_loc`) — the success gate
  `rnd(1,100)` (`magc_scry`, `"scry"`), keyed on `(who, target|where)`.
- **religion** (`relig.c` `d_reveal_vision`/`d_resurrect`/`d_remove_bless`) — the
  piety gate `rnd(1,100)` (`magc_piety`, `"piet"`), keyed on `(who, c->a)` (the
  vision target / resurrected body / blessing target).
- **necromancy eat-dead** (`necro.c` `d_eat_dead`) — the 33% destroy and 25% sick
  gates (`magc_eat`, `"eatd"`), keyed on `(who, body)` with the sub folded into
  the leaf key (`body*2 + sub`) so each is an independent keyed leaf (the skills
  `petty` / weather `day*16+slot` precedent).
- **necromancy skill transfer** (`necro.c` `get_some_skills`, reached only from
  `d_eat_dead`) — the per-skill transfer check `rnd(1,100)` (`magc_learn`,
  `"lern"`), keyed on `(who, skill)`. The two disjoint loops (category vs subskill)
  key on the distinct skill ids, so the keying is collision-free across them.
- **meditation/aura** (`basic.c` `d_meditate`/`d_adv_med` + `hinder_med_omen`) —
  the hinder gate `rnd(1,100)` (`magc_med`, `"medi"`, keyed on `(who, sub)` to
  separate the two commands) and the omen flavor `switch(rnd(1,4))` (`magc_omen`,
  `"omen"`, keyed on `(who, other)`).
- **heal** (`basic.c` `d_heal`) — the Heal-spell success gate `rnd(1,100)`
  (`magc_heal`, `"heal"`), keyed on `(who, target)`.
- **alchemy** (`alchem.c` `new_potion`/`v_use_heal`/`v_use_slave`) — the potion
  kind `switch(rnd(1,2))`, the heal amount `rnd(0,3)`, and the slave-potion gate
  `rnd(1,100)<=33`, all via a single generic `magc_potion(who, sub, lo, hi)`
  (`"potn"`), keyed on `(who, sub)` with the differing range passed in.
  `new_potion` is reached from the BREW commands and the `d_save_*` quick-cast
  saves — all command-path.

### Why this one is byte-neutral on both trees (the quest/explore/skills profile)

Like quest, explore, and skills, **every magic-spell draw is unreached on both
golden trees** — measured empirically (instrument each of the 16 in-scope sites,
build, run, count, revert):

- **Bare-map standard turn (incl. its `-i` world-init): 0 magic draws.** No player
  characters, so no spell / USE / BREW command is ever issued.
- **guard-pillage turn (both `check.sh` and `check-lua.sh`): 0 magic draws.** Its
  factions issue `pillage`/`guard`, never a magic command.
- **World-init (`-s`/`-a`/`-i`, via `build-scenario.sh`): 0 magic draws.** None of
  the migrated draws fire at world-init.

So the migration is **byte-neutral on both manifests** (the quest/upkeep/explore/
skills profile): no re-baseline of the main manifest *or* the guard-pillage tree,
and `scenario.tgz` is untouched. Its value is purely future Ultron-fixture
addressability.

### Explicitly deferred (named residuals — the partial boundary)

This slice **stops at the command/auto boundary**. Each deferred group would move
a manifest or belongs to another subsystem, and stays on the global `rnd()`:

- **`day.c` `curse_erode_day`** (`daily_events`) — a turn-auto day-pick
  (`rnd(1,MONTH_DAYS)`) fired **every turn**; migrating it would move the **main
  manifest** (the economy/weather profile), breaking the byte-neutral goal. Left
  global as a deliberate decision (`noncreator_curse_erode()` itself draws nothing,
  so only the day-pick is at issue).
- **`necro.c` `auto_undead`** (`rnd(1,2)`) — autonomous summoned-undead behavior,
  reached only from `npc.c`'s auto-behavior dispatch (`auto_*` family), **not a
  player spell**; an NPC autonomous-behavior residual.
- **necro undead summoning troop-count** — already on the `npcs` stream via
  `do_cookie_npc` (the npc migration); not touched here.
- **`art.c`** — artifact/orb/ring crafting; the **command-path** draws landed
  here (see the crafting follow-up below), but the three shared-infra **minters**
  stay deferred: `new_orb`/`create_npc_token` (quest loot) and `new_suffuse_ring`
  (economy per-turn restock).
- **`cloud.c`** (4 draws) — `region:cloud` (step 12).

### Crafting follow-up: art.c command draws (still on magc)

The artifact-crafting overlaps the magic step flagged are now **settled**. The
three **player-command** crafting draws in `art.c` reuse the **same `magc`
stream** (no new stream or tag) via three cross-file helpers in `basic.c`,
declared in `proto.h` — the `magc_scry`/`magc_piety` convention:

- **`d_forge_aura`** (FORGE AURACULUM, `sk_forge_aura` skill completion) — the
  unnamed-ring kind `switch(rnd(1,3))` and the auraculum weight `rnd(1,3)`, both
  via `magc_forge(who, sub)` (`"forg"`), keyed on `(who, sub)` with `sub` 0=kind,
  1=weight (the `magc_eat` sub-key precedent).
- **`v_use_orb`** (USE orb) — the 1-in-3 murky-image failure gate
  (`magc_orb(who)`, `"orb "`), keyed on `(who)`.
- **`v_suffuse_ring`** (USE suffuse-ring) — the 1-in-3 fizzle gate
  (`magc_ring(who)`, `"ring"`), keyed on `(who)`.

**Byte-neutral on both trees** (the quest/explore/skills profile), verified
empirically by instrumenting all seven live `art.c` `rnd()` sites:

- The **three command draws are 0 everywhere** — bare-map turn, both
  guard-pillage twins (`check.sh` + `check-lua.sh`), and `-s`/`-a`/`-i`
  world-init. No re-baseline, no `scenario.tgz` regen. The **world-init mint
  risk did not materialize** (0 art.c draws at `-s`/`-a`/`-i`).
- **Deferred minters stay global**, by design:
  - `new_orb` (`rnd(1,4)*2+1` orb_use_count) and `create_npc_token`
    (`switch(rnd(1,5))`) are reached **only** from `quest.c` loot generation —
    **quest** shared-infra residuals (the quest step already left them global).
  - `new_suffuse_ring` (`switch(rnd(1,5))`) is reached from `buy.c`
    `trade_suffuse_ring`, the **per-turn economy restock** — it fires ~22–42×
    on the standard turn (measured), so migrating it **would move the main
    manifest**. An **economy** residual.
  - `add_token_unit_sup`'s `gen_item(..., rnd(3,15))` is **dead code** (`#if 0`);
    nothing to migrate.

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
   ├─ weather    key(turn, 0,        "wthr")  [LANDED]   storm.c (begin_weather/wthr_*), day.c (environmental damage)
   │     └─ seq  shuffle+aura (generation); leaf key(where, day*16+slot, "wrck") (acute, unreached)
   │             one per-turn stream, seeded once; "decy" reserved/unused (storm_decay draws nothing)
   │
   ├─ upkeep     key(turn, 0,        "upkp")  [LANDED]   day.c (begin_upkeep/up_*: healing, loyalty/starve, animal/corpse decay)
   │     └─ leaf key(noble, sub, "heal"/"loyl"/"sckn"/"dier"/"corp")  ← keyed leaves, one per-turn stream
   │             entity in leaf key (no per-entity chokepoint); inn_income -> future income subsystem
   │
   ├─ quest      key(turn, where|who, "qest")  [LANDED]   quest.c (begin_quest/qrnd), use.c
   │     └─ seq  monster/loot/artifact generation; fresh per-scenario stream (begin_battle model)
   │             where for the QUEST command, actor for the skull relic use
   │
   ├─ explore    key(turn, 0,        "expl")  [LANDED]   c1.c (begin_explore/expl_*), stealth.c (d_seek)
   │     └─ leaf key(who, where|target, "find"/"gate"/"flav"/"pick"/"seek"/"dtct")  ← keyed leaves, one per-turn stream
   │             actor in leaf key (no chokepoint); tunnel.c dungeon-gen -> worldgen (11), torture/petty -> skills (9, landed)
   │
   ├─ skills     key(turn, 0,        "skil")  [PARTIAL]  use.c (begin_skills/skil_*), c2.c (weapon), stealth.c (torture/petty)
   │     └─ leaf key(who, ctx, "crit"/"yiel"/"stdy"/"rsch"/"rpik"/"tort"/"ptty")  ← keyed leaves, one per-turn stream, actor in k1
   │             COMMAND CORE landed; deferred: basic.c aura/heal + alchem.c -> magic (10); art.c crafting -> follow-up; produce.c -> economy residual
   │
   ├─ magic      key(turn, 0,        "magc")  [PARTIAL]  basic.c (begin_magic/magc_*), scry.c, relig.c, necro.c, alchem.c, art.c
   │     └─ leaf key(who, ctx, "scry"/"piet"/"eatd"/"lern"/"medi"/"omen"/"heal"/"potn"/"forg"/"orb "/"ring")  ← keyed leaves, one per-turn stream, actor in k1
   │             COMMAND CORE + art.c crafting commands landed; deferred: curse_erode day-pick (day.c) -> stays global; auto_undead -> npc; art.c minters new_orb/create_npc_token -> quest, new_suffuse_ring -> economy; cloud.c -> region:cloud (12)
   │
   ├─ worldgen   key(turn, location, "wgen")  [proposed] seed.c (region/sublocation/feature seeding), tunnel.c (dungeon-gen, deferred from explore)
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

| Order | Root system | Tag                  | Scenario key  | Status                                                                | Primary files                                                                        |
|-------|-------------|----------------------|---------------|-----------------------------------------------------------------------|--------------------------------------------------------------------------------------|
| 1     | combat      | `comb`               | location      | **landed**                                                            | `combat.c`                                                                           |
| 2     | pillage     | `pill`               | location      | **landed**                                                            | `combat.c`, `npc.c`                                                                  |
| 3     | economy     | `econ`               | market        | **landed**                                                            | `buy.c`, `seed.c`                                                                    |
| 4     | npc         | `npcs`               | location      | **landed**                                                            | `npc.c`, `savage.c`                                                                  |
| 5     | weather     | `wthr`               | turn (loc 0)  | **landed**                                                            | `storm.c`, `day.c`                                                                   |
| 6     | upkeep      | `upkp`               | turn (loc 0)  | **landed**                                                            | `day.c`                                                                              |
| 7     | quest       | `qest`               | where / actor | **landed**                                                            | `quest.c`, `use.c`                                                                   |
| 8     | explore     | `expl`               | turn (loc 0)  | **landed**                                                            | `c1.c`, `stealth.c`                                                                  |
| 9     | skills      | `skil`               | turn (loc 0)  | **landed (command core)** — crafting/aura/alchemy deferred            | `use.c`, `c2.c`, `stealth.c` (deferred: `basic.c`, `alchem.c`, `art.c`, `produce.c`) |
| 10    | magic       | `magc`               | turn (loc 0)  | **landed (command core + art.c crafting commands)** — curse-erode/auto-undead + quest/economy minters deferred | `basic.c`, `scry.c`, `relig.c`, `necro.c`, `alchem.c`, `art.c`                       |
| 11    | worldgen    | `wgen`               | location      | proposed                                                              | `seed.c`, `tunnel.c` (dungeon-gen)                                                   |
| 12    | regions     | `faer`/`hads`/`clud` | location      | proposed                                                              | `faery.c`, `hades.c`, `cloud.c`                                                      |
| 13    | mint        | `mint`               | entity id     | last                                                                  | `z.c`, `pw.c`                                                                        |

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
- **weather came next** (now landed) — `day.c` + `storm.c` are split across
  environmental events (location-keyed) and per-noble upkeep (entity-keyed);
  splitting weather out removed the single largest slice of global coupling
  (~76.7k draws/turn, dominated by the `create_some_storms` province shuffles).
  It is the one consumer that uses a **persistent per-turn stream** (seeded once,
  turn-guarded) rather than a fresh per-scenario one, because its reached draws
  are sequential province shuffles — see
  [Fifth consumer](#fifth-consumer-weather). Like economy/npc it ran on the
  standard turn, so it took a one-time main-manifest re-baseline.
- **upkeep came next** (now landed) — the per-noble half of `day.c` (healing,
  loyalty decay, starvation, animal deaths, corpse decay), entity carried in the
  leaf key on one per-turn stream (like weather, seeded once / turn-guarded,
  because the draws have no per-entity chokepoint). It is byte-neutral on **both**
  golden trees — every upkeep draw is unreached (the bare map has no player
  chars; the guard-pillage soldiers are inventory items, its nobles afford
  maintenance and stay at full health) — the combat/pillage profile, so no
  re-baseline. `inn_income` (per-structure income) was left a global residual for
  a future income subsystem — see [Sixth consumer](#sixth-consumer-upkeep).
- **quest came next** (now landed) — the QUEST command and its sublocation
  guardian/loot generation (`quest.c`) plus the skull-relic use (`use.c`). Unlike
  upkeep's keyed leaves it uses a **fresh per-scenario sequential stream** (the
  `begin_battle` model), because the quest path is an ordered run of ~20 draws
  building one monster+loot outcome. Keyed on the sublocation (`d_quest`) or the
  actor (`v_use_bta_skull`); there is no first-class quest entity. Byte-neutral
  on **both** golden trees (every quest draw is command-only, unreached on the
  bare map and guard-pillage; the only world-init quest call, `create_relics`,
  draws nothing) — the upkeep profile, so no re-baseline and no `scenario.tgz`
  regeneration. See [Seventh consumer](#seventh-consumer-quest).
- **explore came next** (now landed) — the EXPLORE command (`c1.c`) and the SEEK
  detect rolls (`stealth.c` `d_seek`). Like upkeep it uses **one per-turn stream,
  keyed leaves** (the actor in the leaf key, no per-actor chokepoint across the
  two files). The boundary was the crux: `tunnel.c` dungeon generation was
  **deferred to worldgen** (step 11) — it is pure world-gen, fires at INIT with
  the largest draw set in the engine (~409,727 `rnd()`/build), and keys on
  `(where, feature)` not an actor — and `stealth.c`'s TORTURE/PETTY THIEF were
  **deferred to skills** (step 9) as skill commands. Byte-neutral on **both**
  golden trees (every explore draw is command-only, unreached on the bare map and
  guard-pillage, and none fire at world-init) — the quest/upkeep profile, so no
  re-baseline and no `scenario.tgz` regeneration. See
  [Eighth consumer](#eighth-consumer-explore).
- **skills came next, as a deliberate partial** (command core now landed) — the
  mundane, command-only skill draws: weapon training (`c2.c`), STUDY/RESEARCH
  (`use.c`), and the TORTURE/PETTY THIEF commands inherited from explore
  (`stealth.c`). Like explore it uses **one per-turn stream, keyed leaves** (the
  actor in the leaf key). Byte-neutral on **both** golden trees (every skill draw
  is command-only, unreached on the bare map and guard-pillage, and none fire at
  world-init) — the quest/explore profile, so no re-baseline and no `scenario.tgz`
  regeneration. The slice **stops at the magic boundary**: `basic.c` aura/heal and
  `alchem.c` potions defer to magic (step 10), `art.c` artifact crafting to a
  post-magic follow-up (three overlaps incl. a world-init mint risk), and
  `produce.c` stays an economy residual. See
  [Ninth consumer](#ninth-consumer-skills-command-core).
- **magic came next, as a deliberate partial** (command core now landed) — the
  player-cast spell draws across `scry.c`/`relig.c`/`necro.c`/`basic.c`/`alchem.c`
  (scrying, religion gates, necromancy eat-dead/skill-transfer, the meditation/aura
  + heal spells and alchemy potions inherited from the skills step-9 deferral).
  Like explore/skills it uses **one per-turn stream, keyed leaves** (the actor in
  the leaf key, no per-actor chokepoint across the five files). Byte-neutral on
  **both** golden trees (every magic draw is command-only, unreached on the bare
  map and guard-pillage, and none fire at world-init) — the quest/explore/skills
  profile, so no re-baseline and no `scenario.tgz` regeneration. The slice **stops
  at the command/auto boundary**: the `day.c` `curse_erode_day` turn-auto day-pick
  stays global (migrating it would move the main manifest), `necro.c` `auto_undead`
  defers to npc (autonomous behavior), and `cloud.c` to region:cloud (step 12). The
  `art.c` **crafting commands** (FORGE AURACULUM / USE orb / USE suffuse-ring) then
  landed on `magc` too (the crafting follow-up — also byte-neutral, also 0 at
  world-init), leaving only the `art.c` **shared-infra minters** deferred
  (`new_orb`/`create_npc_token` → quest, `new_suffuse_ring` → economy). See
  [Tenth consumer](#tenth-consumer-magic-command-core).
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
- `olympia/quest.c` — `begin_quest()`/`qrnd()` (quest), the seventh consumer;
  the QUEST command and skull-relic use, command-only (unreached on both trees).
- `olympia/c1.c` — `begin_explore()`/`expl_*` (explore), the eighth consumer;
  the EXPLORE command + `stealth.c` `d_seek` detect, command-only (unreached on
  both trees). `tunnel.c` dungeon-gen deferred to worldgen, torture/petty to skills.
- `olympia/use.c` — `begin_skills()`/`skil_*` (skills, command core), the ninth
  consumer; weapon training, STUDY/RESEARCH, TORTURE/PETTY THIEF, command-only.
- `olympia/basic.c` — `begin_magic()`/`magc_*` (magic, command core), the tenth
  consumer; scry/relig/necro/meditation/alchemy spell draws plus the `art.c`
  crafting commands (FORGE AURACULUM / USE orb / USE suffuse-ring via
  `magc_forge`/`magc_orb`/`magc_ring`) across six files, command-only (unreached on
  both trees). `curse_erode`/`auto_undead` and the `art.c` shared-infra minters
  (`new_orb`/`create_npc_token` → quest, `new_suffuse_ring` → economy) deferred.
- `tests/olympia/regress/guard-pillage/` — the combat golden tree (and the
  #4-unreachability write-up).
- [agentic-project-ultron.md](agentic-project-ultron.md) — the coverage
  initiative this unblocks.
