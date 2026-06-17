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
      │   5. read coverage     lib/ ──────────► coverage.tsv       │  (do_command)
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
   *today's* golden turn exercise."
2. **State export** — a minimal read-only dump (location, inventory, skills) via
   the oracle bindings or a `-state-export` mode.
3. **A trivial brain** — one archetype (the Chaos Goblin is the cheapest: pick
   legal-ish orders at random) writing order files out of process.
4. **Loop driver** wiring §4 steps 1–6, and freezing any crash as a regress
   fixture.

Each step is independently testable and the first two are valuable on their own.
