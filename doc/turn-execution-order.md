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
> 2. `auto_hades()`
> 3. A `loop_units(indep_player, …)` pass dispatching each independent unit to its
>    `npc_program` / `subkind` behavior (`auto_unsworn`, `auto_undead`,
>    `auto_savage`, `auto_mob`, `auto_bandit`, `npc_move`). Units already running
>    or already queued are skipped (`npc.c:623-627`).

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

- `curse_erode_day = rnd(1, MONTH_DAYS)` (`day.c:1819`) — **global** (magic)
- `faery_day = rnd(MONTH_DAYS/2, MONTH_DAYS)` (`day.c:1822`) — **global** (region:faery)
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
if (day == faery_day)      auto_faery();
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
| Each day, after commands | `daily_events()` day picks (`curse_erode`/`faery`/`dog_bark`) | **global** `rnd()` (magic / region:faery / stealth residuals) |
| Per-pillage / undead / storm | `do_cookie_npc()` troop count when `man_kind` set | **keyed** per-location, `begin_npc(where)` (`npc.c:575`) — *not reached on the standard turn* |
| Combat (only if a battle occurs) | `begin_battle()` / `crnd()` | **keyed** per-battle (combat migration) |
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
- The keyed-stream seam is `lib/rng.{c,h}`; the per-subsystem migration order is
  in [rng-state-granularity.md](rng-state-granularity.md).
