
Investigate embedding a scripting layer (Lua, or an alternative) in the Olympia
G3 engine to replace/augment "immediate mode" for building game state — primarily
to make test-scenario authoring sane. This is a DESIGN/EXPLORATION task: survey
options, prototype the most promising binding on paper, and recommend a path. Do
NOT implement the full thing. Read-only investigation; produce a written design
doc (doc/scripting-tool.md) as the deliverable.

## Motivation (concrete, from a recent scenario build)

Authoring a single combat regression fixture (tests/olympia/regress/guard-pillage)
required gluing together: `-s` (extract startlocs) → hand-staged `act/<id>/Join-g3`
files → `-a` (add-player) → a piped `-i` immediate-mode command sequence
(be/poof/additem/guard/save) → hand-written `lib/orders/<faction>` files → an
awk pass over `lib/fact/<n>` to recover engine-minted noble ids. It works but is
brittle, multi-tool, has no error handling, no variables/loops, and no way to
query state and branch on it. The hypothesis to evaluate: it may be cleaner to
re-implement immediate mode as an embedded scripting interpreter that exposes
engine primitives, rather than to keep extending the line-by-line command path.

## Current state to map first (read these)

- Immediate mode: `olympia/immed.c` — `immediate_commands()` (stdin loop via
  getlin → oly_parse → do_command), and the GM verbs `v_be`, `v_poof` (~158),
  `v_add_item` (~116), `v_makeloc` (~198), `v_dump`, `v_save`, `v_know`, `v_kill`,
  `v_seed`, etc.
- Command table + dispatch: `olympia/glob.c` `cmd_tbl[]` (keyword → v_* handler,
  allow-flags "i"/"c"/"cr"/"p", time/poll/pri); `oly_parse`, `do_command`,
  `finish_command` (order.c / main flow). `struct command` (`c->who`, c->a..c->h,
  c->parse[]).
- Engine primitives the script layer would call: `new_ent`/`alloc_box` (code.c),
  `set_where` (loc.c), `gen_item` (u.c), `loop_here`/`loop_char_here` (loop.h),
  kinds/subkinds (glob.c), entity accessors (`p_char`, `p_player`, `subloc`,
  `player`, `kind`, `box_name`, `scode`/`code_to_int`).
- Bootstrap paths a script would replace: `olympia/add.c` (`make_new_players`
  ~288, `add_new_player` ~162; `act/<id>/Join-g3` + `startloc`), `extract_startlocs`
  (main.c ~604), order load/save (`olympia/order.c` `load_orders`/`load_player_orders`,
  format `<unit>:<order>` in `lib/orders/<n>`).
- CLI dispatch: `olympia/main.c` getopt (~677): `-i`, `-a`, `-s`, `-r`, `-S`.
- Build: `CMakeLists.txt` (THREE targets — olympia-g3, mapgen-g3, island-g3 —
  with one shared `olympia_compile_flags()` carrying a strict `-Werror` ladder;
  read BUILD_HISTORY.md before touching flags), `CMakePresets.json`.
- RNG/determinism: `lib/rnd.c`/`olympia/rnd.c` and the new addressable seam
  `lib/rng.{c,h}` (issue #25). Determinism is load-bearing — see below.

## Questions to answer

1. **Binding surface.** What is the minimal, coherent API a script needs to build
   scenarios and do GM ops? (create/place/stack entities, set items/flags/skills,
   query state, queue orders, run a turn, save.) Can it be a thin wrapper over the
   existing `v_*` handlers + a handful of primitives, or does it need deeper hooks?
   Sketch the Lua API (functions/tables) for re-authoring the guard-pillage
   scenario as one readable script, and show what that script would look like.
2. **Replace vs augment.** Is it cleaner to (a) replace `immediate_commands()`'s
   `-i`, or (c) keep `-i` and expose the same bindings to both? Recommend one.
3. **Determinism & the golden contract.** Golden output must stay byte-identical;
   scenario construction must be reproducible. How does scripting interact with
   the global `rnd()` stream and the #25 keyed seam? Must script-driven entity-id
   allocation and any RNG use be deterministic across runs/platforms? Does a script
   layer risk perturbing the main golden flow (it must not, if test-only)?
4. **Test-only tool vs engine feature.** Should this be a build-time/test harness
   (kept out of the shipped engine, e.g. a separate target or guarded by a flag),
   or a first-class GM capability? What are the implications for the three targets,
   binary size, and the no-CI local-gate workflow?
5. **Dependency & build integration.** Lua is a small C library — how would it be
   vendored/linked across the three CMake targets without disturbing the warning
   ladder (Lua's own sources won't pass `-Werror`; how to isolate them)? Pin a
   version. Compare embedding effort vs alternatives.
6. **Alternatives to weigh against Lua.** (a) A richer built-in command DSL /
   scripting in the existing parser (variables, loops, query-and-assign) without a
   new language; (b) a structured declarative scenario format (e.g. a scenario
   file the engine loads directly) instead of an imperative script; (c) a different
   embeddable language. Give the trade-offs and a recommendation.
7. **Future Go portability.** The team may port the engine to Go. Does an embedded
   C-Lua layer port cleanly (gopher-lua etc.), or does choice (b)/(a) port better?
   Factor this into the recommendation.

## Deliverables

- doc/scripting-tool.md: the option survey, a recommendation, the proposed binding
  API, a sample Lua (or chosen-approach) script that rebuilds the guard-pillage
  scenario end-to-end, a determinism/golden-safety analysis, a build-integration
  plan, and a risks/migration note (incremental rollout behind the existing
  `-i`/`-a` seams; keep them working until parity).
- A short "smallest viable prototype" definition: the minimal binding set that
  would let one real scenario be authored as a script, to validate the approach
  before committing.

## Constraints

- Read-only; no code changes. Legacy C style (tabs, ANSI prototypes, terse names)
  if you sketch C. Respect BUILD_HISTORY.md and the warning policy before
  proposing any flag/target changes. Golden output is the contract — any proposal
  must preserve byte-identical engine output and reproducible scenario builds.
  Prefer reusing existing handlers/primitives over new engine code.

