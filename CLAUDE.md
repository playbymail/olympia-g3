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
The `asan-ubsan` preset sets `OLYMPIA_SANITIZE=ON` with address+undefined on
**all three** targets (issue #13).

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

Since Phase 5 (issue #13) there is a **second standing gate**: the same flow
under ASan/UBSan must run clean. Build the `asan-ubsan` preset and re-run the
flow with `OLYMPIA_PRESET=asan-ubsan` — the golden check must still print `YES`
and produce **zero** ASan/UBSan diagnostics:

```bash
cmake --preset asan-ubsan && cmake --build --preset asan-ubsan
OLYMPIA_PRESET=asan-ubsan ./run/mapgen/mapgen.sh
OLYMPIA_PRESET=asan-ubsan ./run/olympia-g3.sh
OLYMPIA_PRESET=asan-ubsan ./tests/olympia/golden_check.sh   # YES, zero diagnostics
```

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
- Build config lives in `CMakeLists.txt`. All compiler flags live in **one
  shared helper**, `olympia_compile_flags(tgt)` (~line 38, the G1/G2 pattern),
  applied identically to all three targets — `olympia_compile_flags(island-g3)`,
  `(mapgen-g3)`, `(olympia-g3)` — replacing the old per-target inline
  `target_compile_options(... ${LEGACY_C_FLAGS} ...)` blocks (issue #12, Step B).
  The helper carries the surviving `-Wno-*` suppressions plus the Phase 1-4
  `-Wfoo -Werror=foo` pairs (one pair per line, `# Phase N` comments). **The
  enforced set is now uniform across all three targets** (see status table).
  Optimization/debug (`-O`/`-g`) is owned by `CMAKE_BUILD_TYPE` / the presets,
  **not** the helper (the old hardcoded `-Og -g` was clobbering the preset). The
  dead scaffolding (`legacy_build_flags()`, `phase_1..5_build_flags()`,
  `LEGACY_C_FLAGS`, `LEGACY_C_FLAGS_STRICT`) was deleted in #12;
  `olympia_enable_sanitizers()` is now called on **all three** targets
  (Phase 5 / issue #13).
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
ladder than G1/G2, but as of Phase A (issue #11) all three targets now enforce a
uniform Phases 1-4** — read the table literally. The full, current roadmap lives
in the **GitHub issues**
(epic #10, "bring olympia-g3 to G1/G2 64-bit parity", with the phase ladder
extended past Phase 5 there); this table is the on-disk summary.

| Phase | Scope | State | Issue |
|-------|-------|-------|-------|
| 1 | `int-to-pointer-cast`, `pointer-to-int-cast` | ✅ enforced on **all three** targets | #11 (Phase A) ✅ |
| 2 | `incompatible-pointer-types` | ✅ enforced on **all three** targets; all classes 0 | #11 (Phase A) ✅ |
| 3 | `int-conversion` | ✅ enforced on **all three** targets; all classes 0 | #11 (Phase A) ✅ |
| 3.5 | **Remove dead/unused source files** | ✅ done | — |
| 4 | `strict-prototypes`, `missing-prototypes`, `implicit-function-declaration` | ✅ enforced on **all three** targets; all classes 0 | — |
| 5 | `missing-declarations` + wire ASan/UBSan across all three targets | ✅ enforced on **all three** targets (0 hits); sanitizers wired + golden gate green on all three; bug #3 fixed | #13 ✅ (+ bug #3 ✅) |
| 6 | `shorten-64-to-32` (Clang) + `sizeof-pointer-memaccess` | ✅ enforced on **all three** targets (0 hits); MD5 `sizeof(ctx)` bug fixed | #14 ✅ |
| 7 | `sign-conversion` | ✅ enforced on **all three** targets (0 hits); MD5 RNG + qsort-nmemb + guard-slot casts | #15 ✅ |
| 8 | `return-type` + return-mismatch | ✅ enforced on **all three** targets (0 hits); 60 sites: 45 mapgen + 6 main.c + 9 engine singles | #16 ✅ |
| 9 | format-string / vararg checking | ⬜ not started | #7 |
| 10 | `implicit-int-conversion` (Clang, code-quality) | ⬜ not started | #17 |

> One build-cleanup step and a docs step close out epic #10 *after* the warning
> phases land: **Step B** (#12) — ✅ **done**: the per-target flags were
> consolidated into one `olympia_compile_flags()` helper and the dead
> `phase_N_build_flags()` / `legacy_build_flags()` / `LEGACY_C_FLAGS` /
> `LEGACY_C_FLAGS_STRICT` scaffolding deleted (the hardcoded `-Og -g` was also
> moved out to the build type); **Step C** (#18) — write `BUILD_HISTORY.md` and
> refresh this file to mark modernization complete. A standing **post-64-bit
> warning policy** is tracked in #9.

The dangerous 32→64-bit hazards are now fenced off uniformly: **Phases 1-4 are
done on all three targets** (`int-to-pointer-cast` / `pointer-to-int-cast` /
`incompatible-pointer-types` / `int-conversion` / `strict-prototypes` /
`missing-prototypes` / `implicit-function-declaration` are `-Werror` and measure
0 on `olympia-g3`, `mapgen-g3`, and `island-g3`; the shared `-Wno-*`
suppressions for the prototype classes are deleted). As of **Step B (#12)** all
three targets share one `olympia_compile_flags()` helper that lists Phases 1-4
explicitly. So the runway up to here is closed out: **(a)** ✅ the pre-existing
`olympia-g3` startup segfault is fixed — a full `-r -S` turn completes (the
`plist`/`ilist` list-triage in GitHub issue #1); **(b)** ✅ the olympia golden
gate is established and green (`tests/olympia/golden_check.sh`, Test section
above); and **(c)** ✅ **GitHub issue #11 (Phase A, under epic #10) is done:**
`olympia-g3` gained Phase 2 (`incompatible-pointer-types`) + Phase 3
(`int-conversion`) and `island-g3` gained Phases 1-3, so all three targets now
match `mapgen-g3` at Phases 1-4. The Phase-2 fallout on `olympia-g3` was the
`plist`/`ilist` hazard class again (`char **` post/order lists passed to
`ilist_len` → switched to typed `cstrings_len`) plus 15 qsort comparators
canonicalized to `(const void *, const void *)`; Phase 3 surfaced only the
deferred GitHub issue #4 guard check (silenced behaviorally with an explicit
cast, defect left for #4). The related hardening track — GitHub issue #2 (retire
the generic `plist` for element-typed lists, starting with `exit_views_list`),
which made the issue-1 bug class a compile error — is **done and closed**.
**GitHub issue #12 (Step B) is also done:** the per-target flags were
consolidated into one `olympia_compile_flags()` helper and the dead scaffolding
dropped. **GitHub issue #13 (Phase 5) is also done:**
`-Werror=missing-declarations` is locked on all three targets (0 hits — Phase 4
already covered the class on clang), ASan/UBSan are wired on all three (the
malformed `OLYMPIA_SANITIZERS` cache-default line is fixed), and the
**asan-ubsan golden gate runs green end-to-end for the first time**. Two
memory-safety defects it surfaced were fixed in the same pass: bug #3 (the
`times_masthead` turn-0 underflow, below) and a mapgen guard-allocator
misalignment (`my_malloc` placed its trailing guard int at a non-int-aligned
offset for odd request sizes — UBSan misaligned store; fixed by the same
int-alignment rounding `my_realloc` already did). **GitHub issue #14 (Phase 6)
is also done:** `-Werror=shorten-64-to-32` (Clang-guarded) and
`-Werror=sizeof-pointer-memaccess` (portable) are locked on all three targets, 16
LP64 width-truncation sites and the MD5 `sizeof(ctx)` wipe bug are fixed
representation-preservingly, and both golden gates stay byte-identical.
**GitHub issue #15 (Phase 7) is also done:** `-Werror=sign-conversion` (portable)
is locked on all three targets, 47 implicit signed/unsigned conversion sites are
made explicit representation-preservingly, and both golden gates stay
byte-identical. **GitHub issue #16 (Phase 8) is also done:**
`-Werror=return-type` and `-Werror=return-mismatch` (both portable, GCC +
Clang — *not* behind the Clang guard) are locked on all three targets, 60
fall-off-the-end sites are made golden-neutral (45 mapgen + 6 main.c + 9 engine
singles; 54 void-conversions plus 6 terminal returns), and both golden gates
stay byte-identical with zero sanitizer diagnostics. **Next up: GitHub issue #7 (Phase 9)** —
format-string / vararg checking. From here on the asan-ubsan gate
(`OLYMPIA_PRESET=asan-ubsan ./tests/olympia/golden_check.sh` = YES, zero
diagnostics) is part of every later phase.

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
suppressions are deleted from the shared flag set (then the `LEGACY_C_FLAGS`
variable itself was retired in Step B / #12 — the flags now live in
`olympia_compile_flags()`).

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

### Phase 5 — Lock down (GitHub issue #13) ✅ done

`-Wmissing-declarations -Werror=missing-declarations` is locked in
`olympia_compile_flags()` on **all three** targets. **0 hits** — Phase 4's
prototype work already drove the function-declaration class to zero on clang
(re-inventoried from a clean full build with `-- -k 0`); the flag is a
cross-compiler guard (a distinct class from the prototype set on GCC) and the
LP64 lockdown (a function with no prior declaration is `extern int foo()`, so a
caller of a pointer-returning function reads 4 of 8 bytes). Pure flag flip; no
source fixes needed for the class. Mirrors G1/G2 Phase 5.

**Sanitizers wired on all three targets.** `olympia_enable_sanitizers()` is now
called on `olympia-g3`, `mapgen-g3`, and `island-g3`, and the malformed
`OLYMPIA_SANITIZERS` cache-default line was fixed (it was
`set(... "" CACHE STRING "<doc>" address,undefined)`; the stray trailing token
broke CMake's `CACHE` recognition and leaked `CACHE STRING ... address,undefined`
literals onto the compiler command line, so the `asan-ubsan` preset failed to
build with `no such file or directory: 'CACHE'`). Corrected to the one-line
form. The **asan-ubsan golden gate now runs green end-to-end for the first
time** (`OLYMPIA_PRESET=asan-ubsan ./tests/olympia/golden_check.sh` = `YES`,
zero ASan/UBSan diagnostics) — part of every later phase from here on.

Two memory-safety defects the sanitizers surfaced were fixed in the same pass,
both byte-identical golden:

- **Bug #3 (`times_masthead`):** `month_names[oly_month(sysclock)]` underflowed
  to `month_names[-1]` at turn 0 (`oly_month` is `((turn-1) % NUM_MONTHS)`; the
  fixture's `system` file has no `sysclock` line, so turn is 0). ASan
  global-buffer-overflow at `c2.c:422`, fires during the **`-i`** phase only
  (the `-r -S` turn has turn ≥ 1). Fixed by clamping turn 0 to month 0 with a
  bounds assert; turn ≥ 1 (and so the post-turn golden snapshot) is unchanged.
  **Closed.**
- **mapgen guard-allocator misalignment:** `mapgen/z.c` `my_malloc` wrote its
  trailing `0xBABEFACE` guard int at offset `client + 2*sizeof(int)` without
  rounding the client size to int alignment (unlike `my_realloc`, which already
  did) — UBSan misaligned store at `z.c:63` for odd request sizes. Fixed by
  applying the same int-alignment rounding in `my_malloc`; the guard is internal
  metadata, never emitted, so `gate`/`loc`/`road` are byte-identical.

No build-to-build non-determinism appeared (G2's `st -32` `fact/100` flicker has
no analogue here — G3 output was already verified deterministic). The `gm.c`
divide-by-zero G1 hit did **not** surface: the full golden flow runs clean under
UBSan, confirming `lib/checked_alloc.c` (G2 lineage) avoids G1's guard-allocator
alignment bug, as expected.

### Phase 6 — `shorten-64-to-32` + `sizeof-pointer-memaccess` (GitHub issue #14) ✅ done

The **first real width phase** (Phases 1-5 guarded *pointer/int* hazards and
declarations; this one surfaces *width* truncation). Both classes are now
`-Werror` on **all three** targets via `olympia_compile_flags()` — the shorten
flag Clang-guarded (`if (CMAKE_C_COMPILER_ID MATCHES "Clang")`, the **first**
Clang guard inside the compile-flags helper, distinct from the one in
`olympia_enable_sanitizers()`; `-Wshorten-64-to-32` is a Clang-only spelling, GCC
folds it into `-Wconversion` which is not enabled — it MUST stay guarded or GCC
builds break), `sizeof-pointer-memaccess` portable. The
`-Wno-sizeof-pointer-memaccess` suppression was dropped. All Phase 6 changes are
representation-preserving → golden byte-identical on both the debug and
asan-ubsan gates.

**The `sizeof-pointer-memaccess` bug (2 sites).** In `MD5Final` the defensive
post-digest wipe was `memset(ctx, '\0', sizeof(ctx))` where `ctx` is
`struct xMD5Context *` — `sizeof(ctx)` is the *pointer* size (8 on LP64, was 4 on
ILP32), so it zeroed only 8 bytes instead of `sizeof(*ctx)`. Fixed to
`sizeof(*ctx)` in **both** `olympia/rnd.c` and `mapgen/rnd.c` (G3's MD5 RNG, G2
lineage). Golden-safe: the digest is `memcpy`'d out *before* the wipe, so the
produced MD5 — and the RNG built on it — is unchanged (verified byte-identical).

**16 `-Wshorten-64-to-32` sites** (10 olympia + 4 mapgen/z.c + 1 island + 1 add),
all representation-preserving:

- `olympia/z.c` + `mapgen/z.c` `readlin` path: `nread` retyped `int`→`ssize_t`
  (its source is `read()`), clearing both `nread = read(...)` sites in each;
  downstream indexing/compares are unaffected.
- `mapgen/z.c` `str_save`: `(unsigned)` cast on `strlen(s) + 1` feeding mapgen's
  `my_malloc(unsigned size)`. (olympia's `my_malloc` is `checked_alloc` with a
  `size_t` arg, so its `str_save` was never flagged — divergence from mapgen.)
- `olympia/code.c` `letter_val`: `return (int)(p-let)` — index into a fixed short
  string.
- `strlen()`→`int` name/line/word lengths, provably `<2^31`: documented `(int)`
  casts in `z.c`/`mapgen/z.c` `fuzzy_strcmp`, `c2.c` `line_length_check`,
  `check.c` `check_loc_name_lengths`, `eat.c` `do_eat_command`, `report.c`
  `strip_leading_stupid_word`, plus `mapgen/island.c` map-row length and
  `olympia/add.c` password-symbol-set length.

**G3-specific vs G2:** `add.c` (the sbaillie randomly-generated-password feature)
and `island.c` are extra sites with no G2 precedent — the third target,
`island-g3`, contributed its own site, so don't trust sibling counts. **No
`md5_int` change was needed** (G2 required `return (int) buf[0]`): G3's `word32`
is `uint32_t` (the `unsigned long` typedef is commented out in `rnd.c`), so
`buf[0]`→`int` is a 32→32 conversion, never flagged. Probe (`-Wshorten-64-to-32`)
reports 0; all three targets build clean as errors.

### Phase 7 — `sign-conversion` (GitHub issue #15) ✅ done

`-Wsign-conversion -Werror=sign-conversion` is locked in the **portable** section
of `olympia_compile_flags()` (GCC + Clang — *not* behind the Clang guard that
holds Phase 6's `-Wshorten-64-to-32`). This is the signed/unsigned
implicit-conversion class: architecture-independent (it bites the same on ILP32
and LP64), but a large population. No `-Wno-sign-conversion` suppression existed
to drop. **Mirrors `../olympia-g2`'s Phase 7 minus the seed fix** — G1's Phase 7
canonicalised a `seed[3]` signed/unsigned `extern` mismatch in its
`drand48`/`erand48` RNG; G2/G3 use the MD5 RNG, so there is **no `seed[3]`** and
**no deliberate golden change** in this phase. All changes are
representation-preserving → golden byte-identical on both the debug and
asan-ubsan gates.

**47 sites**, all matching what the implicit conversion already did:

- **MD5 RNG (`olympia/rnd.c` + `mapgen/rnd.c`, identical twins).** `rnd()`:
  `range = (unsigned)(high-low)`, `r = (int)range`, `mask |= (unsigned)r`,
  `return (int)(num + (unsigned)low)` — modulo-2³² identities.
  `xMD5Update()`: `t + (word32)len` (`len >= 0`). The `memcpy`/`memset` length
  args (`(size_t)len`, `(size_t)(count+8)`) only surface under the asan-ubsan
  preset's instrumentation — fixed too so the lock holds under **both** presets.
  The digest is `memcpy`'d out before any wipe, so the produced MD5 — and the RNG
  on it — is unchanged.
- **G3-specific vs G2 in `rnd.c`:** `md5_int` needed `return (int) buf[0]` here.
  G3's `word32` is `uint32_t`, so `buf[0]`→`int` is a *signedness* change Phase 6
  (shorten) did not flag (G2 fixed it under Phase 6 because its `word32` differs);
  in G3 it is a Phase 7 site.
- **qsort `nmemb` (bulk).** The `*_len()` count (`int`) feeding qsort's `size_t`
  `nmemb`, cast `(size_t)`: gm.c (×5), perm.c (×4), report.c (×3), input.c (×2),
  use.c (×2), check.c, seed.c, swear.c.
- **The shared `loop_known` macro** (`olympia/loop.h`). One `(size_t)` on its
  embedded `qsort(ilist_len(kn))` clears **all** its expansion sites at once
  (gm.c ×2, io.c, summary.c, report.c ×2) — those are *not* separate edits.
- **`mapgen/z.c`** — the `my_malloc`/`my_realloc` size-header and guard slots.
  **G3-specific vs G2:** G3's guard constants are `0xDEADBEEF`/`0xBABEFACE`
  (both exceed `INT_MAX`, so unsigned→int), giving two extra `(int)` casts per
  allocator beyond G2's lone `(int)size`. The guards are internal metadata, never
  emitted, so `gate`/`loc`/`road` are byte-identical.
- **The fixed `spaces` buffer** — `(size_t)spaces_len` in the `perm.c` subscript
  and `my_malloc((size_t)spaces_len+1)` in `sout.c`.
- **`mapgen/island.c`** — `(size_t)(target_size + 1)` on the island `malloc`
  count (G3-only, no G1/G2 precedent; `target_size` is a non-negative count). The
  third target, `island-g3`, contributed its own site — don't trust sibling
  counts.

Probe (`-Wsign-conversion`) reports 0 on **both** presets; all three targets
build clean with the new `-Werror` flag; debug and asan-ubsan golden gates both
`YES` (byte-identical) and asan/ubsan clean.

### Phase 8 — `return-type` + `return-mismatch` (GitHub issue #16) ✅ done

`-Wreturn-type -Werror=return-type` and `-Wreturn-mismatch
-Werror=return-mismatch` are locked in the **portable** section of
`olympia_compile_flags()` (GCC + Clang — *not* behind the Clang guard that holds
Phase 6's `-Wshorten-64-to-32`; G2 kept this class portable and the macOS clang
build accepts `-Wreturn-mismatch`). This is the register-garbage class: a
non-void function that falls off the end (or hits a bare `return;`) leaves the
caller reading whatever is in the return register — 8 bytes on LP64. It is the
exact class behind G2's `fact/100` "st -32" flicker (`i_use()` fell off the end
and its garbage return became `command->status`). G3 was verified deterministic
with **no such flicker**, so there is **no deliberate golden change** this phase
— every fix is golden-neutral and both gates stay byte-identical. Both `-Wno-`
lines (`-Wno-return-type`, `-Wno-return-mismatch`) are dropped in the lock commit.

**Inventory: 60 `-Wreturn-type`, 0 `-Wreturn-mismatch`** (identical under both the
debug and asan-ubsan presets; the two `-Wno-` lines override `CMAKE_C_FLAGS`, so
inventory by sed-dropping them first or probing a throwaway). Apple clang did
**not** truncate here (these are warnings until `-Werror`, and `-- -k 0` built
every TU), but re-inventory was reconciled against an unlimited error limit per
the issue's caution. Two fix shapes, mirroring the siblings (g2 `c51f558` /
`45ab4b2` / `3c3d22d`):

- **(a) void-convert** a legacy default-`int` procedure whose callers *all*
  ignore the return — definition **and** every `proto.h` declaration changed in
  lockstep (a clean `-Werror` build proves no caller consumed it). **44 in
  `mapgen/mapgen.c`** (the map pipeline: `open_fps`, `map_init`, `read_map`,
  `add_road`, `link_roads`, `dump_*`, `print_*`, `bridge_*`, `make_*`, `gate_*`,
  `count_*`, `clear_*_marks`, `dir_assert`, `randomize_dir_vector`,
  `place_sublocations`, …), **6 in `olympia/main.c`** (`call_init_routines`,
  `write_forward_sup`, `write_faction_sup`, `mail_reports`, `output_html_rep`,
  `copy_public_turns`), and **4 olympia singles** (`check.c` `check_db`, `sout.c`
  `init_spaces`, `order.c` `queue`, `gm.c` `gm_count_stuff` [static, no decl]).
- **(b) add the missing `return <default>;`** where a value is genuinely
  expected. Most fall-off paths sit after a live `assert(FALSE)` (asserts on in
  both the `-Og` debug and asan-ubsan builds → the new return is unreachable in
  the golden run → neutral). Matching the siblings' chosen values: `return 0`
  (`basic.c` `hinder_med_chance`, `buy.c` `reduce_qty`, `combat.c` `fort_covers`,
  `dir.c` `hidden_count_to_index`), `return ""` (`mapgen.c` `name_guild` — the
  lone *consumed* mapgen return, stays `char *`), and `return TRUE` (`build.c`
  `i_repair`).

**G3-specific traps that held:** `build.c` `i_repair` is the `repair`
**interrupt handler** in `glob.c`'s command table (`int (*)(struct command *)`),
so it MUST stay `int` — fixed with shape (b) `return TRUE`, never void-converted
(G2 had to revert the equivalent). `order.c` `queue` is already variadic
(`(...)`/`vsprintf` with a `proto.h` prototype since Phase 4), so void-converting
it carries no register-ABI hazard. The G3 count is 60 sites (45 mapgen + 6
main.c + 9 engine singles), smaller than G2's ~91 — G3 has its own mapgen/main
source, so sibling counts were not trusted (re-inventoried).

Probe reports 0 on **both** presets; all three targets build clean with the new
`-Werror` flags; debug and asan-ubsan golden gates both `YES` (byte-identical)
and asan/ubsan clean.

### Known bugs deferred past the 64-bit effort

- **Bug #4 (combat):** `construct_guard_fight_list`'s guard check compares
  `fight` *pointers* to an int box-id, so it is always -1. Labeled
  bug / golden / tech-debt — fixing it **changes golden output** and needs a
  deliberate re-baseline. **Deferred** until we are happy with the 64-bit
  modernization effort; do not pick it up as part of the phase ladder.
