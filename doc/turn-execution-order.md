# Turn execution order

A reference for **when** the engine runs things during a turn — the fixed phase
order the driver walks, independent of how players queue their orders. It exists
because the #25 RNG-granularity work keeps tripping over *when* a given `rnd()`
draw fires (e.g. savage-fort spawn checks running on the bare-map standard turn).

Scope: the order the engine *processes* work. Order *parsing/queueing* (the
priority sort, `wait`/poll semantics, the day-by-day command state machine) is
summarized only as far as needed to place the draws. Everything below is for a
run-a-turn invocation (`olympia-g3 -r`, plus `-S` to save) — `main.c:803`.

All references are `file:line` at the time of writing; treat them as anchors, not
guarantees.

---

## Top level — `main()` run-a-turn block

`olympia/main.c:803-840`. After `load_db()` (`main.c:791`), the run path is a
flat, fixed sequence:

```
process_orders();        // the turn itself — see below
post_month();            // end-of-month settlement — see below
                         // (show_day toggles off here)
determine_output_order();
turn_end_loc_reports();
list_order_templates();
player_ent_info();
character_report();
player_banner();
charge_account();        // only if -A (acct_flag)
report_account();
summary_report();
player_report();
scan_char_skill_lore();
show_lore_sheets();
gm_report(gm_player);
gm_show_all_skills(skill_player);
add_new_players();
gen_include_section();    // "must be last"
... write_* output files ...
```

Then `check_db()` and, if `-S`, `save_db()` (`main.c:855-858`).

Everything that mutates game state for the turn happens in the first two calls:
**`process_orders()`** (the days) and **`post_month()`** (end-of-month
settlement). The rest is reporting and output and does not draw from the game
RNG.

---

## `process_orders()` — the turn

`olympia/input.c:1036-1080`. Two parts: a one-time **setup / day-0** block, then
the **daily loop** over `MONTH_DAYS`.

### Setup and day 0 (runs once, before day 1)

In order (`input.c:1044-1062`):

1. `init_locs_touched()`
2. `init_weather_views()`
3. `olytime_turn_change(&sysclock)` — advances the clock into the new turn
4. `init_wait_list()` — seeds the wait list from in-flight `wait` commands
5. `init_collect_list()`
6. `initial_command_load()` — every char and player gets its command loaded into
   the priority queues (`input.c:727`; calls `init_load_sup` per entity)
7. **`queue_npc_orders()`** — NPC behavior is queued here (see below). **This is
   where savage-fort spawn checks fire.**
8. `ping_garrisons()`
9. `check_token_units()`  *(marked "XXX/NOTYET — temp fix")*
10. `process_interrupted_units()` — "happens on day 0" (`input.c:1059`); pops a
    `stop` order and interrupts the current order for each affected unit
11. `process_player_orders()` — runs all **player-entity** (`T_player`) orders,
    which are zero-time control orders (`input.c:943`)
12. `scan_char_item_lore()`

> **NPC queueing — `queue_npc_orders()`** (`olympia/npc.c:606`). Order matters
> for RNG:
> 1. `init_savage_attacks()` (`savage.c:352`) — loops **every** `LOC_build`
>    location (forts). For each fort it calls `begin_npc(fort)` then
>    `npc_spawn(fort, 0, 1, 100)`, i.e. an `rnd(1,100)` spawn check **per fort,
>    every turn**, keyed on the fort (#25). The bare-map standard turn has 243
>    forts, so this is 243 keyed draws on the standard manifest even though no
>    savages end up spawning. This is the "surprise" draw.
> 2. `auto_hades()` — spawns up to 25 Hades "nasties" (`create_hades_nasty`) per
>    turn. Since #25 step 12 these draw from the keyed per-turn **region:hades**
>    stream (tag `hads`, `begin_hades()` / `hads_nasty`, the auto-spawn slot in the
>    leaf key); 25 spawns × ~2–3 draws fire on the bare-map turn (NOT byte-neutral).
> 3. A `loop_units(indep_player, …)` pass dispatching each independent unit to its
>    `npc_program` / `subkind` behavior (`auto_unsworn`, `auto_undead`,
>    `auto_savage`, `auto_mob`, `auto_bandit`, `npc_move`). Units already running
>    or already queued are skipped (`npc.c:623-627`). The hades/faery **bandit
>    ambush checks** (`hades_attack_check`/`faery_attack_check`, fired from
>    `move.c` when a char enters Hades/Faery) also draw from the region streams
>    since #25 step 12 (`hads_ambush`/`faer_ambush` etc.); the trigger roll fires
>    per mover (the spawned NPCs move, so ~25/15 trigger draws on the bare map) but
>    no bandit spawns there (the roll passes only 6% of the time, and NPC movers
>    short-circuit).

### The daily loop

`input.c:1065-1076`. While `sysclock.day < MONTH_DAYS`:

```
olytime_increment(&sysclock);          // advance to the next day
if (sysclock.day == 1) match_all_trades();
daily_command_loop();                  // run today's commands
daily_events();                        // run today's scheduled events
```

So each day is **commands first, then events**, and trade matching happens once,
at the start of day 1.

#### `daily_command_loop()` — `input.c:932`

```
auto_attack_flag = TRUE;
start_phase();        // the day's command execution
evening_phase();      // end-of-day completion checks
clear_second_waits();
```

- **`start_phase()`** (`input.c:813`) drains the priority queues. It repeatedly
  finds the lowest ready priority (`min_pri_ready()`, `MAX_PRI == 5`,
  `input.c:9`), sorts that priority's load queue (`sort_load_queue`), and runs
  each command via `do_command()`. After each command it runs
  `check_all_waits()`, and it breaks to re-evaluate priority whenever a started
  command lowers `cur_pri`. **Auto-attacks** (`check_all_auto_attacks()`) fire
  once per day, gated to run only once `pri >= 3` so they never precede a
  lower-priority command (`input.c:831-835`).
- **`evening_phase()`** (`input.c:870`) sorts the run queue and calls
  `finish_command()` on each still-running command — the daily "are you done
  yet?" completion pass (`days_executing++`, finish routine, wait decrement).

A single command's lifecycle: `do_command()` (`input.c:628`) calls the command's
`start` routine, and if it's zero-wait, `finish_command()` immediately; otherwise
the `finish` routine runs in later evening phases when `wait` hits 0 or each
evening if `poll` is set (`input.c:614-618`). State machine is
`STATE_LOAD → STATE_RUN → STATE_DONE`.

#### `daily_events()` — `day.c:1810`

Scheduled, day-conditioned effects. **First-call RNG draws** pick the random days
for the month (these fire the first time `daily_events` runs, i.e. day 1):

- `curse_erode_day = rnd(1, MONTH_DAYS)` (`day.c:1819`) — **global** (magic) — a
  **deliberate magic residual**: the magic migration (#25, tag `magc`) keyed the
  player-cast spell draws but left this turn-auto day-pick global, since it fires
  every turn and would move the main manifest (`noncreator_curse_erode()` itself
  draws nothing)
- `faery_day = rnd(MONTH_DAYS/2, MONTH_DAYS)` (`day.c:1822`) — **global** (region:faery)
  — the **day-pick stays global** (a turn-auto schedule pick that fires every turn,
  like `curse_erode_day`); only `auto_faery`'s *behavior* draws moved onto the
  keyed `faer` stream (#25 step 12, below)
- `dog_bark_day = rnd(1, MONTH_DAYS)` (`day.c:1825`) — **global** (detection/stealth)
- `weather_days`: built `1..MONTH_DAYS`, shuffled, then the first 4 `qsort`ed
  (`day.c:1827-1838`) — the shuffle now draws from the **keyed** weather stream
  (`wthr_shuffle` → `ilist_shuffle_rng`, #25), not the global `rnd()`

Then, every day in order (`day.c:1840-1868`):

```
default_garrison_pay();
ship_coastal_damage();
random_loc_damage();
check_ocean_chars();
if (day % 7 == 0) { heal_characters(); weekly_prisoner_escape_check(); }
if (day == curse_erode_day) noncreator_curse_erode();
if (day == 15)             increment_stone_ring_aura();
if (day == dog_bark_day)   dogs_bark_at_hidden_chars();
if (day == weather_days[wday_index]) { wday_index++; natural_weather(); }
if (day == faery_day)      auto_faery();   // create_elven_hunt -> keyed faer stream (#25 step 12)
```

> Mixed streams since the weather migration (#25). The **weather** draws here are
> now on the keyed per-turn weather stream (seeded once via `begin_weather()`):
> the `weather_days` shuffle, `ship_coastal_damage` and `random_loc_damage` (acute
> damage — keyed `wthr_wreck`, unreached on the bare map), and `natural_weather()`
> (the province shuffles + storm-strength rolls — the ~76.7k draws/turn that
> dominate this phase). The weekly `heal_characters()` (`day % 7 == 0`) draws
> from the keyed per-turn **upkeep** stream (seeded once via `begin_upkeep()`,
> `up_heal`, #25) — unreached on the bare map (no wounded chars). The remaining
> draws — the three day-picks (`curse_erode_day`/`faery_day`/`dog_bark_day`) —
> stay on the **global serial stream** (`rnd()`) as documented residuals for the
> magic / region:faery / stealth subsystems. Those global residuals are part of
> why reordering or adding a global draw still re-bakes the rest of the manifest.
> When `faery_day` arrives, `auto_faery()`'s `create_elven_hunt` spawns (15/turn)
> draw from the keyed per-turn **region:faery** stream (tag `faer`, #25 step 12),
> not the global `rnd()` — only the day-*pick* above stays global.

---

## `post_month()` — end-of-month settlement

`olympia/day.c:1749`. Runs once after the last day, before reporting. Fixed
order (`day.c:1754-1798`):

```
clear_orders_sent();
if (month == 2) special_locs_open();
if (month == 6) special_locs_close();
move_city_gold();
garrison_gold();
collect_taxes();
add_claim_gold();
add_noble_points();
add_unformed();
increment_current_aura();
decrement_ability_shroud();
decrement_region_shroud();
decrement_meditation_hinder();
decrement_loc_barrier();
loyalty_decay();
pillage_decay();
relic_decay();
hide_mage_decay();
inn_income();
temple_income();
charge_maint_costs();
animal_deaths();
ghost_warrior_decay();
corpse_decay();
dead_body_rot();
storm_decay();
storm_move();
collapsed_mine_decay();
post_production();
if (auto_quit_turns > 0) auto_drop();
link_decay();
quest_decay();
check_token_units();
determine_noble_ranks();
```

Several of these draw from the RNG. Since the **upkeep** migration (#25) the
per-noble gradual-maintenance draws are on the keyed per-turn upkeep stream
(seeded once via `begin_upkeep()`): `loyalty_decay` (`up_loyal`), `men_starve`
via `charge_maint_costs`/`garrison_gold` (`up_starve`), `animal_deaths`
(`up_animal`), and `corpse_decay` (`up_corpse`). All are **unreached on both
golden trees** (no eligible chars), so the migration was byte-neutral. Still on
the **global** stream as documented residuals: `inn_income` (per-structure
income → a future income subsystem; `temple_income` draws nothing). Note
`storm_decay()` / `storm_move()` draw **nothing** (pure strength decrement /
stored-direction move), so the weather migration left `post_month` untouched.
`quest_decay()` likewise draws **nothing** (a pure `quest_late` decrement loop),
so the quest migration (#25, tag `qest`) left `post_month` untouched too — quest
draws are **command-only** (the QUEST command / skull-relic use, on the keyed
per-quest stream `begin_quest()`/`qrnd()`), and a standard `-r` turn issues
neither, so the quest stream is unreached on both golden trees.

---

## RNG-relevant quick reference

Where draws happen during a standard `-r` turn, in execution order, and which
stream they're on:

| When | Call site | Stream |
|------|-----------|--------|
| Setup / day 0 | `init_savage_attacks()` → `npc_spawn()` per fort | **keyed** per-fort (#25) — `begin_npc(fort)` |
| Setup / day 0 | other `queue_npc_orders()` NPC programs | mixed (see per-subsystem migration map) |
| Each day, day 1 | `daily_events()` `weather_days` schedule shuffle | **keyed** per-turn weather — `begin_weather()` (#25) |
| Each day, after commands | `daily_events()` `ship_coastal_damage` / `random_loc_damage` (acute) | **keyed** weather `wthr_wreck` (#25) — *not reached on the bare map* |
| Weather-days | `daily_events()` → `natural_weather()` province shuffle + storm-strength rolls | **keyed** per-turn weather (#25) — the ~76.7k draws/turn that dominate the phase |
| Each day, after commands | `daily_events()` day picks (`curse_erode`/`faery`/`dog_bark`) | **global** `rnd()` (magic / region:faery / detection residuals — the *day picks*, distinct from the keyed spell/EXPLORE/SEEK commands below; `curse_erode` is the deferred magic residual) |
| Per-pillage / undead / storm | `do_cookie_npc()` troop count when `man_kind` set | **keyed** per-location, `begin_npc(where)` (`npc.c:575`) — *not reached on the standard turn* |
| Combat (only if a battle occurs) | `begin_battle()` / `crnd()` | **keyed** per-battle (combat migration) |
| Command phase (only if issued) | EXPLORE (`d_explore`/`find_lost_items`) + SEEK (`d_seek`) detect rolls | **keyed** per-turn explore — `begin_explore()` / `expl_*` (#25, tag `expl`) — *not reached on either golden tree* |
| Command phase (only if issued) | weapon training (ARCHERY/DEFENSE/SWORDPLAY), STUDY scroll-consume, RESEARCH pick/gate, TORTURE, PETTY THIEF | **keyed** per-turn skills — `begin_skills()` / `skil_*` (#25, tag `skil`, command core) — *not reached on either golden tree* |
| Command phase (only if issued) | scry/locate, religion gates, necro eat-dead/skill-transfer, MEDITATE/HEAL aura spells, alchemy potion brew/use, FORGE AURACULUM / USE orb / USE suffuse-ring crafting | **keyed** per-turn magic — `begin_magic()` / `magc_*` (#25, tag `magc`, command core + `art.c` crafting via `magc_forge`/`magc_orb`/`magc_ring`) — *not reached on either golden tree* |
| Per-turn / quest loot (restock & loot minters) | `new_suffuse_ring` (`buy.c` `trade_suffuse_ring`, per-turn economy restock), `new_orb`/`create_npc_token` (`quest.c` loot) | **keyed** (#25 endgame Unit A) — `new_suffuse_ring` → `econ_ring` on `begin_economy(where)` (fires ~25×/turn over faery/cloud cities — forced a 204-file content-only main-manifest re-baseline); `new_orb`/`create_npc_token` → `qrnd` inside quest loot gen (byte-neutral) |
| Each day (`day%7`) / end of month | `heal_characters`, `loyalty_decay`, `men_starve`, `animal_deaths`, `corpse_decay` | **keyed** per-turn upkeep — `begin_upkeep()` (#25) — *not reached on either golden tree* |
| End of month | `inn_income()` (`temple_income` draws nothing) | **global** `rnd()` (future income subsystem residual) |

Notes for #25 work:

- `do_cookie_npc()`'s troop-count draw (`npc.c:576`, the pillage residual) is
  **unreached by the bare-map standard turn** — no pillage/undead/storm cookies
  are present — which is why it shows 0 hits there.
- Combat draws only happen if a battle resolves; the standard turn runs none, so
  the combat per-battle stream is byte-neutral on the main manifest and is pinned
  separately by `tests/olympia/regress/guard-pillage`.
- **Weather is the heaviest phase on the bare map**: `natural_weather()` shuffles
  the full province list (~7.5k–10k) up to 8 times per turn plus ~6608
  storm-strength rolls — ~76.7k draws, all now on the keyed per-turn weather
  stream. Its acute-damage cousins (`ship_coastal_damage`, mine/inn calamities)
  draw **nothing** on the bare map (no rocky-coast ships, mines, or inns), so they
  show 0 hits there despite being migrated.
- **Upkeep is the inverse of weather**: every per-noble upkeep draw (healing,
  loyalty decay, starvation, animal deaths, corpse decay) is **unreached on both
  golden trees** — the bare map has no player chars, and the guard-pillage turn's
  soldiers are inventory items (its two nobles afford maintenance, are
  LOY_oath/LOY_npc, and stay at full health). So the upkeep migration is
  byte-neutral on both manifests, the combat/pillage profile.
- **Explore is command-only** (the quest/upkeep profile): the EXPLORE and SEEK
  detect rolls draw from the keyed per-turn explore stream (`begin_explore()` /
  `expl_*`, tag `expl`), but a standard `-r` turn issues neither command, so the
  stream is unreached on both golden trees and at world-init — byte-neutral, no
  re-baseline. `tunnel.c` dungeon generation (the engine's largest draw set,
  ~409,727 `rnd()`/build, fired at INIT) was **deferred to worldgen** — which has
  now landed (below) — and `stealth.c`'s torture/petty-thief skill draws to
  **skills**, which has now landed (below).
- **Skills (command core) is command-only too** (the quest/explore profile): the
  mundane skill-command draws — weapon training (`c2.c`), STUDY scroll-consume and
  RESEARCH pick/gate (`use.c`), and the TORTURE / PETTY THIEF commands inherited
  from explore (`stealth.c`) — draw from the keyed per-turn skills stream
  (`begin_skills()` / `skil_*`, tag `skil`), but a standard `-r` turn issues no
  skill command, so the stream is unreached on both golden trees and at
  world-init — byte-neutral, no re-baseline. This is a **deliberate partial**:
  the aura/magic-adjacent draws (`basic.c` meditation/heal, `alchem.c` potions)
  deferred to magic — **now landed** (below) — while the `art.c` artifact-crafting
  **commands** also landed on magic (the crafting follow-up, below). The
  `art.c` shared-infra **minters** and the `produce.c` mining/harvest residual
  have **since landed** as endgame **Unit A** (onto `qest`/`econ`); only the
  cosmetic `produce.c mage_menial_how` flavor pick stays global (deferred to
  Unit E).
- **Magic (command core) is command-only too** (the quest/explore/skills profile):
  the player-cast spell draws across six files — scrying (`scry.c`), religion
  gates (`relig.c`), necromancy eat-dead/skill-transfer (`necro.c`), the
  meditation/aura + heal spells (`basic.c`), alchemy potion brew/use
  (`alchem.c`, the last two inherited from the skills step-9 deferral), and the
  `art.c` crafting commands (FORGE AURACULUM kind+weight, USE orb, USE
  suffuse-ring, via `magc_forge`/`magc_orb`/`magc_ring` — the post-magic crafting
  follow-up) — draw from
  the keyed per-turn magic stream (`begin_magic()` / `magc_*`, tag `magc`, actor in
  the leaf key), but a standard `-r` turn issues no magic command, so the stream is
  unreached on both golden trees and at world-init — byte-neutral, no re-baseline
  (the flagged world-init mint risk did not materialize: 0 `art.c` draws at
  `-s`/`-a`/`-i`). Another **deliberate partial**: the turn-auto `curse_erode`
  day-pick (`day.c`) stays global (it fires every turn and would move the main
  manifest), and `cloud.c` defers to region:cloud — **now landed** (regions, below).
  `auto_undead` (npc autonomous behavior) and the `art.c` shared-infra minters
  (`new_orb`/`create_npc_token` → quest, `new_suffuse_ring` → economy — the last
  fires ~25×/turn) have **since landed** as endgame **Unit A** (`auto_undead` →
  `npcs` via `npc_behavior`; minters → `qrnd`/`econ_ring`).
- **Worldgen is the opposite of every command-only consumer above — it fires at
  INIT, not during the turn**, and is the engine's largest draw set. The
  non-economy city seeding (`seed.c`: city prominence, skill teaching, garrison
  size) and the dungeon/subworld generation (`tunnel.c`, ~409,727 `rnd()`/build)
  now draw from the worldgen stream (tag `wgen`): `seed.c` uses **keyed leaves**
  on a per-turn stream (`begin_worldgen()` / `wgen_prom`/`wgen_skill`/`wgen_garr`,
  location in the leaf key, the gate `wgen_gate` for `tunnel.c`'s per-city build
  decision), while `tunnel.c` uses **fresh per-location sequential streams**
  (`begin_worldgen_loc(where)` / `wseq_rnd`/`wseq_shuffle`) because a dungeon is an
  ordered recursive build — one subsystem, two draw models (the weather
  precedent). Both fire at the `-i`/`-s`/`-a` world-init that
  `./run/olympia-g3.sh` and `build-scenario.sh` run, so removing them from the
  global serial stream realigned the still-global mint draws: **NOT byte-neutral**.
  It took a **deliberate one-time re-baseline** of the main manifest (still 204
  files, content-only shift) and a `scenario.tgz` regeneration + `EXPECT.sha256`
  re-baseline of the guard-pillage tree (both `check.sh` and `check-lua.sh` agree).
  Worldgen yields no command fixture; its value is removing the largest draw set
  from the global stream and completing the INIT-seeding partition. The
  saved-`randseed` → master-seed coupling that moved the guard-pillage tree
  disappears once **mint** (step 13) lands.
- **Regions are a hybrid like worldgen — part INIT, part turn-time** (#25 step 12,
  three sibling tags `faer`/`hads`/`clud`). Each region splits two reachability
  profiles in one file: the **world BUILD** (`create_faery`/`create_hades`/
  `create_cloudlands`, fired once at the `-i`/`-s`/`-a` world-init via `io.c`,
  init-guarded `if (<region>_region == 0)`) is ordered terrain/gate/populate
  generation, so it uses a **fresh per-build sequential stream** (the `tunnel.c`
  model: `begin_<region>_build()` / `<r>seq_rnd`/`<r>seq_shuffle`); the
  **turn-time autonomous** behavior (`auto_hades`'s nasties, `auto_faery`'s elven
  hunts, the `npc.c` bandit ambushes, and the `random_hades_loc` transcend pick)
  uses **keyed leaves** on a turn-guarded per-turn stream (the explore/npc model:
  `begin_<region>()` / `hads_*`/`faer_*`, actor/location/slot in the leaf key,
  the bandit/transcend helpers exposed via `proto.h`). cloud is build-only (no
  autonomous half). Like worldgen the build halves fire at world-init → **NOT
  byte-neutral**; *unlike* the brief's expectation the autonomous halves are not
  byte-neutral either (`auto_hades`/`auto_faery` fire every turn — 25 nasty + 15
  hunt spawns + 40 ambush-trigger draws on the bare map). Both halves migrated in
  one PR under a **single deliberate re-baseline** of both trees (main manifest
  still 204 files content-only; guard-pillage `scenario.tgz` regen +
  `EXPECT.sha256`, both `check.sh`/`check-lua.sh` agree). This absorbs the
  npc-deferred bandit residuals and the magic-deferred `cloud.c`. The autonomous
  halves give future fixture addressability (a hades-ambush / faery-bandit
  fixture); the build halves yield no command fixture. After this only **mint**
  (step 13) remains.
- The keyed-stream seam is `lib/rng.{c,h}`; the per-subsystem migration order is
  in [rng-state-granularity.md](rng-state-granularity.md).
