# RNG streams (#25, complete)

> Split out of [CLAUDE.md](../../CLAUDE.md). Read this when you add, move or remove a random draw, touch `lib/rng.{c,h}` or a `begin_*()` stream, or need to know why a change re-baselined (or did not re-baseline) a golden tree.

## Ultron groundwork (#25 — ✅ COMPLETE)

The [Project Ultron](../agentic-project-ultron.md) test-coverage initiative was
gated by **#25 — RNG-state granularity**.
**#25 is now complete**: the engine no longer draws from the process-global serial
stream for any gameplay or world-build randomness — every subsystem reseeds its own
addressable stream off the turn root, so a reordered/added draw no longer re-bakes
the whole manifest, unblocking the small per-subsystem fixtures Ultron needs. The
global `rnd()` (`lib/rnd.c` / `olympia/rnd.c`) survives only as the low-level MD5
primitive the `rng` layer is built on, and a standing audit gate in
`tests/rng/check.sh` keeps it that way. The design survey lives in
[doc/rng-state-granularity.md](../rng-state-granularity.md); the addressable seam is
`lib/rng.{c,h}` (`rng_seed`/`rng_stream_of`/`rng_draw`/`rng_keyed`). For **when** each
draw fires during a turn — the fixed phase order the driver walks, and which stream
each draw is on — see [doc/turn-execution-order.md](../turn-execution-order.md).
The follow-up stream ticket **#46** (per-game trade-route buyer secret) landed in
PR #71.

**#25 is COMPLETE — the engine has ZERO gameplay/world-build draws on the global
`rnd()`** (it survives only as the low-level MD5 primitive the `rng` layer is built
on), enforced by a standing audit gate in `tests/rng/check.sh`. The consumers landed
across the roadmap (1–12) and the endgame (units A–F): combat, pillage,
economy/market, npc, weather, upkeep, quest, explore, skills (command core), magic
(command core + `art.c` crafting), worldgen (INIT-time city seeding + dungeon
generation — the engine's largest draw set, first consumer at INIT, mandatory
re-baseline of both trees), regions (faery/hades/cloud — INIT build + turn-time
autonomous, tags `faer`/`hads`/`clud`), and finally **mint** (endgame Unit F —
the entity-id allocator + add-player draws, a per-turn sequential stream that
re-baked every id, the biggest re-baseline; closed #25). The endgame units A–E
(skills/magic residuals, calendar, income, social, entity catch-all) routed the
remaining one-off draws onto existing or small new per-turn streams. Each consumer
reseeds a stream off the turn root (`rng_master_seed()` → turn → its own 4-char
tag) and draws from it instead of the global `rnd()`:

- **combat** — per-battle stream on `(turn, location)`, `begin_battle()`/`crnd()`
  in `olympia/combat.c` (sequential `rng_draw`). Since #167 also keyed on both
  lead characters and the day, so two battles at one place in a turn draw
  independently; pillage likewise adds the pillager and the day.
- **pillage** — sibling per-pillage stream, `begin_pillage()`/`prnd()`
  (`combat.c`) plus the mob-name draw in `create_peasant_mob()` (`npc.c`).
- **economy/market** — `begin_economy()`/`econ_*` (`buy.c`, `seed.c`), keyed leaf
  draws on `(item, where, purpose)` via `rng_keyed`. The harvest/mine leaves
  (`econ_harvest`/`econ_mine`) also key on the unit and the day (#132), so every
  day of a harvest rolls afresh.
- **npc** — per-location `npcs` stream, `begin_npc()`/`npc_spawn`/`npc_qty`/
  `npc_behavior` (`npc.c`, `savage.c`); absorbs the pillage troop-count residual
  in the shared `do_cookie_npc()`.
- **weather** — **one per-turn** stream (tag `wthr`), seeded once via the
  turn-guarded `begin_weather()` (`storm.c`); `wthr_shuffle`/`wthr_storm`/
  `wthr_wreck` exposed via `proto.h` for `day.c`. Unlike the others it carries a
  *persistent counter* across the turn because its reached draws are sequential
  province shuffles (`natural_weather`/`create_some_storms` + the `weather_days`
  schedule, via the new `ilist_shuffle_rng` in `lib/ilist.c`). Largest
  manifest-mover yet (~76.7k draws/turn). Acute damage (`ship_coastal_damage`,
  mine/inn calamities) migrated to keyed `wthr_wreck` but is unreached on the bare
  map; `storm_decay`/`storm_move` draw nothing (the `"decay"` tag is reserved/
  unused).
- **upkeep** — **one per-turn** stream (tag `upkp`), seeded once via the
  turn-guarded `begin_upkeep()` (`day.c`); keyed-leaf helpers `up_heal`/`up_loyal`/
  `up_starve`/`up_animal`/`up_corpse` (static in `day.c` — every draw site is
  there). The per-noble gradual-maintenance draws (healing, loyalty decay,
  starvation, animal deaths, corpse decay); entity carried in the leaf key (no
  per-entity chokepoint, like weather). `inn_income` (per-structure income) later
  folded into this same stream as `up_income` (endgame Unit C); the `daily_events`
  day-picks moved to their own `caln` calendar stream (endgame Unit B);
  `temple_income` and the `post_month` decays draw nothing.
- **quest** — per-quest stream (tag `qest`), but a **fresh per-scenario reseed**
  (the `begin_battle` model, not turn-guarded) via `begin_quest()`/`qrnd()`
  exposed through `proto.h` (`quest.c`, `use.c`). The QUEST command generation
  chain is a sequential ~20-draw run (monster pick, gold/loot switch, artifact
  assembly, teach-book shuffle via `ilist_shuffle_rng`); keyed on the sublocation
  (`d_quest`) or the actor (`v_use_bta_skull`) — there is no first-class quest
  entity. Since #167 the stream also keys on the questing noble and the day, so
  a repeated quest in one subloc draws afresh. Shared infra on the path (`new_char`/`gen_item`/`create_unique_item`/
  `new_orb`/`create_npc_token`) stays global; `quest_decay` draws nothing.
- **explore** — **one per-turn** stream (tag `expl`), seeded once via the
  turn-guarded `begin_explore()` (`c1.c`) — since #167 **one per day**, so a
  repeated EXPLORE and each daily SEEK poll draw afresh; keyed-leaf helpers `expl_find`/
  `expl_gate`/`expl_flavor`/`expl_pick` (EXPLORE command, `c1.c`) and
  `expl_seek`/`expl_detect` (SEEK detect, `stealth.c` `d_seek`, exposed via
  `proto.h`). The upkeep model (keyed leaves, actor in the leaf key `k1`) because
  the draws are scattered across two files with no per-actor chokepoint and one
  actor may issue EXPLORE *and* SEEK in a turn. **Boundary decisions:** `tunnel.c`
  dungeon/subworld generation is **deferred to worldgen (step 11)** — pure
  world-gen, fires at INIT, no actor, and the engine's largest draw set
  (~409,727 `rnd()`/build), so migrating it would force a main-manifest +
  `scenario.tgz` re-baseline for no command-fixture benefit (now landed, see
  worldgen below); `stealth.c`'s TORTURE/PETTY THIEF are **deferred to skills
  (step 9)** as skill commands (now landed, below).
- **skills (command core)** — **one per-turn** stream (tag `skil`), seeded once
  via the turn-guarded `begin_skills()` (`use.c`, the skill-command hub); the
  explore model (keyed leaves, actor in the leaf key `k1`) because the draws are
  scattered across three files (`c2.c`, `use.c`, `stealth.c`) with no per-actor
  chokepoint. Keyed-leaf helpers `skil_crit`/`skil_bonus` (weapon training, `c2.c`
  ARCHERY/DEFENSE/SWORDPLAY), static `skil_study`/`skil_research`/
  `skil_research_pick` (STUDY/RESEARCH, `use.c`), and `skil_torture`/`skil_petty`
  (TORTURE/PETTY THIEF, `stealth.c`, inherited from explore; exposed via
  `proto.h`). A **deliberate partial**: only the mundane command-core draws land;
  the aura/magic-adjacent draws are deferred as named residuals — `basic.c`
  meditation/heal and `alchem.c` potions to **magic (step 10)** (**now landed**,
  below), `art.c` artifact/orb/ring crafting to a **post-magic follow-up** (three
  overlaps incl. a world-init mint risk — the **command** draws **now landed** on
  magc, below; the shared-infra minters stay deferred), and `produce.c`
  mining/harvest as an **economy** residual.
- **magic (command core)** — **one per-turn** stream (tag `magc`), seeded once via
  the turn-guarded `begin_magic()` (`basic.c`, the core-spell file); the
  explore/skills model (keyed leaves, actor in the leaf key `k1`) because the
  player-cast spell draws are scattered across six files (`scry.c`, `relig.c`,
  `necro.c`, `basic.c`, `alchem.c`, `art.c`) with no per-actor chokepoint. Cross-file
  keyed-leaf helpers `magc_scry` (scry/locate/unbar gates), `magc_piety` (religion
  gates), `magc_eat` (necro eat-dead, sub-keyed), `magc_learn` (necro skill
  transfer), `magc_potion` (alchemy brew/use), and the `art.c` crafting helpers
  `magc_forge`/`magc_orb`/`magc_ring` (FORGE AURACULUM kind+weight, USE orb, USE
  suffuse-ring — the post-magic crafting follow-up) exposed via `proto.h`; static
  `magc_med`/`magc_omen`/`magc_heal` for the `basic.c` meditation/aura + heal
  spells (the skills-deferred aura half, now landed). A **deliberate partial**:
  the turn-auto `curse_erode` day-pick (`day.c`) deferred to the calendar stream
  (now landed as endgame Unit B → `caln`), `necro.c` `auto_undead` defers to **npc**
  (autonomous behavior, already keyed troop-count rides the `npcs` stream), the
  `art.c` shared-infra **minters** stay deferred (`new_orb`/`create_npc_token` →
  **quest** loot, `new_suffuse_ring` → **economy** per-turn restock, which fires
  ~22–42×/turn), and `cloud.c` to **region:cloud** (**now landed**, below).
- **worldgen** — tag `wgen`, the **only consumer that fires at INIT** (not during
  the turn) and the engine's **largest draw set** (~409,733 draws/build). Carries
  **two draw models on one tag** (the weather precedent): `seed.c`'s non-economy
  city seeding (prominence/skill/garrison + the per-city tunnel gate) uses
  **keyed leaves** on a per-turn stream — turn-guarded `begin_worldgen()` +
  `wgen_prom`/`wgen_skill`/`wgen_garr`/`wgen_gate` (the last exposed via `proto.h`),
  location in the leaf key because the same city is seeded across three INIT passes
  (a sequential stream would correlate them); `tunnel.c`'s dungeon/subworld
  generation uses **fresh per-location sequential streams** —
  `begin_worldgen_loc(where)` + `wseq_rnd`/`wseq_shuffle` — because a dungeon is an
  ordered recursive build (un-keyable). **NOT byte-neutral** (the economy profile):
  both fire at the `-i`/`-s`/`-a` world-init, so it took a **mandatory one-time
  re-baseline of both trees** — the main manifest (still 204 files, content-only)
  and the guard-pillage `scenario.tgz` regen + `EXPECT.sha256` (both `check.sh` and
  `check-lua.sh` agree). No command-fixture benefit; its value is removing the
  largest draw set from the global stream and completing the INIT-seeding partition.
- **regions** — three sibling tags `faer`/`hads`/`clud` (`faery.c`, `hades.c`,
  `cloud.c`, plus the `npc.c` bandit residuals and the `u.c` transcend pick). Like
  worldgen each carries **two draw models on one tag** (the weather/worldgen
  precedent), split by reachability: the **INIT world build**
  (`create_faery`/`create_hades`/`create_cloudlands`, init-guarded in `io.c`) uses a
  **fresh per-build sequential stream** — `begin_<region>_build(<region>_id)` +
  `<r>seq_rnd`/`<r>seq_shuffle` (the `tunnel.c` model: ordered terrain/gate/populate
  generation, un-keyable); the **turn-time autonomous** behavior (`auto_hades`'s
  nasties, `auto_faery`'s elven hunts, the bandit ambushes, the transcend pick) uses
  **keyed leaves** on a turn-guarded per-turn stream — `begin_<region>()` +
  `hads_*`/`faer_*`, the auto-spawn loop slot in the leaf key for the spawns
  (no entity yet at the where/kind pick) and the actor/location for the bandit/
  transcend draws (helpers exposed via `proto.h` for `npc.c`/`u.c`). `cloud.c` is
  build-only. **NOT byte-neutral** (the worldgen profile): the build halves fire at
  world-init *and* — unlike the brief's expectation — the autonomous halves fire on
  the bare-map turn too (`auto_hades`/`auto_faery` run every turn: 25 nasty + 15 hunt
  spawns + 40 ambush-trigger draws). Migrated in **one PR** (all three builds share
  the same `io.c` INIT block) under a **single deliberate re-baseline of both trees**
  — main manifest still 204 files (content-only), guard-pillage `scenario.tgz` regen
  + `EXPECT.sha256` (noble ids moved to pillager 6249 / guard 2002; both `check.sh`
  and `check-lua.sh` agree). This **resolves the npc-deferred bandit residuals and
  the magic-deferred `cloud.c`**. The autonomous halves give future fixture
  addressability (a hades-ambush / faery-bandit fixture); the build halves do not.
  Smaller re-baseline than worldgen because `tunnel.c`/`seed.c` were already
  off-stream — only the still-global mint draws (+ saved `randseed`) shifted.

Combat and pillage were **byte-neutral on the main manifest** (the bare-map turn
runs no combat/pillage); economy, npc, and weather each ran on the standard turn
(`seed_city_trade` at INIT, `init_savage_attacks` per turn, `daily_events`
weather every day) and took a deliberate one-time re-baseline. **Upkeep is
byte-neutral on *both* trees** (the combat/pillage profile): every upkeep draw is
unreached — the bare map has no player chars and the guard-pillage soldiers are
inventory items, so its nobles afford maintenance and stay at full health — so it
took no re-baseline. **Quest is byte-neutral on *both* trees too** (the same
profile): every quest draw is command-only and neither tree issues a QUEST/USE
command, and the only world-init quest call (`create_relics`) draws nothing — so
no re-baseline and no `scenario.tgz` regeneration. **Explore is byte-neutral on
*both* trees too** (the quest/upkeep profile): every explore draw is command-only,
neither tree issues an EXPLORE/SEEK command, and none fire at world-init — so no
re-baseline and no `scenario.tgz` regeneration. **Skills (command core) is
byte-neutral on *both* trees too** (the same profile): every migrated skill draw
is command-only, neither tree issues a skill command (weapon training / STUDY /
RESEARCH / TORTURE / PETTY THIEF), and none fire at world-init (verified
empirically: 0 draws on the bare-map turn, both guard-pillage twins, and
`-s`/`-a`/`-i`) — so no re-baseline and no `scenario.tgz` regeneration. **Magic
(command core) is byte-neutral on *both* trees too** (the same profile): every
migrated spell draw is command-only, neither tree issues a magic / USE / BREW
command, and none fire at world-init (verified empirically: 0 draws on the
bare-map turn, both guard-pillage twins, and `-s`/`-a`/`-i`) — so no re-baseline
and no `scenario.tgz` regeneration. The **art.c crafting follow-up** (FORGE
AURACULUM / USE orb / USE suffuse-ring command draws, `magc_forge`/`magc_orb`/
`magc_ring` on the same `magc` stream) **is byte-neutral on *both* trees too**
(the same profile): all three command draws are 0 on the bare-map turn, both
guard-pillage twins, and `-s`/`-a`/`-i` world-init (verified empirically — the
flagged mint risk did not materialize) — so no re-baseline and no `scenario.tgz`
regeneration.
**Worldgen, by contrast, was NOT byte-neutral** (the economy profile): both
`seed.c`'s INIT city seeding and `tunnel.c`'s dungeon generation fire at the
`-i`/`-s`/`-a` world-init that `./run/olympia-g3.sh` and `build-scenario.sh` run,
so removing them from the global serial stream realigned the still-global mint
draws. It took a **deliberate one-time re-baseline of both trees** in the same PR:
`golden_check.sh --update` (main manifest, still 204 files — content-only shift)
and a guard-pillage `scenario.tgz` regen (`build-scenario.sh`) + `EXPECT.sha256`
re-baseline (`check.sh --update`), with both `check.sh` and `check-lua.sh`
agreeing. The saved-`randseed` → master-seed coupling that moved the guard-pillage
tree disappears once **mint** (step 13) lands.

Combat/pillage/npc/weather/upkeep behavior is pinned by its own golden tree,
[tests/olympia/regress/guard-pillage](../../tests/olympia/regress/guard-pillage)
(the **second** standing regress alongside secret-sea-route).

**Endgame — drive gameplay `rnd()` to zero — ✅ DONE (#25 CLOSED).** The twelve
roadmap subsystems plus endgame units A–F are all landed; the explicit exit
criterion for #25 was **no gameplay/world-build draw left on the global `rnd()`**
(it survives only as the low-level MD5 primitive the `rng` layer is built on) — now
**achieved and gated** (`tests/rng/check.sh`). The ~41 draws were sequenced into
units A–F (each its own branch + squash PR, surface-scope-first, both golden gates
green on both presets): **A (LANDED)** skills/magic residuals — `produce.c` mine/harvest →
`econ_mine`/`econ_harvest`, `necro.c auto_undead` → `npc_behavior`, `art.c`
minters `new_orb`/`create_npc_token` → `qrnd` and `new_suffuse_ring` → `econ_ring`
(all onto existing `econ`/`npcs`/`qest`, NO new tag; the per-turn suffuse restock
forced a 204-file content-only main-manifest re-baseline, guard-pillage byte-neutral;
`produce.c mage_menial_how` split out to Unit E); **B (LANDED)** the calendar
day-picks (`curse_erode`/`faery`/`dog_bark` → new `caln` per-turn stream via the
static `begin_calendar()`/`cal_day(which,…)`, keyed on the pick identity — this
retired the day-picks' "deliberate permanent residual" framing; fires every turn
on both trees but 0 at world-init, so EXPECT-only re-baseline — the main manifest
moved **204→205** as the mint shift adds an `orders/204` residual, guard-pillage
EXPECT only, no `scenario.tgz` regen); **C (LANDED, bundled with B)** `inn_income`
(→ folded into `upkp` as `up_income(inn,sub,…)`, no new tag — byte-neutral, no inn
on either golden tree); **D (LANDED)** the social commands (`swear.c` gift/bribe/
terrorize/incite/persuade + `beast.c` breeding-accident rolls — 10 draws → new
`socl` per-turn stream via the turn-guarded `begin_social()` + keyed-leaf helpers,
actor in the leaf key k1, a distinct purpose tag per command; the cross-file
skills/magic model — `begin_social()` + `soc_gift`/`soc_bribe`/`soc_terror`/
`soc_incite`/`soc_persuade` static in `swear.c`, `soc_breed` exposed via `proto.h`
for `beast.c`; the `swear.c:863` incite-mob spawn already rides `npcs`, left alone;
this retired the `swear.c`/`beast.c` "residual on global" framing — byte-neutral on
both trees, verified empirically 0 draws on the bare-map turn / both guard-pillage
twins / `-s`/`-a`/`-i`, so NO re-baseline and NO `scenario.tgz` regen); **E (LANDED)**
the entity catch-all (`stack.c` prisoner-escape/drop-stack + `u.c` TAKE-SOME/
sick-onset/find-nearest-land/bark-dogs + `build.c` new-mine gate + `produce.c
mage_menial_how` — **11 live sites** → new `enty` per-turn stream via the
turn-guarded `begin_entity()` + keyed-leaf helpers, actor/location in the leaf key
k1, a distinct purpose tag per site; the cross-file skills/magic/social model —
host `begin_entity()` + the u.c-local `ent_take`/`ent_sick`/`ent_land_dir`/
`ent_land_pick`/`ent_bark` static in `u.c`, `ent_prisoner`/`ent_drop`/`ent_build`/
`ent_menial` exposed via `proto.h` for `stack.c`/`build.c`/`produce.c`. The brief's
quest shared-infra half (`free_artifact`/`make_subloc_monster` rolls) and a 12th
entity site (`u.c nearby_grave`) turned out to be **dead `#if 0` code**, a no-op —
the live `make_subloc_monster` already draws from `qrnd` (documented in
`doc/dead-code.md`). **Byte-neutral on both trees**: 0 draws on the bare-map turn
and at all world-init, and the 4 `ent_prisoner` rolls the guard-pillage turn fires
do not perturb the hashed faction records — both twins match `EXPECT` unchanged, so
NO re-baseline and NO `scenario.tgz` regen); and **F (LANDED) — #25 CLOSED** mint,
the last consumer (`code.c rnd_alloc_num`, THE entity-id allocator, + `add.c`
ids/passwords → new per-turn **`mint`** stream, tag `mint`). Unlike A–E this is a
**fresh per-turn SEQUENTIAL stream** (`rng_draw` via the turn-guarded `begin_mint()`,
which also seeds at INIT — the `begin_worldgen()` idiom — because the allocator mints
at the `-i`/`-s`/`-a` world build *and* during the turn), NOT keyed leaves: there is
no entity in hand when minting its id and no natural leaf key, so the win is
**isolation** (the worldgen-tunnel / quest-`qrnd` precedent). Hosted in `code.c`
(`mint_alloc` static); the `add.c` draws share the stream via `mint_password(pl,i,n)`
(keyed leaf on `(pl,i)`) and `mint_city()` (sequential), exposed via `proto.h`.
**This re-baked every entity id → the biggest re-baseline of the project, on BOTH
trees** (the reason mint is last): main manifest stayed **205 files** (content-only —
`loc`/`item`/`master`/`unform`/`gate` + renumbered `fact/*` shifted as ~8189 INIT +
~18124 turn allocator draws left the global stream), and guard-pillage took a
`scenario.tgz` regen + `EXPECT` re-baseline (noble ids settled at pillager 4126 /
guard 8651), with both `check.sh` and `check-lua.sh` agreeing — confirming the
**saved-`randseed` → master-seed coupling is now gone** (no gameplay `rnd()` advances
`digest` during a turn). The same PR repointed `test_random()` (the `-R` self-test)
to a local `rng_stream`, **deleted** the remaining dead `rnd()` sites (`equip_new_noble`/
`okay_entity_code`/`art.c:1102`/`buy.c` jitter/`tunnel.c` hades-sewer/`nearby_grave`/
`free_artifact` + caller, archived in `doc/dead-code.md`), and **flipped on the
standing "no gameplay `rnd()`" audit gate** in `tests/rng/check.sh` (the `rnd(`-grep
over `olympia/*.c` must stay empty — **this passing IS the definition of #25 done**).
Beyond the call-site grep, Unit F also migrated the **indirect** draws it could not
see (`ilist_scramble`/`exit_views_scramble` via `lib/`): `dir.c`'s randomized
exit-direction pick (~117 draws/turn from NPC/savage movement) → a new per-turn
**`exitdir`** stream (tag `exdr`, weather model) via the new `exit_views_shuffle_rng`;
`npc.c auto_bandit`'s victim pick → `npcs` (`NTAG_VICTIM`); `add.c`'s "empty"-start
shuffle → `mint` (`mint_shuffle`); the two dead `ilist_scramble` sites
(`faery.c swap_region_locs`, `necro.c random_body_here`) deleted. **#25 exits with
ZERO gameplay/world-build `rnd()`** — verified empirically (an instrumented `rnd()`
counts 0 on `-i`/`-r`/`-s`/`-a`/`-R` and both guard-pillage twins); the global
`rnd()` survives only as the MD5 primitive under the `rng` layer.
The full per-unit plan is [doc/rng-endgame-to-zero.md](../rng-endgame-to-zero.md);
the migration order and per-subsystem keying live in
[doc/rng-state-granularity.md](../rng-state-granularity.md). A PCG32 generator swap
stays deferred behind the TAG 64-bit work; the follow-up **#46** landed in PR #71.
