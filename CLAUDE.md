# CLAUDE.md

Guidance for working in the **Olympia G3** repository.

## What this is

G3 is the third-generation Olympia play-by-mail (PBM) strategy game engine
(~54K lines of C) — the GitHub-era version with refinements over G2, and the
ancestor of the TAG engine. This repo is a standalone extraction of G3 from the
original multi-engine monorepo; it builds on its own with CMake.

The code is legacy C originally targeting **32-bit** systems. An active
modernization effort is bringing it to clean **C11 on 64-bit**. See
[Modernization status](#modernization-status) — read it before changing build
flags or touching prototypes/headers.

## Build

Requires CMake (>= 4.1), Ninja, and Clang or GCC.

```bash
cmake --preset debug
cmake --build --preset debug
# Binaries: build/debug/{olympia-g3,mapgen-g3,island-g3}
```

Presets (`CMakePresets.json`): `debug` (default), `release`, `asan-ubsan`.
The `asan-ubsan` preset sets `OLYMPIA_SANITIZE=ON` with address+undefined (on
`olympia-g3`).

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

> **The olympia golden gate now exists.** `tests/olympia/golden_check.sh`
> (adapted from G2) gates the post-turn DB in `run/olympia/lib` as a sorted
> sha256 **manifest** (`tests/olympia/golden/manifest.sha256`, 206 files). Run
> `./run/olympia-g3.sh` (a full `-r -S` turn) first, then `golden_check.sh`
> (prints `YES`); re-baseline with `--update`. The baseline was captured *after*
> the issue-1 list-triage fixes — the engine could not complete a turn before
> them — so it reflects the corrected tree; every modernization edit must keep
> it byte-identical (the first such edit, the `exit_views_list` migration under
> GitHub issue #2, is **done and closed**).
> Unlike G2, G3 output is **deterministic across clean rebuilds** (verified), so
> the gate has **no flaky-file holdout** (no G2-style `fact/100` `st -32`
> flicker). `tests/mapgen/golden` remains a **stale 32-bit baseline** — *not* the
> gate; the mapgen check is `tests/mapgen/regress/secret-sea-route/check.sh`.

## Layout

- `olympia/` — G3 engine sources (55 `.c`) and headers
- `mapgen/` — map generator (`mapgen.c`, `z.c`), island generator
  (`island.c`), and the MD5-based RNG (`rnd.c`, like G2)
- `lib/` — shared support code (entity lists, tiles, roads, allocation, …)
- `tests/` — golden fixtures (and the stale mapgen baseline)
- `run/` — run/test driver scripts and scratch run dirs
- `doc/` — assorted G3 design/reference notes, plus the modernization playbook
  and `phase4-tools/` (copied from G2 — see below)

## Conventions

- Legacy C style: tabs, ANSI prototypes for definitions, terse names. Match the
  surrounding file; don't reformat untouched code.
- **Golden output is the contract.** Behavior changes that alter engine output
  must be deliberate and the snapshot updated in the same change with a note on
  why. Modernization changes (prototypes, casts, dead-code removal) must produce
  byte-identical golden output.
- Build config lives in `CMakeLists.txt`. The enforced per-target flags are the
  `${LEGACY_C_FLAGS}` variable (a big block of `-Wno-*` suppressions, ~line 136)
  plus per-target `-Werror=` lines appended in each `target_compile_options`
  block (`island-g3` ~line 212, `mapgen-g3` ~line 231, `olympia-g3` ~line 276).
  **The `-Werror=` set differs per target** (see status table). The
  `phase_N_build_flags()` / `legacy_build_flags()` functions and
  `LEGACY_C_FLAGS_STRICT` are roadmap scaffolding — defined, not yet called.
- **C11 standard** is set both project-wide (`CMAKE_C_STANDARD 11` /
  `…_REQUIRED ON` / `CMAKE_C_EXTENSIONS OFF`, lines 4–6) *and* declared
  explicitly per target via `target_compile_features(<tgt> PRIVATE c_std_11)`
  on all three executables (issue #6, merged in #8). The per-target call is
  documentation/intent only — inert because the global standard already forces
  `-std=c11`; it guards against divergence if new targets are added. Mirrors the
  same change in siblings `../olympia-g1` / `../olympia-g2`. Not part of the
  64-bit modernization effort.

## Modernization status

A phase ladder is being applied. What is actually *enforced* is the per-target
`-Werror=` lines in each `target_compile_options` block. **G3 is earlier on the
ladder than G1/G2, and enforcement is uneven across the three targets** — read
the table literally. The full, current roadmap lives in the **GitHub issues**
(epic #10, "bring olympia-g3 to G1/G2 64-bit parity", with the phase ladder
extended past Phase 5 there); this table is the on-disk summary.

| Phase | Scope | State | Issue |
|-------|-------|-------|-------|
| 1 | `int-to-pointer-cast`, `pointer-to-int-cast` | ✅ enforced on `olympia-g3` + `mapgen-g3`; ⬜ **not** on `island-g3` | — |
| 2 | `incompatible-pointer-types` | ✅ enforced on `mapgen-g3`; ⬜ **not** on `olympia-g3` / `island-g3` | #11 (Phase A) |
| 3 | `int-conversion` | ✅ enforced on `mapgen-g3`; ⬜ **not** on `olympia-g3` / `island-g3` | #11 (Phase A) |
| 3.5 | **Remove dead/unused source files** | ✅ done | — |
| 4 | `strict-prototypes`, `missing-prototypes`, `implicit-function-declaration` | ✅ enforced on **all three** targets; all classes 0 | — |
| 5 | `missing-declarations` + wire ASan/UBSan across all three targets | ⬜ wired (asan preset), not enforced | #13 (+ bug #3) |
| 6 | `shorten-64-to-32` (Clang) + `sizeof-pointer-memaccess` | ⬜ not started | #14 |
| 7 | `sign-conversion` | ⬜ not started | #15 |
| 8 | `return-type` + return-mismatch | ⬜ not started | #16 |
| 9 | format-string / vararg checking | ⬜ not started | #7 |
| 10 | `implicit-int-conversion` (Clang, code-quality) | ⬜ not started | #17 |

> Two build-cleanup steps and a docs step close out epic #10 *after* the warning
> phases land: **Step B** (#12) — consolidate the per-target flags into one
> `olympia_compile_flags()` helper and drop the dead `phase_N_build_flags()` /
> `legacy_build_flags()` / `LEGACY_C_FLAGS_STRICT` scaffolding; **Step C** (#18)
> — write `BUILD_HISTORY.md` and refresh this file to mark modernization
> complete. A standing **post-64-bit warning policy** is tracked in #9.

The dangerous 32→64-bit hazards are now *largely* fenced off: **Phase 4 is done
on all three targets** (`strict-prototypes` / `missing-prototypes` /
`implicit-function-declaration` are `-Werror` and measure 0; the shared
`-Wno-implicit-function-declaration` / `-Wno-deprecated-non-prototype`
suppressions are deleted from `LEGACY_C_FLAGS`). `olympia-g3` still enforces
**only Phase 1** for the *pointer* classes (its `target_compile_options` comment
still says *"Phase 1 - list triage - only pointer-cast errors"*) — Phase 4 added
the three prototype classes alongside it. So the remaining runway is: **(a)** ✅
the pre-existing `olympia-g3` startup segfault is fixed — a full `-r -S` turn
completes (the `plist`/`ilist` list-triage in GitHub issue #1); **(b)** ✅ the
olympia golden gate is established and green (`tests/olympia/golden_check.sh`,
Test section above); and **(c)** ⬜ **the next step — GitHub issue #11 (Phase A,
under epic #10):** bring `olympia-g3` (and ideally `island-g3`) up to Phase 2/3
parity by flipping `incompatible-pointer-types` and `int-conversion` to
`-Werror` and fixing the fallout, keeping golden green at each step. `mapgen-g3`
already enforces both and is the worked example. The related hardening track —
GitHub issue #2 (retire the generic `plist` for element-typed lists, starting
with `exit_views_list`), which made the issue-1 bug class a compile error — is
**done and closed**.

> **The sister G1 and G2 repos are done through Phase 4.** `../olympia-g1` and
> `../olympia-g2` have both completed Phase 3.5 and Phase 4 — all three Phase-4
> warning classes are `-Werror` and measure 0, with byte-identical golden
> output. Read their `CLAUDE.md` "Modernization status" sections and their
> `Phase 4:` commits as **worked examples** before starting the same work here.
> The shared method is `doc/modernization-prototypes-playbook.md` (copied from
> G2) and the helper scripts in `doc/phase4-tools/` (`kr2ansi.py`,
> `gen_proto3.py`, `fix_comp.py`, `fix_void_defs.py`). The scripts carry
> G1/G2-specific paths and file lists — adapt them; the method matters more than
> the exact scripts.

> **Caution on the prototype probe:** do **not** use `-Wold-style-definition` to
> find K&R *definitions* — clang reports those under
> `-Wdeprecated-non-prototype`. In G1 the wrong probe hid **95** K&R definitions
> (54 in the map generator); G2 had 65. Expect a comparable population here, and
> probe with the correct flag. See `doc/modernization-prototypes-playbook.md`.

### Phase 3.5 — Remove dead/unused source files ✅ done

Deleted three `lib/*.c` modules that are in **no** `target_sources` block (never
compiled or linked into any target — verified by grepping `CMakeLists.txt` for
each basename, tree-wide across `olympia/`, `mapgen/`, `lib/`):

- `lib/effects.c`, `lib/entity_builds.c` — list modules referenced only by
  declarations in `lib/lists.h`; their list types (`effects_list`,
  `entity_builds_list`, `struct effect`, `struct entity_build`) had no use
  anywhere in the compiled tree. The matching declaration blocks were pruned
  from `lib/lists.h`.
- `lib/ring_buffer.c` (+`.h`) — self-contained; its only export `ring_printf`
  is called nowhere. (The `ring_buffer` symbols in `olympia/sout.c` are an
  unrelated local `static char *` array.)

This is the **same dead set as G2.** Kept (live in G3, in `olympia-g3`'s
sources): `lib/accept_ents.c`, `lib/checked_alloc.c` (+`.h`). **`lib/plist.c` is
already wired** into `olympia-g3`'s `target_sources` in G3 (unlike G1/G2, where
it was retained-but-unwired) — kept. Recover any deleted file from git history if
ever needed.

Verified: clean build of all three targets succeeds; **mapgen output
(`gate`/`loc`/`road`) is byte-identical** before vs after the deletion.

> **Pre-existing blocker — now FIXED.** `olympia-g3` used to **segfault** at
> `location_trades()` during `post_production()` on a freshly extracted fixture
> DB (identically on the pristine pre-Phase-3.5 tree, so the dead-file removal did
> not introduce it). It was a 64-bit pointer hazard exactly as suspected — a
> `plist` queried with `ilist` accessors — in three waves (`loop.h` macros, the
> `exit_view **` cluster, an inventory `qsort`). See
> GitHub issue #1 (closed; the archived design doc is attached as a comment there).
> The engine now
> completes a full `-r -S` turn, and the olympia golden gate has been captured
> (Test section / playbook Step 0).

### Phase 4 — Prototypes & declarations ✅ done

`strict-prototypes`, `missing-prototypes`, and `implicit-function-declaration`
are now `-Werror` on **all three** targets (olympia-g3, mapgen-g3, island-g3),
all three classes measure **0**, and golden output is **byte-identical**. The
dead `-Wno-implicit-function-declaration` / `-Wno-deprecated-non-prototype`
suppressions are deleted from `LEGACY_C_FLAGS` (and the mirrored scaffolding).

What it took (62 K&R defs → ANSI [38 mapgen / 24 olympia], 245 empty-paren
`name()` → `name(void)`, `olympia/proto.h` [657 protos] + `mapgen/proto.h` [74]):

- **G3-specific vs G1/G2:** G3's `rnd.c` **already includes `z.h`** (so the G2
  "rnd.c includes neither z.h nor oly.h" trap was pre-handled) — only its
  cross-file API (`MD5`/`load_seed`/`save_seed`/`md5_int`) needed declaring in
  `z.h`, with `byteSwap` made `static`. G3's `z.h` has **no `bzero`/`bcopy`
  macros** (only `abs` + char-class), a smaller libc-collision surface; the real
  libc headers (`stdio`/`string`/`stdlib`/`fcntl`) went at the top of
  `olympia/z.h` + `mapgen/z.h` above those macros. `olympia/tunnel.c`'s
  `print_map` uses file-private `SZ`/`MAX_LEVELS` macros → kept a local prototype
  (can't live in `proto.h`). `queue(int,char*,long a1..a9)` was still the G2
  poor-man's-varargs → made `(...)`/`vsprintf` with its `proto.h` prototype in
  the same step (arm64). `island-g3` (island.c is standalone, includes neither
  z.h nor oly.h): its 4 local helpers made `static`, 3 rnd entry points declared
  inline. No qsort comparator mismatches surfaced (G3's are already canonical).
- Latent bugs fixed as real bugs: `make_appropriate_subloc(row,col,0)` dead 3rd
  arg (×5, mapgen.c); `queue` varargs; `eat.c`'s bogus `extern char
  *clear_wait_parse()` for a `void` function; orphan decls `fetch_inside_name`,
  `dir_assert` (olympia decl; defined only in mapgen), `wrap_done`.
- **Gotcha for re-runs:** generate `proto.h` from a **clean** full build log, not
  an incremental one — ninja only re-emits warnings for recompiled TUs, so an
  incremental log silently omits most missing-prototype functions.

> **Golden gate date-determinism (surfaced + fixed during Phase 4):**
> `run/olympia/lib/times_0` (the "Olympia Times" newsletter) embeds the
> wall-clock **date**, so the committed `manifest.sha256` used to only match on
> the day it was captured. Fixed by a testing flag: passing
> **`test-use-const-report-date`** on the engine command line sets the
> `test_use_const_report_date` global (main.c), and `times_masthead()` (c2.c)
> then emits a fixed `January 1, 2000` instead of the wall-clock date.
> `run/olympia-g3.sh` passes the flag on the turn run, and the committed manifest
> was re-baselined with it, so `golden_check.sh` is now date-independent and
> prints `YES` on any day. (The flag affects *only* the newsletter date; all
> other output is byte-identical with or without it.)

The full method, order of operations, probe recipe, and every trap is in
`doc/modernization-prototypes-playbook.md`. The high-level shape (from G1/G2):

- Convert all K&R definitions to ANSI (`kr2ansi.py`; probe with
  `-Wdeprecated-non-prototype`, **not** `-Wold-style-definition`) and the
  empty-paren `name()` definitions to `name(void)` (`fix_void_defs.py`).
- Canonicalise the `qsort` comparators to `(const void *, const void *)` with
  local casts (`fix_comp.py`) — but only *after* `<stdlib.h>` gives `qsort` a
  real prototype, or stragglers hide.
- Generate a prototype header per target (`gen_proto3.py`) and wire it in:
  `olympia/proto.h` at the tail of `oly.h` (after type defs + `#include
  <stdio.h>`, forward-declaring any file-private structs used in signatures);
  `mapgen/proto.h` from the map generator's own header. **G3 has a third target,
  `island-g3`** — it builds `mapgen/island.c` + `mapgen/rnd.c`; check whether
  its functions need their own prototypes/header too.
- Add the real libc headers at the **top of `z.h` / `mapgen/z.h`**, above the
  engine's `bzero`/`bcopy`/`abs` shadow macros (the chokepoint every TU includes
  first), so implicit libc calls get real prototypes without breaking the macros.
- Delete now-redundant empty-paren forward decls (dispatch-table handler blocks,
  scattered `extern T foo();`, header decls).
- Fix the latent bugs the prototypes expose as **real bugs**, not papering over.

**Carry these G2-specific traps into G3 (G3 shares G2's ancestry more closely
than G1):**

- **MD5 RNG in `rnd.c`.** G3 uses the same MD5-based `rnd.c` as G2 (one per
  target, including neither `z.h` nor `oly.h`). Make it `#include "z.h"` (safe:
  the `bzero`/`bcopy` macros are `#ifdef SYSV`, off on macOS, so the
  golden-critical hash is untouched), declare its cross-file funcs (`MD5`,
  `save_seed`, `md5_int`) in `z.h`, and make purely file-local helpers
  (`byteSwap`, etc.) `static`. The RNG sequence is golden-critical — never
  "simplify" it.
- **Variadic conversion + arm64 ABI are coupled.** If G3 has a "poor man's
  varargs" function (G2's was `queue(int,char*,long a1..a9)`), it must become
  `(...)`/`vsprintf` *and* gain its `proto.h` prototype in the **same step** —
  on Apple arm64 a prototype-less variadic call segfaults.
- **File-private macros in a prototype's parameter type** (G2's `tunnel.c`
  `print_map` used file-local `SZ`/`MAX_LEVELS`) can't go in `proto.h`. Make
  such functions `static`, or keep a local prototype after the macro defs.
  G3 has its own `olympia/tunnel.c` — expect similar.

### Phase 5 — Lock down (GitHub issue #13)

Enable `-Werror=missing-declarations` and wire the `asan-ubsan` preset into CI
so sanitizers run against the golden flow across all three targets. **Watch for
a build-to-build non-determinism** like G2's `st -32` flicker in `fact/100`; if
one appears here, G2 proved it is *not* a missing-prototype bug — chase it with
the sanitizer run (uninitialized read / UB is the leading suspect).

**Pick up bug #3 while working #13:** `times_masthead` reads `month_names[-1]`
(turn-0 underflow; ASan global-buffer-overflow at `c2.c:422`). It is exactly the
kind of finding the Phase-5 sanitizer wiring is meant to surface, so fix it in
the same pass.

### Known bugs deferred past the 64-bit effort

- **Bug #4 (combat):** `construct_guard_fight_list`'s guard check compares
  `fight` *pointers* to an int box-id, so it is always -1. Labeled
  bug / golden / tech-debt — fixing it **changes golden output** and needs a
  deliberate re-baseline. **Deferred** until we are happy with the 64-bit
  modernization effort; do not pick it up as part of the phase ladder.
