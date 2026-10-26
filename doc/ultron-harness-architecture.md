# Project Ultron — harness architecture

*Design / exploration. No engine code changed by this document. Companion to the
vision doc [`doc/agentic-project-ultron.md`](agentic-project-ultron.md) and the
scenario-scripting design [`doc/scripting-tool.md`](scripting-tool.md).*

## TL;DR — recommendation

Build the Ultron harness as **three separate roles with one hard rule**, not as
one monolithic Lua agent:

1. **Scenario authoring** — *reuse the existing `olyscript-g3` Lua binding.* It
   already builds deterministic pre-turn worlds via the immediate-mode GM verbs
   and is proven byte-identical by `check-lua.sh`. Nothing new here.
2. **State oracle** — *extend the in-process Lua query surface* (`oly.loc`,
   `oly.has_item` today) so an agent can ask "what is here / what does this noble
   have / what can it legally do." In-process reads are cheap and lossless;
   parsing the saved-DB text from outside is brittle and lossy.
3. **Order submission** — *the agent emits plain-text player order files*
   (`lib/orders/<faction>`) and they run through the **unmodified `-r -S` turn
   pipeline.** This is the thing under test and it must not be shortcut.

**The hard rule: Ultron orders never go through the immediate-mode binding.**
Immediate mode skips `check_allow()` (`input.c:318`; see also the GM-verb table
in [`scripting-tool.md §1.2`](scripting-tool.md)). The whole point of Ultron is
to stress the *player* order path — validation, permissions, costs, the full
`start`/`finish` lifecycle. Routing generated orders through `oly.order()` would
bypass the exact layer Ultron exists to break.

A fourth concern is **neither Lua nor order files**: **coverage instrumentation**
— a counter at the single command-dispatch chokepoint (`do_command`,
`input.c:628`). That is the actual heart of "coverage-driven" and is engine-side.

---

## 1. Why the split — the validation boundary

The current Lua layer (`olympia/lua_bindings.c`, target `olyscript-g3`) is a thin
binding over the `v_*` **immediate-mode** GM verbs ("parser path (A)"). The
load-bearing fact, from `input.c:318`:

> **No permission checks fire in immediate mode.** `check_allow()` short-circuits
> to `TRUE` whenever `immediate` is set and the verb's allow-string contains
> `'i'`.

That single fact decides everything:

- Reading state through the in-process binding is **safe and ideal** — it touches
  the live entity boxes directly.
- Writing *orders under test* through that same binding is **wrong** — it skips
  the validation, permission, and cost machinery that Ultron is trying to
  exercise. A bug that only manifests as "this order should have been rejected
  but wasn't" is invisible if the order never reaches `check_allow()`.

So queries go in-process; orders-under-test go out as text and through the real
turn runner.

## 2. The three roles in detail

| Role | Mechanism | Status | Reference |
|------|-----------|--------|-----------|
| Scenario authoring | Lua immediate binding | **exists** | `lua_bindings.c`, `check-lua.sh` |
| State oracle | Lua query binding (extend) | partial | `oly.loc`/`oly.has_item` |
| Order submission | plain text order files → `-r -S` | engine native | `order.c:248` |
| Coverage tracking | counter at `do_command` | **new** | `input.c:628` |

### 2.1 Scenario authoring (reuse as-is)

`guard-pillage.lua` already demonstrates the pattern: `oly.load()` →
`extract_startlocs()` → `add_player()` → `poof`/`additem`/`guard`/`order` →
`save()`, producing a frozen pre-turn `lib` that runs a turn byte-identically to
the shell-built scenario (`check-lua.sh` vs `check.sh`).

Ultron's **Scenario Injection** archetypes (resource shortages, excessive wealth,
isolated empires — see the vision doc) are exactly this: GM-authored starting
conditions. They belong on the immediate-mode binding, because at *authoring*
time we *want* the no-permission-check god mode. This is unchanged from the
scenario-scripting work.

### 2.2 State oracle (extend the query surface)

Ultron's central question is *"what game systems have not been exercised, and
what can this noble legally do this turn?"* The first half is coverage stats
(§2.4); the second half is a **read against live state**.

Today the query surface is two functions (`oly.loc`, `oly.has_item`). To drive
coverage-targeted order selection an agent wants, roughly:

- **location / topology** — where is a unit, what's adjacent, what sublocations
  and routes exist (to drive Explorer / movement coverage).
- **inventory & resources** — items, gold, NP, men (to drive Accountant /
  logistics / economic coverage).
- **skills & capabilities** — what a noble knows, what it could study (to drive
  Mad Scientist coverage).
- **neighbors & factions** — who else is here / known (to drive diplomacy &
  espionage coverage — the lowest-usage systems in the vision doc's table).

These are all reads. They do not perturb the RNG streams (#25) and do not touch
`check_allow()`. Building them as `oly.*` query functions keeps the agent's view
**lossless and in sync with engine truth** — strictly better than re-parsing the
`fact/`/`loc/` save text out of process.

> Open question for §6: *how much* of the order grammar's legality should the
> oracle pre-compute vs. let the agent attempt-and-observe. Attempting illegal
> orders on purpose is itself coverage (+50 for a validation failure), so the
> oracle should inform selection, not gate it.

### 2.3 Order submission (text files, real pipeline)

Order files are plain text, one order per line (`order.c:248`):

```
<unit_id>:<order string>
<unit_id>:<order string>
```

Written to `lib/orders/<faction_id>`, loaded by `load_player_orders()`
(`order.c:260`) → `queue_order()`, and executed by the normal turn runner
(`olympia-g3 -r -l ./lib -S`). Every order then flows through
`do_command()` → `check_allow()` → `start`/`finish` like any real player's.

**Ultron's job is to write these files.** Whatever picks the orders (§3) emits
text; the unmodified engine consumes it. This has three payoffs:

- **It tests the real path.** Validation failures and engine exceptions — the
  highest-value coverage events (+50 / +100) — only happen here.
- **It is reproducible.** Post-#25 a turn is a pure function of
  `(master seed, order files)`. "Produces reproducible test scenarios" is a
  literal Ultron success criterion, and it falls out for free.
- **It avoids stream perturbation.** Generating orders via the immediate binding
  *in the same process as a turn* is exactly the global-`rnd()` perturbation risk
  flagged for scenario allocation in `scripting-tool.md`. Text-in / turn-process
  -out sidesteps it.

### 2.4 Coverage instrumentation (engine-side, the real heart)

Every command — immediate or turn — funnels through one place:

```c
/* olympia/input.c:628 */
do_command(struct command *c)
{
        ...
        else if (!check_allow(c, cmd_tbl[c->cmd].allow))   /* :646  rejected   */
                c->status = FALSE;
        else if (cmd_tbl[c->cmd].start == NULL)            /* :650  unimpl     */
                ...
        else {
                p_player(player(c->who))->cmd_count++;     /* :659  already!   */
                ...
                c->status = (*cmd_tbl[c->cmd].start)(c);    /* :668  executed   */
        }
```

There is already a per-turn `cmd_count++` here. A coverage counter is the same
move at finer grain: key on `cmd_tbl[c->cmd].name` (the system) and record the
outcome — **rejected** (`check_allow` failed), **executed-ok** (`status` true),
**executed-fail** (`status` false). That single hook yields the vision doc's
usage table:

| System | Last Used | Usage Count |
|--------|-----------|-------------|

Emit it as a small machine-readable file at end of turn (alongside the reports).
This is the feedback signal that closes the loop: the harness reads it to choose
*next* turn's coverage targets. It is independent of Lua and of the order format.

> Note: `do_command` is the right grain for *which verb fired*. Finer system tags
> ("diplomacy", "espionage") that group several verbs can be a static
> verb→system map maintained next to `cmd_tbl`, not new per-verb hooks.

## 3. The one real decision — where the agent brain lives

Roles §2.1–§2.4 are settled. The open architectural choice is where the
**decision logic** lives — the archetypes (Bureaucrat, Chaos Goblin, …),
coverage scoring, and order selection.

### Option A — in-process Lua agent

Engine + Lua host in one binary. Lua queries live state (§2.2), decides, writes
the order file, the turn runs.

- **Pro:** single binary, fully deterministic, cheapest possible queries, reuses
  the existing host.
- **Con:** logic is pinned to the Lua subset targeted for the future `gopher-lua`
  Go port (`third_party/lua/VERSION` notes the 5.1-subset intent). LLM-driven or
  richly stateful archetypes (Chaos Goblin) are awkward to embed. Mixing decision
  logic into the host muddies the byte-identical authoring guarantee.

### Option B — out-of-process harness

The engine runs a turn and emits a state snapshot + coverage file; an external
harness (Python / an LLM agent / anything) reads them, selects coverage-targeted
orders, writes order files, loops.

- **Pro:** decision logic can be anything; engine stays clean; archetypes and
  scoring evolve without touching C; natural fit for "submit unusual but legal
  orders at industrial scale."
- **Con:** needs a clean machine-readable **state export**, and care to keep the
  exported view from drifting from engine truth.

### Recommendation — hybrid

Keep **Lua as the in-process state oracle + scenario builder** (§2.1, §2.2) and
put the **decision logic out of process** (Option B), communicating purely
through *(state snapshot in → order files out)*. Concretely:

- The oracle can be surfaced two ways from the same bindings: called in-process
  by a thin Lua "dump current state to JSON/TSV" script, or — if we never need
  in-process branching — just a `-state-export` mode on the engine. Either way
  the *export format* is the contract, not the language.
- The brain reads `(state export, coverage file)`, applies an archetype to pick
  orders, writes `lib/orders/*`, and invokes the unmodified turn runner.

This keeps orders on the validated path, keeps the engine clean, doesn't pin
Ultron's brain to the Lua subset, and preserves `(seed, orders)` reproducibility.

## 4. The loop, end to end

```
            ┌─ (once) scenario authoring ──────────────────────┐
            │  olyscript-g3 <archetype-scenario>.lua  →  lib/   │  (GM, immediate)
            └──────────────────────────────────────────────────┘
                                   │
      ┌────────────────────────────▼─────────────────────────────┐
      │  per turn:                                                 │
      │   1. state export      lib/ ──────────► state.{json,tsv}   │  (read-only)
      │   2. brain (out-of-proc): state + coverage ► pick orders   │  (archetype)
      │   3. write order files                  ► lib/orders/*     │  (plain text)
      │   4. run turn          olympia-g3 -r -l lib -S            │  (real path!)
      │   5. read coverage     --coverage ────► coverage.tsv       │  (do_command)
      │   6. score + choose next-turn targets                     │
      └──────────────────────────────────────────────────────────┘
                                   │ repeat
```

Steps 1, 4, 5 are engine/Lua; steps 2, 3, 6 are the out-of-process brain. The
engine is touched only for the read-only oracle (§2.2) and the coverage hook
(§2.4) — both additive and both byte-neutral on the existing golden trees (reads
and a counter perturb no output).

## 5. Why this is well-timed (post-#25)

Ultron was explicitly gated on #25 (RNG-state granularity), now complete. The
payoff is direct: a turn is a pure function of `(master seed, order files)`, so
every Ultron-discovered defect is **reproducible from those two inputs alone** —
no hidden global-stream coupling, no re-bake of unrelated subsystems when the
agent reorders draws. A reproduced failure can be frozen as a small regress
fixture exactly like `guard-pillage` and `trade-routes` (both are
`(scenario, orders) → hashed manifest` already). Ultron's "automated defect
reproduction" / "reproducible test scenarios" criteria are essentially the
fixture pattern the repo already runs.

## 6. Open questions

1. **State-export format & scope.** JSON vs TSV; how much topology/legality to
   pre-compute vs. let the brain attempt-and-observe (attempting illegal orders
   is itself coverage). Smallest useful export first.
2. **Verb→system grouping.** The static map that turns `cmd_tbl` names into the
   coverage table's coarse systems (diplomacy, espionage, logistics, …).
3. **Coverage-score bookkeeping.** Where the cross-turn usage stats live (the
   brain's state, not the engine's) and how "previously untested interaction"
   (+25) is detected.
4. **Archetype representation.** Data-driven (weights over verb/system classes)
   vs. coded strategies; whether an LLM picks orders or only picks *targets* a
   deterministic selector then expands.
5. **Multi-faction / multi-agent turns.** The vision doc's long-term multi-agent
   diplomacy — out of scope for the first cut but the loop in §4 already supports
   N order files per turn.

## 7. First-cut scope (proposed)

Smallest end-to-end slice that proves the architecture, in dependency order:

1. **Coverage hook** at `do_command` + a `coverage.tsv` dump (engine-side,
   byte-neutral). Immediately useful even before any agent — it answers "what did
   *today's* golden turn exercise." **✅ Done** (#98, #100) — see
   [§7.1](#71-coverage-hook--landed).
2. **State export** — a minimal read-only dump (location, inventory, skills) via
   the oracle bindings or a `-state-export` mode. **✅ Done** (#104) — see
   [§7.2](#72-state-export--landed).
3. **A trivial brain** — one archetype (the Chaos Goblin is the cheapest: pick
   legal-ish orders at random) writing order files out of process. **✅ Done**
   (#105) — see [§7.3](#73-chaos-goblin-brain--landed).
4. **Loop driver** wiring §4 steps 1–6, and freezing any crash as a regress
   fixture. **✅ Done** (#106) — see [§7.4](#74-loop-driver--landed).

Each step is independently testable and the first two are valuable on their own.

### 7.1 Coverage hook — landed

`olympia-g3 ... --coverage <path>` (#100) writes `coverage.tsv` to `<path>` at the
end of the run; `run/olympia-g3.sh` passes it through from `OLYMPIA_COVERAGE`.
Without the flag nothing is counted or written, and every golden tree stays
byte-identical. Keep the path outside `lib/`, which the gates hash.

`do_command()` reports each dispatch to `coverage_count()` (`olympia/coverage.c`,
#98). Decisions taken in the first cut:

- **Outcomes** (columns): `rejected` (`check_allow()` failed), `unimplemented`
  (`start == NULL`), `ok` / `fail` (what `start` returned). Finish and interrupt
  outcomes are not counted yet.
- **Turn-runner commands only.** Commands run in immediate mode (`-i`,
  `olyscript-g3`) are not counted: they skip `check_allow()`, so they say nothing
  about the player order path. For example, the GUARD that `guard-pillage.lua`
  sets up does not show.
- **Every verb gets a row**, sorted by name, including verbs that never fired.
  Unrecognized commands have no verb; they are counted on the `cmd_tbl[0]`
  placeholder and written as `(unrecognized)`, under `rejected`.

**Baseline (2026-10-24).** Across the main golden turn and both olympia regress
trees, only **4 of 147 verbs fire**, all with outcome `ok`; nothing is rejected
and nothing fails:

| Tree | Verbs fired (count) |
|------|---------------------|
| main golden turn | `move` 25, `wait` 25 |
| guard-pillage | `move` 25, `wait` 25, `pillage` 1 |
| trade-routes | `move` 15, `wait` 15, `use` 1 |

The `move`/`wait` rows are NPC and savage orders. Every other verb, and every
`rejected`/`fail` path, is unexercised: that list is the fixture backlog ahead of
the Go port, tracked per verb and outcome in
[`tests/ultron/backlog.tsv`](../tests/ultron/README.md).

### 7.2 State export — landed

`olympia-g3 ... --state-export <path>` (#104) writes a JSON snapshot of what each
regular player faction can act on. It is the engine-mode form of the oracle; the
format below is the contract, so a Lua dump through the `oly.*` bindings can
produce the same file later if in-process branching is ever needed.

- **When.** At the end of `main()`, after `save_db()`, so nothing it touches can
  reach the saved database. It only reads and draws no random numbers. With `-r`
  it shows the post-turn state; without (`olympia-g3 -l lib --state-export
  <path>`) it shows the state the next orders will run against.
- **Opt-in**, like `--coverage`: without the flag nothing is written. Keep the path
  outside `lib/`.
- **Deterministic**: every list is in entity-id order. Names are 8-bit, so bytes
  outside printable ASCII are written as `\u00XX` (read as Latin-1).
- **Note:** every engine run rewrites `lib/times_0` (the Times masthead), with or
  without this flag. Pass `test-use-const-report-date`, or export from a scratch
  copy of `lib`, when the tree must stay untouched.

```json
{"turn": 2, "factions": [
  {"id": 400, "name": "Trade Test",
   "units": [
     {"id": 4126, "name": "…", "where": 10113, "stacked_under": 0,
      "items":  [{"id": 1, "name": "gold", "qty": 200}],
      "skills": [{"id": 730, "name": "Trade"}]}],
   "locations": [
     {"id": 10113, "name": "", "kind": "loc", "subkind": "plain",
      "depth": "province", "province": 10113,
      "exits": [{"direction": "north", "destination": 10013, "distance": 2,
                 "road": 0, "impassable": 0, "hidden": 0}],
      "here":  [{"id": 4126, "name": "…", "faction": 400}]}]}]}
```

| Field | Meaning |
|---|---|
| `units[].where` | the unit's immediate location or ship (`subloc()`) |
| `units[].stacked_under` | the unit it is stacked under, or 0 if it leads its own stack |
| `units[].skills` | skills it knows (`SKILL_know`), not ones in progress |
| `locations` | every location the faction's units are in |
| `exits` | the exits the faction's lowest-numbered unit there can see; exits hidden from it are left out |
| `exits[].direction` | `north` … `out`, or `road` for a road |
| `exits[].hidden` | 1 for a hidden destination the unit knows about |
| `here[].faction` | the owning faction of each character present |

Faction relations (attitudes, allies) and studyable-skill lists are not in the
first cut.

### 7.3 Chaos Goblin brain — landed

`tests/ultron/brain/chaos_goblin.py` (#105) is the first brain: Python 3, standard
library only, out of process. It reads the state export, `backlog.tsv` and, if
given, the latest `coverage.tsv`, and writes `lib/orders/<faction>` for every
faction in the export. Usage and details are in its
[README](../tests/ultron/brain/README.md). Decisions taken in the first cut:

- **One pick per order, over `(verb, outcome)` cells.** A cell weighs more when
  its backlog cell is `todo` or the coverage dump counts it zero. Alias verbs
  weigh half; the `gm-immediate` and `directive` families are skipped, and `die`
  and `quit` are excluded by default (#110). `--exclude`/`--allow` take
  comma-separated or repeated verbs to change that without editing the script.
- **The picked outcome shapes the order.** `ok` uses arguments from the state;
  `rejected` issues the order from an entity the `allow` string leaves out (the
  faction for a unit verb), since `check_allow()` keys on the issuer's kind; `fail`
  garbles the arguments. This answers open question 1's legality half: the brain
  attempts and observes, and the state only informs the pick.
- **Seeded:** the same seed and inputs give byte-identical order files.
- `tests/ultron/brain/check.sh` checks reproducibility and that a turn on the
  goblin's orders exits 0 and fires more than the baseline verbs.

**First rounds (2026-10-24).** One turn per seed for seeds 1–40 at 20 orders per
unit fired 110 verbs on each of trade-routes and guard-pillage (baseline: 3 and
4), reaching `rejected` and `fail` as well as `ok`. Nothing crashed, and seeds
1–20 ran clean under ASan/UBSan. Driving this across turns and freezing any crash
as a fixture is step 4 (#106).

### 7.4 Loop driver — landed

`tests/ultron/loop.py` (#106) runs the whole loop in one command:

```bash
tests/ultron/loop.py --scenario tests/olympia/regress/trade-routes/scenario.tgz \
                     --turns 5 --seed 1 [--preset asan-ubsan] [--orders-per-unit 8]
```

- **Scenario.** A `scenario.tgz`, or an `olyscript-g3` `.lua` run on the
  bare-map fixture (`tests/olympia/fixtures/lib.tgz`), the way `check-lua.sh`
  does. It is unpacked into the work directory, by default
  `run/ultron/<scenario>-s<seed>` (git-ignored). An existing work directory needs
  `--force`, and one under `tests/` is refused, so the golden trees are never
  written.
- **Per turn** it keeps `turn-NNN/{state.json, orders/, coverage.tsv, turn.log}`.
  The brain seed for turn *t* is `seed × 1000003 + t`. The brain's `--coverage`
  is `coverage-total.tsv`, the sum over the turns so far, so each turn steers away
  from what earlier turns already hit (step 6). Turn 1 is steered by the backlog
  alone.
- **Failures** are a non-zero exit, a signal, an assert message, any ASan/UBSan
  diagnostic, a run past `--timeout` (600 s), or a missing export or coverage
  file. The state export run is checked the same way as the turn. On the first
  failure the loop stops and freezes `fixtures/<name>/`, named
  `ultron-<scenario>-s<seed>-t<turn>-<signature>` (for example
  `…-t002-assert-code.c-42` or `…-asan-heap-buffer-overflow`). The fixture holds:
  - `scenario.tgz`: the pre-run `lib` with its order files
  - `orders/`: those order files, for reading
  - `meta.json`: the signature and the exact engine arguments
  - `failure.log`: the engine's output
  - `check.sh`: replays the run through `loop.py --replay` and prints `YES` while
    it still fails with the same signature

  To promote one, move it under `tests/olympia/regress/` and turn `check.sh` into
  a pinned check once the bug is fixed.
- **Summary.** At the end it prints the backlog `todo` cells that the run hit
  at least once, and writes them to `newly-hit.tsv`.
- **Brain flags.** `--exclude` and `--allow` (comma-separated or repeated) are
  passed through to the brain, e.g. `--exclude wait,move --allow die` (#110).
- **Testing the freeze.** `--inject TURN:FACTION:UNIT:ORDER` appends a raw order
  line after the brain. `--engine tests/ultron/inject-crash.sh` runs the real
  engine but aborts like a failed assert on any `ultron-crash` order. Together
  they plant a crash that depends only on the order files.
  `tests/ultron/check-loop.sh` uses them, and also checks that two runs with one
  seed give identical per-turn orders, state and coverage.

**First runs (2026-10-24).** Three turns of trade-routes at seed 1 fired 22 verbs
and hit 21 backlog `todo` cells. Four turns of `guard-pillage.lua` at seed 3, 20
orders per unit, on `asan-ubsan`, fired 83 verbs and hit 104 `todo` cells (21
`ok`, 42 `rejected`, 41 `fail`). Both ran clean.

### 7.5 Use coverage — landed

The verb hook counts every `use` in one `use` row, whatever it dispatched: 135
`use_tbl` skills and 15 item use keys. `olympia-g3 ... --use-coverage <path>`
(#181) writes a second dump, `use-coverage.tsv`, counted inside `v_use()` and
`v_use_item()` (`olympia/use.c`, `olympia/coverage.c`). `run/olympia-g3.sh`
passes it through from `OLYMPIA_USE_COVERAGE`. Like `--coverage`, it is opt-in
and changes nothing under `lib/`.

- **Rows:** one per `use_tbl` skill (`kind` `skill`, `key` the skill id), sorted
  by id, then one per item use key (`kind` `item`, `key` the use key from the
  `use_*` defines in `oly.h`), plus one `invalid` row. An item is counted by its
  use key, not its id, because unique items such as the palantir are minted per
  game. `name` is the skill's name from the database, or the use key's name.
- **`invalid`** counts a target with no row: not a box, a skill school, a skill
  with no `use_tbl` entry, or an item with use key 0. A scroll used by its item
  number is redirected to the spell it holds, so it is counted on that skill.
- **Outcomes:** `checks` (a shared check failed before dispatch: skill or
  school not known, magic in a safe haven, unmet requirements; for items, not
  held or a safe haven), `ok` and `fail` (what the skill's start function, the
  `skill_produce` path, or the item's use function returned). Keeping `checks`
  apart means a "does not know" can't fill a skill's own `fail` cell.
- **Start time only**, like the verb hook, and turn-runner commands only.
- **Invariant:** every `use` the verb dump counts as `ok` or `fail` is counted
  in exactly one row here, so the rows sum to the `use` row's `ok` + `fail`.

The per-skill and per-item cells are tracked in
[`tests/ultron/use-backlog.tsv`](../tests/ultron/README.md#the-use-backlog), under
parent issue #180. A fixture asserts its cells with `use_cells` from
`tests/olympia/fixtures/coverage.sh`.

**Baseline (2026-10-25).** Across the main golden turn and every regress
fixture, `use` reaches only 2 of 150 rows: `incite_mob` (675) `ok` in
social-bribe and `find_buy` (733) `ok` in trade-routes. skills-refused also
reaches `invalid`.

### 7.6 Phase coverage — landed

The verb and use hooks only see commands. A turn also runs work that no command
starts: the day-0 NPC setup in `process_orders()`, trade matching on day 1,
`daily_events()` and `post_month()` (see
[turn-execution-order.md](turn-execution-order.md)). `olympia-g3 ...
--phase-coverage <path>` (#227) writes a third dump, `phase-coverage.tsv`,
counted inside those routines (`olympia/coverage.c`, rows in `ph_rows[]`,
enum `PH_*` in `oly.h`). `run/olympia-g3.sh` passes it through from
`OLYMPIA_PHASE_COVERAGE`. Like the other dumps it is opt-in, draws nothing and
changes nothing under `lib/`: all 79 regress fixtures and the golden turn are
byte-identical with it on.

- **Rows:** one per thing a routine can do (`event`), in turn execution order,
  with columns `phase` (`day0`, `day1`, `daily`, `month`), `routine`, `event`,
  `ran`, `acted`. A routine that can do several distinct things gets a row for
  each: `loyalty_decay` has `decay`, `release` (a summoned unit is let go) and
  `desert`; `heal_characters` has `heal`, `sicken` and `recover`.
  `queue_npc_orders` has a row per NPC program it dispatches.
- **`ran`** counts calls of the routine and is repeated on each of its rows.
  `check_token_units` runs at day 0 and at month end, so it counts both.
  `post_production` counts only its `post_month()` call, not the one-time call
  on loading a fresh world (`io.c`).
- **`acted`** counts each time the routine did that thing to one entity
  (healed a unit, collected a castle's tax, spawned an NPC). A routine that is
  called but finds nothing to do shows `ran` > 0 and `acted` 0.
- **Turn-runner only**, like the other hooks: immediate mode is skipped.

The cells are tracked in
[`tests/ultron/phase-backlog.tsv`](../tests/ultron/README.md#the-phase-backlog).
A fixture asserts its cells with `phase_cells` from
`tests/olympia/fixtures/coverage.sh`.

**Baseline (2026-10-25).** The bare-map golden turn acts in 9 of 75 rows: the
Hades and faery spawns and their units, garrison guards, natural weather, the
city-tax move, unformed minting, storm weakening, post-production and link
opening. With the regress fixtures, 39 rows are reached. The 36 that no fixture
reaches include every NPC program, trade matching, garrison pay and tax
forwarding, desertion, relic, ghost and body decay, temples, animal deaths and
the month-gated routines (`special_locs_open/close`, `auto_drop`).

The dump's first finding was a bug: `natural_weather` ran 6 times on the
golden turn, not the 4 its comment says. `daily_events()` sorts only the first
4 of the 30 shuffled weather days, but `wday_index` kept walking into the
unsorted rest. It was fixed in #229 (PR #231), so it now runs 4 times
(storms 9708 → 6472).
