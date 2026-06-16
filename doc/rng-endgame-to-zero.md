# Issue #25 endgame — drive gameplay `rnd()` to zero

This is the master plan for finishing issue #25: replace **every gameplay /
world-build draw** that still uses the process-global serial `rnd()` so the engine
exits #25 with no `rnd()` in any game logic. Each unit below becomes its own
session → branch → squash PR (`Refs #25`), in order. Surface scope + re-baseline
plan and get confirmation BEFORE implementing each unit; ask before pushing.

## Finish line (decided) — ✅ ACHIEVED (Unit F, #25 closed)

- **Zero gameplay draws on global `rnd()`.** `rnd()` (lib/rnd.c) stays only as the
  low-level MD5 primitive that the `rng` layer itself is built on; no game logic or
  world build may call it. **Verified empirically**: an instrumented `rnd()` counts
  0 on `-i`/`-r`/`-s`/`-a`/`-R` and both guard-pillage twins. This includes the
  *indirect* draws (`ilist_scramble`/`exit_views_scramble` via `lib/`), which the
  call-site grep below cannot see — Unit F migrated those onto streams too.
- `test_random()` (`olympia/z.c:456`, the `-R` self-test, `main.c:738`) is
  **repointed to draw from an `rng_stream`** (or kept strictly as the generator's
  own unit test) — it no longer counts as a gameplay draw either way.
- **Dead code deleted as cleanup** when its file is touched: `equip_new_noble`
  (`c1.c`, `#if 0`, 7 `rnd()` sites), the commented `tunnel.c:506` and `buy.c:1547`.
- **Exit gate:** the audit grep below must return only the lib/rnd.c definition and
  the (repointed) self-test — wire it into `tests/rng/check.sh` as a standing
  "no gameplay rnd()" assertion.

```
# audit: live gameplay rnd() call sites (should hit ZERO game-logic lines at exit)
grep -rnE '[^_a-zA-Z]rnd\(' olympia/*.c | grep -v 'olympia/rnd.c' \
  | grep -vE ':\s*\*|//'        # drop comments
```

## Full remaining surface (audited against current main — re-verify, line numbers shift)

41 live gameplay draws in 7 buckets at the start (after excluding the dead code +
the `-R` self-test). **ALL SEVEN BUCKETS ARE NOW LANDED — #25 is DONE.** Unit A
removed the 6 skills/magic residuals (bucket 4); Units B+C (one PR) removed the 3
calendar day-picks (bucket 1) and the 4 `inn_income` draws (bucket 2); Unit D
removed the 10 social-command draws (bucket 3); Unit E removed the 11 entity
catch-all draws (bucket 6) — and the original tally over-counted: bucket 5 ("quest
shared-infra") and one bucket-6 site (`u.c nearby_grave`) turned out to be **dead
`#if 0` code**, not live draws; **Unit F removed the mint bucket (7)** — the
entity-id allocator + add-player draws — and, beyond the literal audit, the
indirect `ilist_scramble`/`exit_views_scramble` draws the `rnd(`-grep never saw
(`dir.c` exit-direction shuffles, ~117/turn → the new `exitdir` stream; plus
`npc`/`add` sites). The standing audit gate is live and the global `rnd()` is now
**zero** on every flow:

1. **calendar** ✅ **LANDED (Unit B)** — `day.c` daily_events day-picks
   (`curse_erode_day`, `faery_day`, `dog_bark_day`) → new per-turn `caln` stream.
2. **income** ✅ **LANDED (Unit C)** — `day.c inn_income()` (base, `rnd(1,8)`
   gate, `rnd(5,13)` bonus, `switch rnd(1,3)` flavor) → folded into upkeep `upkp`.
3. **social** ✅ **LANDED (Unit D)** — `swear.c`: `:405`, `:488`, `:495`, `:713`,
   `:1022`, `:1039`, `:1110` (gift flavor / bribe / terrorize / incite / persuade-oath);
   `beast.c`: `:314`, `:322`, `:330` (breeding accidents) → new per-turn `socl` stream.
4. **skills/magic residuals** ✅ **LANDED (Unit A)** — `produce.c`
   `finish_generic_mine:242` / `d_generic_harvest:654` → `econ_mine`/`econ_harvest`;
   `necro.c auto_undead:405` → `npc_behavior`; `art.c` minters `new_orb:895` /
   `create_npc_token:1253` → `qrnd`, `new_suffuse_ring:1427` → `econ_ring`.
   (`create_npc_token:1102` is `#if 0` **dead code** in `add_token_unit`, never a
   live draw. `produce.c mage_menial_how:702`, a cosmetic actor-keyed flavor pick,
   stays global → bucket 6 / Unit E instead.)
5. **quest shared-infra** — ✅ **LANDED (Unit E): a no-op.** Both listed sites are
   **dead `#if 0` code**: `quest.c free_artifact:288` (its only caller, the
   `make_subloc_monster` `#if 0` block at `:598`, is also dead). The **live**
   `make_subloc_monster` body already draws entirely from `qrnd()` — there was
   nothing live to route. (Documented in [dead-code.md](dead-code.md).)
6. **entity catch-all** ✅ **LANDED (Unit E)** — `stack.c check_prisoner_escape:267`
   / `drop_stack` gate+dir; `u.c take_unit_items` gate+amount / `add_char_damage`
   sick / `find_nearest_land` dir+pick / `bark_dogs`; `build.c create_new_building`
   mine-gate; `produce.c mage_menial_how` → new per-turn `enty` stream (tag
   0x656e7479). **11 live sites, not 12** — `u.c nearby_grave:451` was also dead
   `#if 0` code (documented in [dead-code.md](dead-code.md)).
7. **mint** ✅ **LANDED (Unit F)** — `code.c rnd_alloc_num` (THE entity-id
   allocator, reached by every random-id `new_ent`/`alloc_box`), `add.c
   get_city_id` / password gen → new per-turn `mint` stream (tag 0x6d696e74).

## Units, in order (cheapest / most byte-neutral first; mint last — it re-bakes every id)

Each unit reuses the established conventions: a 4-char ASCII tag packed to
`uint32`, `rng_stream_of(turn, key, TAG)` derived order-independently off the turn
root, keyed-leaf draws via `rng_keyed(stream, k1, k2, tag, lo, hi)` (or a fresh
sequential stream via `rng_draw` for ordered runs). Cross-file helpers exposed via
`proto.h` (the `begin_economy`/`qrnd` convention). For each unit: instrument/count
to confirm reachability, re-baseline deliberately only if it moves a manifest, and
keep both golden gates green on both presets (debug + asan-ubsan).

### Unit A — skills/magic residuals → existing econ / npcs / qest streams  ✅ LANDED
Routed onto **already-landed** subsystems (NO new tags). Six live draws migrated;
`new_suffuse_ring` forced a main-manifest re-baseline (still **204 files**,
content-only: `loc`/`item`/`master`/`randseed`/`save/1/202` shifted as 25 draws/turn
left the global stream), the other five draw **0** on both trees and at world-init so
**guard-pillage stayed byte-neutral** (no `scenario.tgz` regen, no `EXPECT` change).
Both golden gates green on both presets; `tests/rng/check.sh` YES. What landed:
- `produce.c` mining/harvest → **economy** (`econ`): `begin_economy(where)` +
  new `econ_*` keyed leaves on `(item, where)` for `finish_generic_mine:242` and
  `d_generic_harvest:654`. (`mage_menial_how:702` is **not** in this unit — it is a
  cosmetic labor-flavor pick with no item/where, deferred to Unit E as an
  actor-keyed `enty` leaf.)
- `necro.c auto_undead:405` `rnd(1,2)` → **npc** (`npcs`): `npc_behavior(who, …)`
  (the auto_bandit/auto_savage precedent). Do NOT touch the undead troop-count
  (`necro.c:114` `do_cookie_npc`, already on `npcs`).
- `art.c new_orb`/`create_npc_token` → **quest** (`qest`) via the already-exposed
  `qrnd()` (they run inside quest loot gen, `quest.c:559/575`, after `begin_quest`).
  CONFIRM `create_relics` (world-init, `quest.c:93`) does not reach them.
- `art.c new_suffuse_ring` → **economy** (`econ`): `trade_suffuse_ring` (`buy.c`)
  already calls `begin_economy(where)`; add a small `econ_*` helper. **This fires
  ~22–42×/turn → NOT byte-neutral → main-manifest re-baseline.**

Byte-neutrality: produce/auto_undead/quest-minters expected byte-neutral (verify);
`new_suffuse_ring` forces the re-baseline the others fold into. Likely one PR.

### Unit B — calendar scheduler (day-picks) → new `caln` stream  (tag 0x63616c6e)  ✅ LANDED
The three `day.c` day-picks (`curse_erode_day`/`faery_day`/`dog_bark_day`). A
**turn-guarded per-turn stream** (the weather/upkeep model: seeded once via the
static `begin_calendar()`), keyed leaves with the pick identity in the key
(`cal_day(which, lo, hi)` → `rng_keyed(&calendar_rng, which, 0, CTAG_DAY, lo, hi)`,
`which` 0/1/2). All three sites are local to `daily_events()`, so `cal_day()` is
**static in `day.c`** — no `proto.h` export (the simplification vs weather/explore).
This retires the day-picks' "deliberate permanent residual" framing — they now have
a home. (The `weather_days` shuffle stays on `wthr`/`wthr_shuffle`, untouched.)

Each pick fires **exactly once per turn on BOTH golden trees** (verified
empirically) and **0 at world-init** (`daily_events` is not reached at `-i`/`-s`/
`-a`) → NOT byte-neutral, but **EXPECT-only** (no `scenario.tgz` regen). The
re-baseline (landed with Unit C, one PR) moved the **main manifest 204 → 205
files** — not the predicted "content-only 204": dropping the 3 day-picks off the
global stream shifted the still-global mint (entity-id allocator), and one
wandering NPC now persists a residual move queue (`orders/204`). The output is
deterministic across independent clean runs (verified), so it is a valid baseline.

### Unit C — income (inn_income) → fold into upkeep (`upkp`)  ✅ LANDED (with Unit B)
`day.c inn_income()` 4 draws → `up_income(inn, sub, …)` keyed leaf (sub 0=base,
1=jackpot gate, 2=bonus, 3=pillage flavor; purpose tag `UTAG_INCOME` "inco") on the
existing per-turn upkeep stream rather than a new tag. **Byte-neutral on both
trees**: neither golden tree contains an inn (0 `inn_income` draws on either turn
and at world-init, verified empirically), so it added nothing to Unit B's
re-baseline. Bundled into Unit B's PR (both touch `day.c`).

### Unit D — social → new `socl` stream  (tag 0x736f636c)  ✅ LANDED
`swear.c` (gift-acknowledgement flavor, bribe pre-gate + success, terrorize
severity, incite rumor/failure, persuade-oath) + `beast.c` breeding-accident rolls —
the npc-deferred social/loyalty residuals. **All 10 draws on ONE turn-guarded
per-turn `socl` stream** seeded once via `begin_social()` (the skills/magic model:
keyed leaves, ACTOR in the leaf key k1, target/item folded into k2, a distinct
purpose tag per command — `SOTAG_GIFT`/`BRIBE`/`TERROR`/`INCITE`/`OATH`/`BREED`).
Hosted in `swear.c` (the hub, 7 sites; `begin_social()` + the `soc_gift`/`soc_bribe`/
`soc_terror`/`soc_incite`/`soc_persuade` helpers are **static**); `soc_breed`
(beast.c, 3 sites) is **exposed via `proto.h`** so its draws share the one stream
(the `begin_economy`/`skil_crit`/`magc_scry` cross-file convention — NOT a second
stream). The one incite-mob *spawn* in `swear.c:863` already rides the `npcs`
troop-count — left alone.

**Byte-neutral on both trees** (the quest/explore/skills/magic profile): every site
is a player social command, neither golden tree issues BRIBE/TERRORIZE/INCITE/
PERSUADE/BREED, and none fire at world-init — verified empirically (0 draws on the
bare-map turn, both guard-pillage twins, and `-s`/`-a`/`-i` world-init via an
instrument/count/revert pass). So **no re-baseline, no `scenario.tgz` regen**; both
golden gates green on both presets, `tests/rng/check.sh` YES, audit grep zero.

### Unit E — entity catch-all → new `enty` stream  (tag 0x656e7479)  ✅ LANDED
The one-off entity/command behaviors with no natural subsystem: `stack.c`
(prisoner escape, drop-stack scatter), `u.c` (TAKE-SOME qty, sick-onset gate,
find_nearest_land dir+pick, bark_dogs), `build.c` (new-mine gate-crystal gate), and
`produce.c mage_menial_how` (the cosmetic mage labor-flavor pick, deferred here from
Unit A because it is actor-keyed flavor, not an economic draw). **11 live sites** on
ONE turn-guarded per-turn `enty` stream seeded once via `begin_entity()` (the
explore/skills/magic/social model: keyed leaves, the actor/location in the leaf key
k1, a distinct purpose tag per site — `ENTAG_PRISON`/`DROP`/`TAKE`/`SICK`/`LANDDIR`/
`LANDPICK`/`BARK`/`BUILD`/`MENIAL`). Hosted in `u.c` (the hub, 6 of 11 sites);
`begin_entity()` + the u.c-local helpers (`ent_take`/`ent_sick`/`ent_land_dir`/
`ent_land_pick`/`ent_bark`) are static, while `ent_prisoner`/`ent_drop` (stack.c),
`ent_build` (build.c), and `ent_menial` (produce.c) are exposed via `proto.h` so
their draws share the one stream (the `begin_economy`/`skil_crit`/`magc_scry`/
`soc_breed` cross-file convention). Two keying nuances: `find_nearest_land`'s dir
draw carries the bounded-retry counter in k2 (a fixed key would make every retry
walk the same way); `add_char_damage`'s sick gate carries the post-hit health in k2
(a char may be hit several times per turn before the sick flag latches).

**The quest shared-infra half was a no-op.** Both `quest.c` sites the brief listed
(`free_artifact:288`, the `make_subloc_monster:598` caller) are **dead `#if 0`
code**; the live `make_subloc_monster` already draws from `qrnd()`. Same for
`u.c nearby_grave:451` (listed as a 12th entity site) — also dead `#if 0`. All three
are documented in [dead-code.md](dead-code.md) and left in place as Unit-F-era
cleanup.

**Byte-neutral on BOTH trees** (the social/Unit-D profile, despite the mixed
prediction). Instrument/count/revert showed: **0** entity draws on the bare-map turn
and at every world-init (`-i`/`-s`/`-a`) → main manifest byte-identical; the
guard-pillage turn fires **4** `ent_prisoner` rolls (prisoners taken in the pillage)
but they do not perturb the four hashed faction records — both twins (`check.sh`
frozen + `check-lua.sh` lua-built) still match `EXPECT.sha256` unchanged. So **no
re-baseline and no `scenario.tgz` regen**. `add_char_damage` (the flagged likely
mover) does not fire — the pillage nobles die outright rather than survive wounded.

### Unit F — mint (LAST) → `mint` stream  (tag 0x6d696e74)  ✅ LANDED — #25 DONE
`code.c rnd_alloc_num` (the entity-id allocator) + `add.c` id/password gen, onto a
fresh per-turn **SEQUENTIAL** `mint` stream (NOT keyed leaves — there is no entity
in hand when minting its id, and no natural leaf key; the win is **isolation**, the
worldgen-tunnel / quest-`qrnd` sequential-stream precedent). Seeded once via the
turn-guarded `begin_mint()`, which fires at INIT too (the `begin_worldgen()`
`sysclock.turn`-at-INIT idiom) because the allocator mints at the `-i`/`-s`/`-a`
world build *and* during the turn. Hosted in `code.c` (the allocator hub); the
`add.c` draws share the same stream via `mint_password(pl, i, n)` (a **keyed** leaf
on `(pl, i)` — passwords have a natural key) and `mint_city()` (sequential, like the
allocator), exposed via `proto.h`. `rnd_alloc_num` calls the file-static
`mint_alloc(low, high)`.

**Empirical mint counts** (instrument/count/revert): main `-i` 8189, main `-r`
18124, guard-pillage frozen turn 8320 — all `rnd_alloc_num`; the `add.c` draws (2
`mint_city` + 2×8 `mint_password`) fire **only** when the scenario build's `-a`
pass mints the two nobles, re-baking their ids (now **pillager 4126 / guard 8651**)
and passwords.

**This re-bakes every entity id → the biggest re-baseline of the project**, on
BOTH trees (the reason mint is last): the main manifest stayed **205 files**
(content-only — `loc`/`item`/`master`/`unform`/`gate` + the renumbered `fact/*`
shifted as ~26k allocator draws/turn left the global stream), and the
guard-pillage tree took a `scenario.tgz` regen (`build-scenario.sh`) +
`EXPECT.sha256` re-baseline (`check.sh --update`), with **both `check.sh` and
`check-lua.sh` agreeing** — confirming the saved-`randseed` → master-seed coupling
the economy/worldgen/regions docs flagged has now **settled and disappeared** (no
gameplay `rnd()` advances `digest` during a turn, so the saved `randseed` is
stable turn-to-turn).

Also in the PR (the exit-criterion cleanup):
- **`test_random()` (`z.c`, the `-R` self-test) repointed** to a local
  `rng_stream` rooted at the master seed — the generator's own smoke test, no
  longer a gameplay draw (its format string and `ilist_scramble` were retired too).
- **Dead `rnd()` sites deleted** (the audit grep is pure text — it cannot skip
  `#if 0`/comments): `c1.c equip_new_noble` + its call, `code.c okay_entity_code`,
  `art.c:1102`, `buy.c` expire-jitter comment, `tunnel.c` hades-from-sewer comment,
  `u.c nearby_grave`, `quest.c free_artifact` + its dead caller. Archived in
  [dead-code.md](dead-code.md). Descriptive comments that mentioned a literal
  `rnd(` (basic.c, use.c, day.c) were reworded.
- **The standing audit gate** wired into `tests/rng/check.sh`: the endgame grep
  over `olympia/*.c` must return **zero**. It passes — **this is the definition of
  #25 done.**

**Indirect draws too (scope expansion — surfaced by instrumentation).** The
literal-`rnd(` audit never caught draws made *through* the `lib/` list helpers
`ilist_scramble()`/`exit_views_scramble()` (which call `rnd()` internally). The
bare-map turn still made **117** such draws — all from `dir.c`'s randomized
exit-direction pick (`exits_from_loc_nsew_select` with `rand` set, reached from
NPC/savage movement in `npc.c`/`savage.c`). To make "zero gameplay draws"
literally true (not just zero call *sites*), Unit F also: added
`exit_views_shuffle_rng()` to `lib` (the `ilist_shuffle_rng` precedent) and routed
`dir.c` onto a new per-turn **`exitdir`** stream (tag 0x65786472, the weather
model — one per-turn sequential stream, `begin_exitdir()`); routed `npc.c
auto_bandit`'s victim pick onto the `npcs` stream (keyed `NTAG_VICTIM`); and routed
`add.c`'s "empty"-start candidate shuffle onto the `mint` stream (`mint_shuffle`).
The two remaining gameplay `ilist_scramble` sites (`faery.c swap_region_locs`,
`necro.c random_body_here`) were **dead** and deleted. After this, an instrumented
`rnd()` counts **0** on `-i`/`-r`/`-s`/`-a`/`-R` and both guard-pillage twins —
the global `rnd()` survives only as the MD5 primitive under the `rng` layer.

## Per-unit gates (every unit, both presets debug + OLYMPIA_PRESET=asan-ubsan, zero diagnostics)
- `./tests/olympia/golden_check.sh` after `./run/mapgen/mapgen.sh` + `./run/olympia-g3.sh`
  (re-baseline deliberately if it moves — note the file count + why).
- guard-pillage `check.sh` AND `check-lua.sh` → YES (regen `scenario.tgz` + `EXPECT`
  only if the unit is shown to draw at world-init).
- `tests/rng/check.sh` (and, from Unit F, the new no-gameplay-rnd() assertion).
- clean build under the full `-Werror` ladder.

## Docs to update (each unit)
- `doc/rng-state-granularity.md` — add the new stream to the distribution map/tree
  + table; replace "mint is last" framing with this endgame; flip each unit's
  residual bullets to landed; record any re-baseline like the economy/regions
  sections. Update the intro count.
- `doc/turn-execution-order.md` — flip the affected notes (day-picks now on
  `caln`/`upkp`, social/entity draws keyed, auto_undead on `npcs`).
- `CLAUDE.md` — bump the consumer list; on Unit F, state #25 exits with zero
  gameplay `rnd()` and the standing audit gate.

## Workflow (every unit)
Branch `feat/rng-<unit>` off main, squash-PR `Refs #25`, cross-reference issue #25
with a summary comment (`gh issue comment 25`). Surface scope + re-baseline plan
before implementing; ask before pushing/merging.
