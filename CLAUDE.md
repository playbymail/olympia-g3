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
(non-literal format strings) are resolved. The turn-1 golden fixtures don't
exercise `construct_guard_fight_list`'s guard path, so the #4 fix left the
manifest byte-identical — the corrected behavior is **not yet pinned by a
regression fixture**.

### Next track: Ultron groundwork (#25)

The next forward track is the [Project Ultron](doc/agentic-project-ultron.md)
test-coverage initiative, blocked by **#25 — RNG-state granularity**. The engine
draws from one process-global serial stream (`lib/rnd.c` / `olympia/rnd.c`), so
any reordered/added `rnd()` call re-bakes the whole 206-file manifest — which
makes the small, per-subsystem fixtures Ultron needs impossible. The design
survey and recommendation live in
[doc/rng-state-granularity.md](doc/rng-state-granularity.md). A prototype seam,
`lib/rng.{c,h}` (MD5-backed `rng_seed`/`rng_stream_of`/`rng_draw`/`rng_keyed`),
is committed but **intentionally unwired** — nothing calls it yet, so golden
output is byte-identical — with a standalone self-check at `tests/rng/check.sh`.
No subsystem has been migrated onto it (that step requires a deliberate one-time
re-baseline and stays deferred behind the TAG 64-bit work).
