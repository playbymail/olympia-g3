# Embedding a scripting layer for scenario authoring

*Design / exploration — investigation only, no engine code changed. Deliverable
for the prompt in [`doc/scripting-tool-prompt.md`](scripting-tool-prompt.md).*

## TL;DR — recommendation

Build a **test-only embedded Lua layer that is a thin binding over the existing
`v_*` immediate-mode handlers plus a symbolic-name registry**, vendored as a
**separate CMake static-lib target** so Lua's own sources never see the `-Werror`
ladder. Keep `-i` / `-a` working unchanged until the Lua path reaches parity
(incremental rollout behind the existing seams).

Two decisions fall out of the investigation and matter more than the language
choice:

1. **The id-recovery pain is not a language problem — it is a naming problem.**
   The brittle `awk '/^ un /{print $2}' lib/fact/300` step exists only because
   the engine *mints* random entity ids and the author can't predict them. A
   **symbolic-name → id map** ("call this noble `grok`") removes that step
   entirely, and is worth building *before* (and independently of) any language
   choice. It is the core of the smallest viable prototype.

2. **Scenario-time allocation should not draw from the global `rnd()` stream.**
   `new_ent()` → `rnd_alloc_num()` → `rnd()` advances the process-global MD5
   digest. If scenario construction shares that stream, build order silently
   perturbs ids *and* (if ever run in the same process as a turn) the turn's
   draws. Route scenario-time id allocation through an **explicit / #25-keyed
   allocator** so builds are reproducible independent of global stream position.

Why Lua over the alternatives, in one line each: a hand-extended parser DSL (a)
is a worse language at higher cost and doesn't port; a pure declarative format
(b) is the most portable and deterministic but **cannot do the query-and-branch
the prompt explicitly asks for**; Lua (c) is a real language at low embedding
cost whose *scripts* survive a Go port via `gopher-lua` even though the C glue
does not. Full trade-offs in [§6](#6-alternatives-weighed) and
[§7](#7-future-go-portability).

---

## 1. What the engine already gives us

The good news from the code survey: **immediate mode is already a command
interpreter, and the GM verbs are already the scenario-building API.** A
scripting layer does not need deep new hooks — it needs a cleaner front end over
machinery that exists.

### 1.1 The immediate-mode REPL

`immediate_commands()` (`olympia/immed.c:8`) is a stdin loop:

```c
while (1) {
        c = p_command(immediate);
        c->who = immediate;
        ...
        if ((line = getlin(stdin)) == NULL) break;     /* EOF terminates   */
        strcpy(buf, line);
        if (!oly_parse(c, buf)) {                       /* tokenize + verb  */
                printf("Unrecognized command.\n");
                continue;                               /* "error handling" */
        }
        c->pri  = cmd_tbl[c->cmd].pri;
        c->wait = cmd_tbl[c->cmd].time;
        c->state = STATE_LOAD;
        do_command(c);                                  /* dispatch v_*     */
        while (c->state == STATE_RUN) { finish_command(c); ... }
}
```

This is exactly the loop a scripting host replaces: read → parse → dispatch →
run-to-completion. Note the *only* error handling is "print `Unrecognized
command.` and continue" — there are no variables, no loops, no way to read a
return value and branch on it. That is the motivating gap.

### 1.2 The GM verbs are the binding surface

Every GM verb has allow-flag `"i"` (immediate-only) in `cmd_tbl[]`
(`olympia/glob.c:141`). Each is a `int v_x(struct command *c)` that reads
already-resolved integer args `c->a … c->h` and returns `TRUE`/`FALSE`. The ones
a scenario builder needs:

| Verb | `immed.c` | Args used | Does |
|------|-----------|-----------|------|
| `v_be` | `:73` | `c->a` | set global `immediate` = active entity (context switch) |
| `v_poof` | `:158` | `c->a` | `move_stack(c->who, c->a)` — teleport active stack to a loc/ship |
| `v_add_item` | `:116` | `c->a,c->b` | `gen_item(c->who, item, qty)` |
| `v_sub_item` | `:134` | `c->a,c->b` | remove items |
| `v_makeloc` | `:198` | `c->parse[1]` | `new_ent()` a loc/ship of a named subkind, `set_where()` it |
| `v_know` | `:248` | `c->a` | `learn_skill(c->who, skill)` |
| `v_kill` | `:306` | `c->a` | `kill_char()` |
| `v_credit` | `:424` | `c->a,c->b,c->c` | award gold / NP / items |
| `v_seed` | `:329` | — | `seed_initial_locations()` |
| `v_save` | `:277` | — | `save_db()` |
| `v_dump` | `:143` | `c->a` | `save_box(stdout, …)` — inspect one entity |

Key behavioral facts a binding must honor:

- **`be` is stateful and load-bearing.** Almost every verb operates on `c->who`,
  which inherits the global `immediate` set by the last `be`. The classic bug a
  script removes: forgetting to `be` the right noble before `additem`.
- **No permission checks fire in immediate mode.** `check_allow()`
  (`input.c:318`) short-circuits to `TRUE` whenever `immediate` is set and the
  verb's allow-string contains `'i'`.
- **Return is `TRUE`/`FALSE`.** That is the success signal a script can finally
  branch on (today `immediate_commands()` ignores it).

### 1.3 The dispatch path we can reuse

`oly_parse()` (`input.c:256`) zeroes `c->a…h`, calls `oly_parse_cmd()` to
tokenize the line into `c->parse[]` and resolve the verb via `find_command()`
(linear scan of `cmd_tbl`, exact then fuzzy), then fills `c->a…h` from
`parse_arg(c->who, c->parse[i])`. `parse_arg()` resolves a token to an entity id
via `scode()`/`code_to_int()` or a plain integer.

`struct command` (`oly.h:843`) is the unit of work: `who`, `cmd` (index into
`cmd_tbl`), `a…h` int args, `parse[]` string tokens, plus the `state`/`wait`
lifecycle fields.

**Two ways for a binding to invoke a verb**, with a clear preference:

- **(A) Reuse the parser.** Format a command string, call `oly_parse()` +
  `do_command()`. Maximum reuse, zero divergence from `-i` semantics, but you
  round-trip through text and the id↔code encoding.
- **(B) Call the handler directly.** Allocate a `struct command`, set `who` and
  `a…h` from Lua values, call the `v_*` pointer. Skips text formatting, lets Lua
  pass native ids, but must replicate the lifecycle bookkeeping
  (`pri`/`wait`/`state`, the `finish_command` loop) and `parse[]` for verbs that
  read `c->parse[1]` (`v_be` error text, `v_makeloc` subkind).

**Recommendation: start with (A).** The text path is the contract `-i` already
honors; reusing it guarantees byte-identical behavior and is the smallest
prototype. Move hot or awkward verbs (`v_makeloc`, which reads a *string*
subkind) to (B) only if (A) proves clumsy. Either way the binding is a wrapper,
not new game logic — which satisfies the "prefer reusing existing
handlers/primitives" constraint.

### 1.4 The bootstrap dance the script replaces

The guard-pillage fixture
([`tests/olympia/regress/guard-pillage/build-scenario.sh`](../tests/olympia/regress/guard-pillage/build-scenario.sh))
is the concrete pain. End to end:

1. `tar zxf fixtures/lib.tgz; rm -f lib/master` — bare map.
2. `oly -l ./lib -s </dev/null` — `extract_startlocs()` (`main.c:604`) writes
   `lib/startloc` as `<seq> <city_id> <name>` over safe-haven cities, and
   one-time world init.
3. Hand-write `act/300/Join-g3` and `act/301/Join-g3`, each **5 lines**: faction
   name, noble name, start-city *index into `startloc`*, full name, email.
4. `oly -l ./lib -a -S </dev/null` — `make_new_players()` (`add.c:288`) →
   `add_new_player()` (`add.c:162`) mints a player box and a noble, places it,
   issues starting items, saves.
5. **`awk '/^ un /{print $2; exit}' lib/fact/300`** — recover the *engine-minted*
   noble ids, because step 4 chose them via `new_ent()`.
6. Pipe an `-i` script: `be <PIL>; poof 10113; additem 12 50; be <GRD>; poof
   10113; additem 12 20; guard 1; save`.
7. Hand-write `lib/orders/300` and `…/301` as `<unit>:<order>` lines
   (`order.c` `save_player_orders` / `load_player_orders`).
8. `tar czf scenario.tgz lib` — freeze the pre-turn world; the regress runs
   `oly -r … -S` and hashes the result.

Six tools, two file formats hand-authored, one `awk` over an internal save
format, and **no error handling anywhere**. Steps 3–7 are exactly what one Lua
script should express.

---

## 2. The proposed binding API

Design goals: (1) name entities so step 5's `awk` disappears; (2) wrap the
existing verbs 1:1 so behavior matches `-i`; (3) expose enough *query* to branch.
The surface is small — the prompt's "minimal coherent API."

### 2.1 The symbolic-name registry (the keystone)

A side table mapping author-chosen names to minted ids, living only in the
scripting host (never serialized into the game db):

```
oly.name(id)            -> register/return a stable handle for an id
oly.id("grok")          -> resolve a name to its id   (error if unbound)
```

`add_player{...}` and `make_loc{...}` *return* a handle and bind the given name,
so the author writes `grok` forever after and never sees `2355`.

### 2.2 World / bootstrap

```
oly.load(libdir)                 -- load_db() equivalent; or start from a fixture
oly.extract_startlocs()          -- wrap extract_startlocs() (the -s step)
oly.seed()                       -- v_seed / seed_initial_locations()

oly.add_player{                  -- replaces Join-g3 + the -a pass
    name      = "pillager",      -- registry handle for the player box
    faction   = "Pillager Horde",
    noble     = "grok",          -- registry handle for the first noble
    noble_name= "Warlord Grok",
    start     = 0,               -- index into startloc, or "empty"
    email     = "pillager@example.com",
    full_name = "P Layer One",
}                                -- returns {player=<h>, noble=<h>}
```

`add_player` wraps `add_new_player()` (`add.c:162`) directly — *not* the
file-staging path — and binds both returned ids in the registry. That single
call subsumes guard-pillage steps 3–5.

### 2.3 Entity ops (thin wrappers over the verbs)

```
oly.be(who)                      -- v_be:    set active context
oly.poof(who, loc)               -- v_poof:  move_stack
oly.additem(who, item, qty)      -- v_add_item / gen_item
oly.subitem(who, item, qty)      -- v_sub_item
oly.know(who, skill)             -- v_know / learn_skill
oly.kill(who)                    -- v_kill
oly.credit(who, amount, item)    -- v_credit
oly.guard(who, on)               -- the `guard` order, set via the handler
oly.make_loc{subkind=, where=, name=}  -- v_makeloc, returns a handle
oly.set(who, field, value)       -- targeted setters (health, attack, …)
```

Note these take an explicit `who` and call `be(who)` under the hood, so a script
never depends on dangling global `immediate` state — fixing the
forgot-to-`be` footgun by construction.

### 2.4 Query (the new capability)

The reason to script at all — read state and branch. Thin reads over the
accessors the survey found (`kind`, `subkind`, `loc`, `box_name`, item lists,
the `loop_*` macros):

```
oly.kind(who)            oly.subkind(who)       oly.name_of(who)   -- box_name
oly.loc(who)             oly.has_item(who,it)   oly.item_qty(who,it)
oly.knows(who, skill)
oly.here(loc)            -- iterate entities at loc  (loop_here)
oly.chars_here(loc)      -- iterate T_char at loc    (loop_char_here)
oly.all(kind)            -- iterate a kind           (loop_kind)
oly.valid(who)           -- valid_box()
```

### 2.5 Orders and turn control

```
oly.order(who, "pillage 1")      -- queue_order(); replaces hand-writing lib/orders/<n>
oly.run_turn()                   -- the -r path (process_orders + post_month + …)
oly.save(path)                   -- save_db()
oly.dump(who)                    -- v_dump, for debugging a script
```

`oly.order()` wraps `queue_order()` (`order.c:160`) and writes through
`save_player_orders()` at save time, so the `<unit>:<order>` file is generated,
not hand-typed.

### 2.6 RNG (determinism-safe; see §3)

```
oly.rng(stream, lo, hi)          -- rng_draw on a named, derived stream
oly.rng_keyed(stream, k1, k2, lo, hi)
```

Scripts **never** get a binding to the global `rnd()`.

---

## 3. Determinism & the golden contract

This is the section that decides whether the tool is safe. Three sub-questions
from the prompt.

### 3.1 How scenario building touches RNG today

`new_ent()` (`code.c:736`) picks a free slot with `rnd_alloc_num()` →
`rnd(low,high)` (`lib/rnd.c:320`), which advances the **process-global MD5
digest** in place:

```c
do { MD5(digest, digest, sizeof(digest)); num = digest[0] & mask; }
while (num > range);
```

So **every entity allocation consumes the global stream**, and the id you get
depends on the exact number of prior `rnd()` calls. This is *why* guard-pillage
recovers ids by `awk` instead of predicting them, and why reordering the build
would change them.

The guard-pillage scenario is reproducible today only because (a) the seed is
loaded from `lib/randseed` and (b) the call sequence is fixed across runs. A
naive script that issues the *same* operations in the *same* order reproduces the
*same* ids — but it inherits the fragility: insert one allocation and every later
id shifts.

### 3.2 The #25 seam is the fix

`lib/rng.{c,h}` (issue #25) already provides addressable, order-independent
draws:

```c
rng_stream rng_seed(const uint32_t master[4]);                 /* root from master */
rng_stream rng_stream_of(const rng_stream *p, int key, uint32_t tag);  /* derive child */
int rng_draw(rng_stream *s, int low, int high);                /* sequential, ++counter */
int rng_keyed(const rng_stream *s, int k1,int k2,uint32_t tag,int lo,int hi); /* leaf, no counter */
void rng_master_seed(uint32_t out[4]);                          /* immutable master */
```

Combat is the first consumer (`olympia/combat.c`): `begin_battle()` roots from
`rng_master_seed()`, derives a per-turn then per-battle stream keyed on
`(turn, location)`, and `crnd()` draws from it. Crucially, that landing was
**byte-neutral on the main manifest** because the standard turn runs no combat —
the pattern to imitate.

**Recommendation for scenario-time allocation:** give the script host a
dedicated build stream derived from the master seed (e.g.
`rng_stream_of(&root, SCENARIO_KEY, TAG_BUILD)`) and either:

- **(preferred) let authors request explicit ids** where they care (the registry
  binds a name to a chosen id via `alloc_box(n, kind, sk)` directly, bypassing
  the random slot picker); or
- allocate the "don't-care" ids from the keyed build stream, so build order no
  longer perturbs the *global* stream the turn will consume.

Either way the scenario build becomes reproducible **independent of global stream
position**, and the author references names, not minted numbers.

### 3.3 Why the main golden flow is safe

The standing golden manifest is produced by `run/olympia-g3.sh` — a bare-map
`-r -S` turn that **runs no scripting**. As long as the Lua layer is a *separate
invocation path* (like `-i` today) and is never entered on the normal `-r` path,
the main turn's `rnd()` sequence is untouched and the 206-file manifest stays
byte-identical. This is the same argument that made the combat keyed-RNG landing
byte-neutral.

Scripted scenarios get their **own golden tree**, exactly like
[`tests/olympia/regress/guard-pillage`](../tests/olympia/regress/guard-pillage)
— the script builds the world, the regress runs the turn with
`test-use-const-report-date` and hashes the result. The gate model already
exists; scripting just changes *how the pre-turn `lib` is authored*, not how it's
checked.

**Hard invariant:** the scripting code must not be linked into, or reachable
from, the standard turn path. If it ships in the engine at all it must be behind
a flag that is *off* in the golden flow. (See §4 — recommended as test-only.)

---

## 4. Test-only tool vs engine feature

**Recommendation: test/build-time tool, not a shipped GM feature** — at least
until parity and demand are proven.

Rationale:

- The motivation is *test-scenario authoring*. Nothing in it needs the
  capability in the production turn engine.
- Keeping it out of the shipped path is the cleanest way to guarantee §3.3 (no
  perturbation of the golden flow): if the standard turn can't reach the Lua
  layer, it provably can't change the manifest.
- Binary size / dependency surface of the production `olympia-g3` stays
  unchanged.

Concretely, three options in increasing invasiveness:

1. **Separate executable** — a fourth target (`olyscript-g3` or similar) that
   links the engine objects + Lua + bindings. The three existing targets are
   untouched. **Preferred**: strongest isolation, zero risk to the golden flow,
   matches the existing "more targets is fine" posture (the repo already has
   three).
2. **A new CLI flag on `olympia-g3`** (e.g. `-L script.lua`) guarded so it is
   never set in `run/olympia-g3.sh`. Less isolation; Lua is now linked into the
   shipped engine.
3. **First-class GM verb** (a `v_script` that runs Lua from `-i`). Maximum reach,
   maximum risk; defer indefinitely.

Option 1 keeps the no-CI local-gate workflow simple: the existing two gates
(`golden_check.sh` and the asan-ubsan flow) never build or run the new target, so
they can't regress because of it; the *scripted* regress trees are checked the
same way guard-pillage is.

---

## 5. Dependency & build integration

### 5.1 The constraint

`olympia_compile_flags(tgt)` (`CMakeLists.txt:36`) applies the full `-Werror`
ladder **per target** via `target_compile_options(${tgt} PRIVATE …)`. Lua's own
sources will not survive that ladder (sign-conversion, shorten-64-to-32, etc.),
and BUILD_HISTORY.md's warning policy is explicit: **one flag set for the whole
project; do not relax the pairs.**

The key realization: **"one flag set for the whole project" is a policy about the
engine trio, not a prohibition on separate library tiers.** Per-target `PRIVATE`
scoping is *already* the architecture. Vendored third-party code goes in its own
target that simply never calls `olympia_compile_flags()`.

### 5.2 The plan

```cmake
# Vendored Lua — its own static lib, NOT subject to olympia_compile_flags().
add_library(lua_vendored STATIC
    third_party/lua/onelua.c)            # Lua's single-TU build
target_include_directories(lua_vendored PUBLIC third_party/lua)
target_compile_definitions(lua_vendored PRIVATE LUA_USE_POSIX)
# Deliberately no olympia_compile_flags(): keep the -Werror ladder off Lua.
# If desired, a tiny olympia_vendor_flags() may add -w / targeted -Wno-* only.

# The scripting target: engine objects + bindings + Lua.
add_executable(olyscript-g3
    olympia/lua_bindings.c               # the thin wrapper layer (new)
    ${OLYMPIA_ENGINE_SOURCES})           # shared with olympia-g3
olympia_compile_flags(olyscript-g3)      # ladder applies to OUR code only
olympia_enable_sanitizers(olyscript-g3)
target_link_libraries(olyscript-g3 PRIVATE lua_vendored)
```

This disturbs nothing in `olympia-g3` / `mapgen-g3` / `island-g3`: their flag
calls, their sources, and both golden gates are unchanged. Our binding file
(`lua_bindings.c`) *does* take the full ladder — it's our code and should.

**Pin the version: Lua 5.4.7** (latest stable 5.4; single-translation-unit
`onelua.c` build keeps the CMake trivial; MIT-licensed; ~30 KLOC, comfortably
"small C library"). Vendor the tarball under `third_party/lua/` with a `LICENSE`
and a `VERSION` note, no submodule.

### 5.3 Embedding effort

Low. Lua's C API is `lua_pushcfunction` + `luaL_setfuncs` to register the ~25
bindings of §2; each binding is a dozen lines that reads Lua args, calls an
existing `v_*`/primitive, and pushes the result. No build-system surgery beyond
§5.2. The bindings *are* the work, and they are shallow.

---

## 6. Alternatives weighed

### (a) Extend the existing parser into a DSL

Add variables, loops, and query-and-assign to `oly_parse`/the `-i` loop.

- **Pro:** no new dependency; nothing leaves C; the ladder is irrelevant.
- **Con:** you are building a programming language inside a line-oriented command
  parser. Every feature (scoping, expressions, control flow, error handling) is
  hand-rolled and will be a *worse* language than Lua at far higher cost. It also
  does **not** port to Go any better than Lua does (it's bespoke C either way).
- **Verdict:** rejected as the primary path. Highest effort, lowest ceiling.

### (b) Declarative scenario format

A data file (TOML/JSON/custom) the engine loads directly: entities by symbolic
name, items/skills/orders as fields. A loader walks it and calls the same
primitives.

- **Pro:** the *most* portable (it's just data — a Go engine reads it trivially);
  deterministic by construction (names/ids are explicit, no global `rnd()`
  dependence); no embedded interpreter, no vendored lib, no ladder concern; and
  it captures the symbolic-name win of §2.1 on its own.
- **Con:** it **cannot express the query-and-branch the prompt explicitly
  asks for** — "create a guard only if the province has no garrison," "loop over
  N nobles," "read a minted id and act on it." Those are the very things that
  make immediate-mode scripting attractive.
- **Verdict:** excellent for the *static* portion of scenarios and as a
  serialization target, but insufficient alone. **Adopt it as a complement**:
  the registry + a declarative front end handles the 80% of scenarios that are
  pure construction; Lua handles the computed minority. (The Lua API can even
  emit the declarative file as its save format.)

### (c) A different embeddable language

Wren, Janet, Python (CPython), Tcl, ChaiScript, etc.

- CPython is far too heavy to vendor past this ladder and for a test tool.
- Wren/Janet are nice but smaller ecosystems and no clear Go portability story.
- Tcl is a natural fit for a command language but a heavier, older dependency.
- **Lua wins** on: smallest mature embeddable, single-TU vendoring, ubiquity in
  game tooling, and — decisively here — a credible Go portability path
  (`gopher-lua`). See §7.

**Overall recommendation:** **Lua (c) for the imperative/query surface, with a
declarative format (b) as a complementary static layer**, both fed by the same
symbolic-name registry and the same thin binding over existing handlers. Reject
(a).

---

## 7. Future Go portability

The team may port the engine to Go. What survives?

- **The binding glue never survives** — it's C calling `v_*`. In a Go engine it's
  rewritten as Go calling the Go equivalents, *regardless of language choice.*
  So "the C-Lua layer doesn't port" is true but not a differentiator: nothing in
  the C tooling ports as code.
- **What can survive is the artifact authors write.** Here the options diverge:
  - **Declarative (b):** survives perfectly. A Go loader reads the same TOML/JSON
    and calls Go primitives. Best portability.
  - **Lua (c):** the *scripts* survive **if the Go engine also embeds Lua** —
    [`gopher-lua`](https://github.com/yuin/gopher-lua) is a pure-Go Lua 5.1 VM, so
    the same `scenario.lua` runs against re-implemented Go bindings. The binding
    layer is rewritten (as it would be anyway); the scenario corpus is preserved.
    (Caveat: gopher-lua targets 5.1; if we pin C-Lua 5.4 we should script to the
    5.1 common subset to keep scripts portable — easy, since the API we expose is
    plain function calls.)
  - **Parser DSL (a):** survives worst — the bespoke interpreter must be
    re-implemented from scratch in Go to run existing scripts.

**This reinforces the recommendation:** lead with the declarative format for
static scenarios (maximally portable) and use Lua for computed ones, scripting to
the 5.1 subset so the corpus ports via gopher-lua. Avoid a bespoke DSL precisely
because it's the least portable.

---

## 8. Sample script — guard-pillage, rebuilt end to end

What guard-pillage's six-tool dance (steps 1–8 of §1.4) becomes as one readable,
deterministic, error-checked Lua file. Names replace every minted id; no `awk`,
no piped `-i`, no hand-written order files.

```lua
-- guard-pillage.lua — rebuild tests/olympia/regress/guard-pillage as one script.

local oly = require "oly"

-- 1-2. bare map + startlocs (replaces tar + `oly -s`)
oly.load("./lib", { fixture = "lib.tgz" })
oly.extract_startlocs()

-- 3-5. two factions. add_player wraps add_new_player() and binds the registry,
--      so the minted noble ids are named here and never recovered by awk.
local pil = oly.add_player{
    name = "pillager", faction = "Pillager Horde",
    noble = "grok", noble_name = "Warlord Grok",
    start = 0, full_name = "P Layer One", email = "pillager@example.com",
}
local grd = oly.add_player{
    name = "guard", faction = "Guard Order",
    noble = "vigil", noble_name = "Captain Vigil",
    start = 1, full_name = "P Layer Two", email = "guard@example.com",
}

-- 6. sculpt the pre-turn world (replaces the piped `be/poof/additem/guard`).
--    each op takes an explicit subject; no dangling `be` state.
local PROV, SOLDIERS = oly.id("prov:10113"), 12   -- item 12 = soldiers

oly.poof(pil.noble, PROV)
oly.additem(pil.noble, SOLDIERS, 50)

oly.poof(grd.noble, PROV)
oly.additem(grd.noble, SOLDIERS, 20)
oly.guard(grd.noble, true)

-- branch on real state — the capability immediate mode never had:
assert(oly.loc(pil.noble) == PROV and oly.loc(grd.noble) == PROV,
       "both nobles must share the province for the battle to trigger")
if not oly.has_item(pil.noble, SOLDIERS) then
    error("pillager has no soldiers — scenario would be a no-op")
end

-- 7. orders (replaces hand-written lib/orders/<n>)
oly.order(pil.noble, "pillage 1")
oly.order(grd.noble, "guard 1")

-- 8. freeze the pre-turn world; the regress runs the turn and hashes it.
oly.save("./lib")
```

A read-and-loop variant the old flow simply could not express — e.g. arm every
noble already standing in the province:

```lua
for who in oly.chars_here(PROV) do
    if not oly.has_item(who, SOLDIERS) then
        oly.additem(who, SOLDIERS, 10)
    end
end
```

---

## 9. Smallest viable prototype

The minimal binding set that lets **one real scenario (guard-pillage) be authored
as a script**, to validate the approach before committing to the full surface:

**Must-have (the prototype):**

1. **Build target** — `olyscript-g3` + `lua_vendored` per §5.2 (proves the
   vendoring/ladder isolation works; this is the riskiest build claim).
2. **Symbolic-name registry** — `oly.name/id` + binding-on-create (§2.1). This is
   the single highest-value piece; it kills the `awk` step that motivates the
   whole investigation.
3. **Eight bindings**, all path (A) over existing handlers:
   `oly.load`, `oly.extract_startlocs`, `oly.add_player`, `oly.poof`,
   `oly.additem`, `oly.guard`, `oly.order`, `oly.save`.
4. **Two query reads** to prove branching: `oly.loc`, `oly.has_item`.
5. **Deterministic build allocation** — route `add_player`'s id minting so the
   build doesn't depend on global `rnd()` position (§3.2), and confirm the
   resulting `lib` reproduces guard-pillage's existing golden tree
   **byte-identically**. That byte-match against the *current* fixture is the
   prototype's pass/fail gate.

**Explicitly deferred:** `make_loc`, `know`, `kill`, `credit`, the full query set
(`here`/`all`/`chars_here`/`knows`), the declarative format, RNG bindings, and
any production-engine integration. Path (B) direct-handler calls are deferred
unless path (A) proves clumsy.

**Success criterion:** `guard-pillage.lua` (§8) produces a `lib` whose
`golden_check`-style manifest equals the committed guard-pillage baseline, under
both the debug and asan-ubsan presets. If that holds, the approach is validated:
behavior is byte-preserving, the ladder is isolated, and the authoring story is
one file instead of six tools.

---

## 10. Risks & migration

| Risk | Mitigation |
|------|------------|
| Scripting perturbs the main golden manifest | Test-only **separate target** (§4); the standard `-r` turn never links or reaches Lua. Same byte-neutral argument as the combat keyed-RNG landing. |
| Non-deterministic ids from global `rnd()` | Explicit / #25-keyed scenario allocation (§3.2); reference entities by name, never by minted number. |
| Lua sources break the `-Werror` ladder | Separate `lua_vendored` static lib that never calls `olympia_compile_flags()` (§5.2); our bindings still take the full ladder. |
| Divergence from `-i` semantics | Bindings use parser path (A) over the *same* `v_*` handlers; keep `-i`/`-a` working unchanged until parity, then deprecate. |
| Go port strands the tooling | Lead with the portable declarative format; script Lua to the 5.1 subset so the corpus ports via `gopher-lua` (§7). Bindings are throwaway under any choice. |
| Scope creep into a GM feature | Hold the line at test-only (§4) until parity + demand are demonstrated. |

**Incremental rollout.** Land the prototype (§9) behind the new target without
touching `-i`/`-a`. Re-author guard-pillage as a script *alongside* the existing
`build-scenario.sh` and assert byte-identical output. Only once several fixtures
are scripted and stable should `build-scenario.sh`-style glue be retired — and
`-i`/`-a` stay in the engine regardless, since they're load-bearing for the
non-scripted paths and cost nothing to keep.
