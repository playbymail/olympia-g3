# CLAUDE.md

Guidance for working in the **Olympia G3** repository.

## What this is

G3 is the third-generation Olympia play-by-mail (PBM) strategy game engine
(~54K lines of C) — the GitHub-era version with refinements over G2, and the
ancestor of the TAG engine. This repo is a standalone extraction of G3 from the
original multi-engine monorepo; it builds on its own with CMake.

The code is legacy C originally targeting **32-bit** systems. The C11/64-bit
modernization warning ladder is **complete** (see [Modernization
status](#modernization-status)); the full phase-by-phase record and the
[warning policy](BUILD_HISTORY.md#warning-policy) live in
[BUILD_HISTORY.md](BUILD_HISTORY.md) — **read it before changing build flags or
touching prototypes/headers.**

## Build

Requires CMake (>= 4.1), Ninja, and Clang or GCC.

```bash
cmake --preset debug
cmake --build --preset debug
# Binaries: build/debug/{olympia-g3,mapgen-g3,island-g3}
```

Presets (`CMakePresets.json`): `debug` (default), `release`, `asan-ubsan`.
The `asan-ubsan` preset sets `OLYMPIA_SANITIZE=ON` with address+undefined on
**all three** targets.

There are **three** targets (one more than G1/G2): `olympia-g3` (engine),
`mapgen-g3` (map generator), and `island-g3` (island generator —
`mapgen/island.c` + `mapgen/rnd.c`).

### 32-bit build (Linux only — for regenerating golden files)

```bash
mkdir build32 && cd build32
cmake -DBUILD_32BIT=ON ..   # requires gcc-multilib
cmake --build .
```

## Test — golden snapshots (must stay green)

Any change must keep the golden tests passing. Modernization changes must
produce **byte-identical** engine output.

```bash
./run/mapgen/mapgen.sh                     # generate gate/loc/road
./run/olympia-g3.sh                        # extract fixtures, run a turn, save DB
./tests/olympia/golden_check.sh            # gate: byte-for-byte check of the saved DB
```

Scripts auto-detect the repo root and look for binaries at
`build/<preset>/<target>` (override with `OLYMPIA_PRESET=release ...`).

There is a **second standing gate**: the same flow under ASan/UBSan must run
clean. Build the `asan-ubsan` preset and re-run the flow with
`OLYMPIA_PRESET=asan-ubsan` — the golden check must still print `YES` and produce
**zero** ASan/UBSan diagnostics:

```bash
cmake --preset asan-ubsan && cmake --build --preset asan-ubsan
OLYMPIA_PRESET=asan-ubsan ./run/mapgen/mapgen.sh
OLYMPIA_PRESET=asan-ubsan ./run/olympia-g3.sh
OLYMPIA_PRESET=asan-ubsan ./tests/olympia/golden_check.sh   # YES, zero diagnostics
```

> **The olympia golden gate.** `tests/olympia/golden_check.sh` (adapted from G2)
> gates the post-turn DB in `run/olympia/lib` as a sorted sha256 **manifest**
> (`tests/olympia/golden/manifest.sha256`). Run `./run/olympia-g3.sh` (a full
> `-r -S` turn) first, then `golden_check.sh` (prints `YES`); re-baseline with
> `--update`. It is date-independent (the `test-use-const-report-date` flag — see
> BUILD_HISTORY.md). G3 output is **deterministic across clean rebuilds**, so the
> gate has **no flaky-file holdout**. `tests/mapgen/golden` is a **stale 32-bit
> baseline** — *not* the gate; the mapgen check is
> `tests/mapgen/regress/secret-sea-route/check.sh`.

## Layout

- `olympia/` — G3 engine sources (55 `.c`) and headers
- `mapgen/` — map generator (`mapgen.c`, `z.c`), island generator
  (`island.c`), and the MD5-based RNG (`rnd.c`, like G2)
- `lib/` — shared support code (entity lists, tiles, roads, allocation, …)
- `tests/` — golden fixtures (and the stale mapgen baseline)
- `run/` — run/test driver scripts and scratch run dirs
- `doc/` — assorted G3 design/reference notes, plus the modernization playbook
  and `phase4-tools/`
- `BUILD_HISTORY.md` — the full phase-by-phase modernization record + warning
  policy

## Conventions

- Legacy C style: tabs, ANSI prototypes for definitions, terse names. Match the
  surrounding file; don't reformat untouched code.
- **Golden output is the contract.** Behavior changes that alter engine output
  must be deliberate and the snapshot updated in the same change with a note on
  why. Modernization changes (prototypes, casts, dead-code removal) must produce
  byte-identical golden output.
- Build config lives in `CMakeLists.txt`. All compiler flags live in **one
  shared helper**, `olympia_compile_flags(tgt)`, applied identically to all three
  targets — `(island-g3)`, `(mapgen-g3)`, `(olympia-g3)`. The helper carries the
  `-Wno-*` suppressions plus the enforced `-Wfoo -Werror=foo` pairs (one pair per
  line, `# Phase N` comments). Optimization/debug (`-O`/`-g`) is owned by
  `CMAKE_BUILD_TYPE` / the presets, **not** the helper.
  `olympia_enable_sanitizers()` is called on all three targets. **Before changing
  any of this, read [BUILD_HISTORY.md](BUILD_HISTORY.md) and its
  [warning policy](BUILD_HISTORY.md#warning-policy).**
- **C11 standard** is set project-wide (`CMAKE_C_STANDARD 11` / `…_REQUIRED ON` /
  `CMAKE_C_EXTENSIONS OFF`) and declared per target via
  `target_compile_features(<tgt> PRIVATE c_std_11)`. The per-target call is
  documentation/intent only (inert — the global standard already forces
  `-std=c11`); it guards against divergence if new targets are added.
- **No CI.** Both golden gates are run locally (maintainer decision); warning
  enforcement is not wired into CI.

### Git workflow

Changes land via **feature branch + pull request** (the repo moved off
direct-to-`main` as of the #25 groundwork). Conventions:

- **Branch** from `main` named `type/slug` — `feat/…`, `fix/…`, `build/…`,
  `docs/…`, `refactor/…` (matching the Conventional-Commits type of the work).
- **Keep both golden gates green** on the branch before opening the PR — the
  byte-identical manifest check *and* the same flow clean under ASan/UBSan (see
  [Test](#test--golden-snapshots-must-stay-green)).
- **Reference the issue** in the PR body: `Closes #NN` when the PR fully resolves
  it, `Refs #NN` for partial/groundwork work. The `#NN` in commit subjects and
  PR bodies are **GitHub issue numbers**.
- **Squash-merge** to keep `main` linear. The squashed commit keeps the
  `type(scope): subject (#NN)` subject and the
  `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>` trailer.

## Modernization status

The C11/64-bit modernization ran as a phased warning ladder and is **complete**.
Every targeted warning class is enforced as `-Werror` via
`olympia_compile_flags()` in `CMakeLists.txt` (applied to all three targets:
`olympia-g3`, `mapgen-g3`, `island-g3`), and the golden flow runs clean under
AddressSanitizer + UndefinedBehaviorSanitizer. The per-phase scaffolding has been
removed; the remaining work is the actual 32→64-bit refactoring the ladder
cleared the way for.

Enforced classes (all `-Werror`):

| Phase | Scope |
|-------|-------|
| 1 | `int-to-pointer-cast`, `pointer-to-int-cast` |
| 2 | `incompatible-pointer-types` |
| 3 | `int-conversion` |
| 3.5 | removed dead/unused source files |
| 4 | `strict-prototypes`, `missing-prototypes`, `implicit-function-declaration` |
| 5 | `missing-declarations` + sanitizers verified against the golden flow |
| 6 | `shorten-64-to-32` (Clang-guarded) + `sizeof-pointer-memaccess` |
| 7 | `sign-conversion` |
| 8 | `return-type` + `return-mismatch` |
| 9 | `format` / vararg checking, full class incl. non-literal sites (project-wide; #20) |
| 10 | `implicit-int-conversion` (Clang-guarded, code-quality — not a 64-bit hazard) |

Also locked in: flag consolidation into `olympia_compile_flags()` with the dead
scaffolding removed (#12), sanitizers wired across all three targets (#13), and a
deterministic newsletter date for reproducible goldens.

**Before changing build flags, prototypes, or headers, read
[BUILD_HISTORY.md](BUILD_HISTORY.md)** — it has the full phase-by-phase record,
the traps each class hid (and the G3-specific divergences: the MD5 RNG, the third
`island-g3` target, the HTML-report/tunnel/`add.c` feature code), the rationale
behind every locked-in flag, and the
[warning policy](BUILD_HISTORY.md#warning-policy) for triaging new warnings.

### Known bugs deferred past the 64-bit effort

Post-modernization tracks, intentionally **not** part of the phase ladder (full
detail in [BUILD_HISTORY.md](BUILD_HISTORY.md#known-bugs-deferred-past-the-64-bit-effort)).

All cleared: **#4** (combat guard-check pointer/int compare) is fixed with a
proper `->unit` membership scan; **#19** (mapgen allocator) and **#20**
(non-literal format strings) are resolved. The #4 branch turned out to be
**unreachable** through its only caller — `attack_guard_units` builds `l_a` with
`add_allies = FALSE` (pillager's stack only) while guards are found via
`loop_here(province)` (province-direct only), so a guard can never be in both.
An A/B build (fixed vs buggy) yields a byte-identical battle report, so the fix
is correct-on-principle hardening of dead code and **no black-box fixture can
pin it** (write-up in
[tests/olympia/regress/guard-pillage/README.md](tests/olympia/regress/guard-pillage/README.md)).

### Next track: Ultron groundwork (#25)

The next forward track is the [Project Ultron](doc/agentic-project-ultron.md)
test-coverage initiative, gated by **#25 — RNG-state granularity**. The engine
draws from one process-global serial stream (`lib/rnd.c` / `olympia/rnd.c`), so
any reordered/added `rnd()` call re-bakes the whole 206-file manifest — which
makes the small, per-subsystem fixtures Ultron needs impossible. The design
survey lives in [doc/rng-state-granularity.md](doc/rng-state-granularity.md);
the addressable seam is `lib/rng.{c,h}`
(`rng_seed`/`rng_stream_of`/`rng_draw`/`rng_keyed`), with a self-check at
`tests/rng/check.sh`. For **when** each draw fires during a turn — the fixed
phase order the driver walks, and which draws are keyed vs still on the global
stream — see [doc/turn-execution-order.md](doc/turn-execution-order.md).

**Twelve consumers landed so far: combat, pillage, economy/market, npc, weather,
upkeep, quest, explore, skills (command core only), magic (command core
plus the `art.c` crafting commands), worldgen (INIT-time city seeding +
dungeon generation — the engine's largest draw set, the first consumer that fires
at INIT and required a mandatory re-baseline of both golden trees), and regions
(faery/hades/cloud — a worldgen-style hybrid carrying an INIT world build *and*
turn-time autonomous behavior, on tags `faer`/`hads`/`clud`; also required a
re-baseline of both trees).** Each
reseeds a stream off the turn root (`rng_master_seed()` → turn → its own 4-char
tag) and draws from it instead of the global `rnd()`:

- **combat** — per-battle stream on `(turn, location)`, `begin_battle()`/`crnd()`
  in `olympia/combat.c` (sequential `rng_draw`).
- **pillage** — sibling per-pillage stream, `begin_pillage()`/`prnd()`
  (`combat.c`) plus the mob-name draw in `create_peasant_mob()` (`npc.c`).
- **economy/market** — `begin_economy()`/`econ_*` (`buy.c`, `seed.c`), keyed leaf
  draws on `(item, where, purpose)` via `rng_keyed`.
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
  entity. Shared infra on the path (`new_char`/`gen_item`/`create_unique_item`/
  `new_orb`/`create_npc_token`) stays global; `quest_decay` draws nothing.
- **explore** — **one per-turn** stream (tag `expl`), seeded once via the
  turn-guarded `begin_explore()` (`c1.c`); keyed-leaf helpers `expl_find`/
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
[tests/olympia/regress/guard-pillage](tests/olympia/regress/guard-pillage)
(the **second** standing regress alongside secret-sea-route).

**Endgame — drive gameplay `rnd()` to zero.** The twelve roadmap subsystems are
landed; the explicit exit criterion for #25 is now **no gameplay/world-build draw
left on the global `rnd()`** (it survives only as the low-level MD5 primitive the
`rng` layer is built on). The ~41 draws are sequenced into units A–F (each
its own branch + squash PR, surface-scope-first, both golden gates green on both
presets): **A (LANDED)** skills/magic residuals — `produce.c` mine/harvest →
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
twins / `-s`/`-a`/`-i`, so NO re-baseline and NO `scenario.tgz` regen); **E** an entity catch-all
for the `u.c`/`stack.c`/`build.c` one-offs plus `produce.c mage_menial_how` (→ new
`enty`, quest-infra → `qrnd`), and
**F** mint last (`code.c rnd_alloc_num` + `add.c` ids/passwords → `mint`; same PR
repoints `test_random()` and flips on a standing "no gameplay `rnd()`" audit gate).
The full per-unit plan is [doc/rng-endgame-to-zero.md](doc/rng-endgame-to-zero.md);
the migration order and per-subsystem keying live in
[doc/rng-state-granularity.md](doc/rng-state-granularity.md). A PCG32 generator swap
stays deferred behind the TAG 64-bit work.
