# Issue #25 endgame — drive gameplay `rnd()` to zero

This is the master plan for finishing issue #25: replace **every gameplay /
world-build draw** that still uses the process-global serial `rnd()` so the engine
exits #25 with no `rnd()` in any game logic. Each unit below becomes its own
session → branch → squash PR (`Refs #25`), in order. Surface scope + re-baseline
plan and get confirmation BEFORE implementing each unit; ask before pushing.

## Finish line (decided)

- **Zero gameplay draws on global `rnd()`.** `rnd()` (lib/rnd.c) stays only as the
  low-level MD5 primitive that the `rng` layer itself is built on; no game logic or
  world build may call it.
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
the `-R` self-test). **Units A–C are landed**: Unit A removed the 6 skills/magic
residuals (bucket 4); Units B+C (one PR) removed the 3 calendar day-picks (bucket
1) and the 4 `inn_income` draws (bucket 2) → **28 live draws in 3 buckets** remain
(D–F):

1. **calendar** ✅ **LANDED (Unit B)** — `day.c` daily_events day-picks
   (`curse_erode_day`, `faery_day`, `dog_bark_day`) → new per-turn `caln` stream.
2. **income** ✅ **LANDED (Unit C)** — `day.c inn_income()` (base, `rnd(1,8)`
   gate, `rnd(5,13)` bonus, `switch rnd(1,3)` flavor) → folded into upkeep `upkp`.
3. **social** — `swear.c`: `:405`, `:488`, `:495`, `:713`, `:1022`, `:1039`,
   `:1110` (bribe / terrorize / persuade-oath / incite-riot); `beast.c`: `:314`,
   `:322`, `:330` (breeding accidents).
4. **skills/magic residuals** ✅ **LANDED (Unit A)** — `produce.c`
   `finish_generic_mine:242` / `d_generic_harvest:654` → `econ_mine`/`econ_harvest`;
   `necro.c auto_undead:405` → `npc_behavior`; `art.c` minters `new_orb:895` /
   `create_npc_token:1253` → `qrnd`, `new_suffuse_ring:1427` → `econ_ring`.
   (`create_npc_token:1102` is `#if 0` **dead code** in `add_token_unit`, never a
   live draw. `produce.c mage_menial_how:702`, a cosmetic actor-keyed flavor pick,
   stays global → bucket 6 / Unit E instead.)
5. **quest shared-infra** — `quest.c free_artifact:288`,
   `make_subloc_monster:598`.
6. **entity catch-all** — `stack.c check_prisoner_escape:267` / `drop_stack:409`+`420`;
   `u.c take_unit_items:291`+`292` / `add_char_damage:402` / `nearby_grave:451` /
   `find_nearest_land:1882`+`1945` / `bark_dogs:2458`; `build.c create_new_building:447`;
   `produce.c mage_menial_how:702` (cosmetic labor-flavor pick, actor-keyed).
7. **mint** — `code.c rnd_alloc_num:706` (THE entity-id allocator, reached by every
   random-id `new_ent`/`alloc_box`), `add.c get_city_id:73` / password gen `:201`.

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

### Unit D — social → new `socl` stream  (tag 0x736f636c)
`swear.c` (bribe success, terrorize severity, persuade-oath, incite-riot
rumor/failure) + `beast.c` breeding-accident rolls — the npc-deferred social/loyalty
residuals. Keyed leaves on `(actor, target|purpose)` (these are player social
commands, no per-actor chokepoint, the explore/magic model). The one incite-mob
*spawn* in `swear.c` already rides the `npcs` troop-count — leave it. Expected
byte-neutral on both trees (no social commands on the bare map) — verify, likely no
re-baseline.

### Unit E — entity catch-all → new `enty` stream  (tag 0x656e7479) + quest-infra to qrnd
The one-off entity/command behaviors with no natural subsystem: `stack.c`
(prisoner escape, drop-stack), `u.c` (TAKE qty, char damage, nearby_grave,
find_nearest_land, bark_dogs), `build.c` (build outcome), and `produce.c`
`mage_menial_how:702` (the cosmetic mage labor-flavor pick, deferred here from
Unit A because it is actor-keyed flavor, not an economic draw). One turn-guarded
per-turn stream, keyed leaves keyed on the actor/location + a purpose sub-tag per
site. Fold
the **quest shared-infra** (`free_artifact`, `make_subloc_monster`) into quest's
`qrnd()` instead (they run inside quest gen — confirm they're under a `begin_quest`
scope; if not, they join `enty`). Mixed byte-neutrality (prisoner-escape / damage
may fire on the bare turn) — instrument/count, re-baseline only if it moves.

### Unit F — mint (LAST) → `mint` stream  (tag 0x6d696e74)
`code.c rnd_alloc_num:706` (the entity-id allocator) + `add.c` id/password gen.
Key on the requesting context so a new id is a keyed leaf rather than a stream
position. This **re-bakes every entity id** → the largest re-baseline (both trees);
do it absolutely last so no later unit perturbs it. In the same PR: repoint
`test_random()` to an `rng_stream`, delete the remaining dead `rnd()` sites, and
flip the exit-gate grep on in `tests/rng/check.sh`. Once mint lands the
`scenario.tgz` saved-`randseed` coupling disappears and the engine has **zero
gameplay `rnd()`**.

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
