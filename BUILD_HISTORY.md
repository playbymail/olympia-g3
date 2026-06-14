# Olympia G3 — Build & Modernization History

Detailed record of the C11/64-bit modernization effort and build-system changes
for the Olympia G3 engine. This is the long-form history; for the current
build/test workflow and conventions see [CLAUDE.md](CLAUDE.md).

G3 is the third-generation Olympia play-by-mail engine (~54K lines of C) — the
GitHub-era version with refinements over G2, and the ancestor of the TAG engine.
The code originally targeted **32-bit** systems. A phased warning ladder
(Phases 1–10, plus project-wide `-Wformat`, flag consolidation, and wired
sanitizers) drove each 32→64-bit hazard class to zero and locked it as
`-Werror`. That ladder is **complete** — every targeted class is enforced across
all three targets (`olympia-g3`, `mapgen-g3`, `island-g3`), the golden flow runs
clean under AddressSanitizer + UndefinedBehaviorSanitizer, and the remaining work
is the actual 32→64-bit refactoring the ladder cleared the way for. This file is
the full phase-by-phase record; the [warning policy](#warning-policy) at the end
governs how new warnings are triaged from here.

## Deterministic newsletter date (`test-use-const-report-date`)

`test-use-const-report-date` makes the golden gate deterministic. The Olympia
Times masthead (`times_masthead()` in `olympia/c2.c`) otherwise embeds the
wall-clock **date** into `run/olympia/lib/times_0`, so its sha256 diverged from
the committed manifest on any day but the capture day. Passing
`test-use-const-report-date` on the engine command line sets the
`test_use_const_report_date` global (`olympia/main.c`); `times_masthead()` then
emits the fixed date `January 1, 2000` instead of calling `time()/localtime()`.
`run/olympia-g3.sh` passes the flag on the turn run, and the committed manifest
was baselined with it, so `golden_check.sh` is date-independent and prints `YES`
on any day. The flag affects **only** the newsletter date — all other output is
byte-identical with or without it — and normal play (no flag) still prints the
real date. (Surfaced and fixed during Phase 4.)

## Modernization status

| Phase | Scope | Issue |
|-------|-------|-------|
| 1 | `int-to-pointer-cast`, `pointer-to-int-cast` | #11 (Phase A) ✅ |
| 2 | `incompatible-pointer-types` | #11 (Phase A) ✅ |
| 3 | `int-conversion` | #11 (Phase A) ✅ |
| 3.5 | Remove dead/unused source files | — ✅ |
| 4 | `strict-prototypes`, `missing-prototypes`, `implicit-function-declaration` | — ✅ |
| 5 | `missing-declarations` + wire ASan/UBSan across all three targets | #13 ✅ |
| 6 | `shorten-64-to-32` (Clang-guarded) + `sizeof-pointer-memaccess` | #14 ✅ |
| 7 | `sign-conversion` | #15 ✅ |
| 8 | `return-type` + `return-mismatch` | #16 ✅ |
| 9 | format-string / vararg checking (`-Wformat`) | #7 ✅ |
| 10 | `implicit-int-conversion` (Clang-guarded, code-quality) | #17 ✅ |
| — | Step B: consolidate flags into `olympia_compile_flags()`, drop dead scaffolding | #12 ✅ |
| — | Step C: write `BUILD_HISTORY.md`, fold in warning policy, mark complete | #18 ✅ |

All phases were executed one per commit, with the golden gate `YES` on **both**
the debug and (from Phase 5 on) the asan-ubsan presets at every step. The dead
scaffolding (`legacy_build_flags()`, `phase_1..5_build_flags()`,
`LEGACY_C_FLAGS`, `LEGACY_C_FLAGS_STRICT`) is gone; the per-phase story lives here
and in git history.

> **G3-specific lineage facts** (they change which sibling fixes apply):
> - G3 uses the **MD5 RNG** (G2 lineage), not G1's `drand48`/`erand48` — so
>   apply G2's `sizeof(*ctx)` wipe fix and the MD5 sign sites, and **skip** G1's
>   `seed[3]` signedness fix (there is no `seed[3]`, so **no deliberate golden
>   change** in Phase 7).
> - G3 has **three** targets — `olympia-g3`, `mapgen-g3`, and the extra
>   `island-g3` (`mapgen/island.c` + `mapgen/rnd.c`). `island-g3` contributed
>   its **own** Phase 6/7 sites; `mapgen-g3`/`island-g3` use libc `fprintf`
>   directly and scanned **0** for format. **Don't trust sibling counts** —
>   every phase was re-inventoried.
> - G3-only feature code (the HTML report path, `tunnel.c`, the `add.c` sbaillie
>   generated-password feature) produced fresh format/return/conversion sites
>   with no G1/G2 precedent.

> **Caution on the prototype probe:** do **not** use `-Wold-style-definition` to
> find K&R *definitions* — clang reports those under
> `-Wdeprecated-non-prototype`. In G1 the wrong probe hid **95** K&R definitions
> (54 in the map generator); G2 had 65; G3 had 62. The full method is in
> `doc/modernization-prototypes-playbook.md`.

### Phase 3.5 — Remove dead/unused source files ✅

Deleted three `lib/*.c` modules in **no** `target_sources` block (never compiled
or linked into any target — verified by grepping `CMakeLists.txt` for each
basename, tree-wide across `olympia/`, `mapgen/`, `lib/`):

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

Verified: clean build of all three targets succeeds; mapgen output
(`gate`/`loc`/`road`) was byte-identical before vs after the deletion.

> **Pre-existing blocker — fixed in issue #1.** `olympia-g3` used to **segfault**
> at `location_trades()` during `post_production()` on a freshly extracted
> fixture DB (identically on the pristine pre-Phase-3.5 tree, so the dead-file
> removal did not introduce it). It was a 64-bit pointer hazard — a `plist`
> queried with `ilist` accessors — in three waves (`loop.h` macros, the
> `exit_view **` cluster, an inventory `qsort`). See GitHub issue #1 (closed; the
> archived design doc is attached there). The engine now completes a full `-r -S`
> turn, and the olympia golden gate was captured *after* this fix (so the
> baseline reflects the corrected tree). The related hardening track — issue #2
> (retire the generic `plist` for element-typed lists, starting with
> `exit_views_list`), which made the issue-1 bug class a compile error — is
> **done and closed**.

### Phase A (Phases 1–3) — pointer/int conversion classes ✅ (#11)

Brought `olympia-g3` and `island-g3` up to `mapgen-g3`'s level: Phase 1
(`int-to-pointer-cast`, `pointer-to-int-cast`), Phase 2
(`incompatible-pointer-types`), and Phase 3 (`int-conversion`) are `-Werror` and
measure **0** on all three targets. These are the dangerous 32→64-bit
pointer/int hazards (bad casts, int↔pointer conversions). Fallout:

- **Phase 2 on `olympia-g3`** was the `plist`/`ilist` hazard class again — `char
  **` post/order lists passed to `ilist_len` → switched to typed `cstrings_len`
  — plus 15 qsort comparators canonicalized to `(const void *, const void *)`.
- **Phase 3** surfaced only the deferred issue #4 guard check (silenced
  behaviorally with an explicit cast at the time; the defect itself was later
  fixed under #4 — see [Known bugs](#known-bugs-deferred-past-the-64-bit-effort)).

### Phase 4 — Prototypes & declarations ✅

`strict-prototypes`, `missing-prototypes`, and `implicit-function-declaration`
are `-Werror` on **all three** targets, all three classes measure **0**, and
golden output is byte-identical. The dead
`-Wno-implicit-function-declaration` / `-Wno-deprecated-non-prototype`
suppressions were deleted.

What it took: 62 K&R defs → ANSI (38 mapgen / 24 olympia), 245 empty-paren
`name()` → `name(void)`, `olympia/proto.h` (657 protos) + `mapgen/proto.h` (74).

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
  the **same step** (on Apple arm64 a prototype-less variadic call segfaults).
  `island-g3` (island.c is standalone, includes neither z.h nor oly.h): its 4
  local helpers made `static`, 3 rnd entry points declared inline. No qsort
  comparator mismatches surfaced (G3's are already canonical).
- Latent bugs fixed as real bugs: `make_appropriate_subloc(row,col,0)` dead 3rd
  arg (×5, mapgen.c); `queue` varargs; `eat.c`'s bogus `extern char
  *clear_wait_parse()` for a `void` function; orphan decls `fetch_inside_name`,
  `dir_assert` (olympia decl; defined only in mapgen), `wrap_done`.
- **Gotcha for re-runs:** generate `proto.h` from a **clean** full build log, not
  an incremental one — ninja only re-emits warnings for recompiled TUs, so an
  incremental log silently omits most missing-prototype functions.

The full method, order of operations, probe recipe, and every trap are in
`doc/modernization-prototypes-playbook.md`.

### Phase 5 — `missing-declarations` + wire sanitizers ✅ (#13)

`-Wmissing-declarations -Werror=missing-declarations` is locked in
`olympia_compile_flags()` on all three targets. **0 hits** — Phase 4's prototype
work already drove the function-declaration class to zero on clang (re-inventoried
from a clean full build with `-- -k 0`); the flag is a cross-compiler guard (a
distinct class from the prototype set on GCC) and the LP64 lockdown (a function
with no prior declaration is `extern int foo()`, so a caller of a
pointer-returning function reads 4 of 8 bytes). Pure flag flip; no source fixes
needed for the class.

**Sanitizers wired on all three targets.** `olympia_enable_sanitizers()` is now
called on `olympia-g3`, `mapgen-g3`, and `island-g3`, and the malformed
`OLYMPIA_SANITIZERS` cache-default line was fixed (it was
`set(... "" CACHE STRING "<doc>" address,undefined)`; the stray trailing token
broke CMake's `CACHE` recognition and leaked `CACHE STRING ... address,undefined`
literals onto the compiler command line, so the `asan-ubsan` preset failed to
build with `no such file or directory: 'CACHE'`). Corrected to the one-line form.
The **asan-ubsan golden gate ran green end-to-end for the first time**
(`OLYMPIA_PRESET=asan-ubsan ./tests/olympia/golden_check.sh` = `YES`, zero
ASan/UBSan diagnostics) — part of every later phase from here on.

Two memory-safety defects the sanitizers surfaced were fixed in the same pass,
both byte-identical golden:

- **Bug #3 (`times_masthead`):** `month_names[oly_month(sysclock)]` underflowed
  to `month_names[-1]` at turn 0 (`oly_month` is `((turn-1) % NUM_MONTHS)`; the
  fixture's `system` file has no `sysclock` line, so turn is 0). ASan
  global-buffer-overflow at `c2.c:422`, fires during the **`-i`** phase only (the
  `-r -S` turn has turn ≥ 1). Fixed by clamping turn 0 to month 0 with a bounds
  assert; turn ≥ 1 (and so the post-turn golden snapshot) is unchanged. Closed.
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
alignment bug.

### Phase 6 — `shorten-64-to-32` + `sizeof-pointer-memaccess` ✅ (#14)

The **first real width phase** (Phases 1–5 guarded *pointer/int* hazards and
declarations; this one surfaces *width* truncation). Both classes are `-Werror`
on all three targets via `olympia_compile_flags()` — the shorten flag
Clang-guarded (`if (CMAKE_C_COMPILER_ID MATCHES "Clang")`, the **first** Clang
guard inside the compile-flags helper; `-Wshorten-64-to-32` is a Clang-only
spelling, GCC folds it into `-Wconversion` which is not enabled — it MUST stay
guarded or GCC builds break), `sizeof-pointer-memaccess` portable. The
`-Wno-sizeof-pointer-memaccess` suppression was dropped. All Phase 6 changes are
representation-preserving → golden byte-identical on both gates.

**The `sizeof-pointer-memaccess` bug (2 sites).** In `MD5Final` the defensive
post-digest wipe was `memset(ctx, '\0', sizeof(ctx))` where `ctx` is `struct
xMD5Context *` — `sizeof(ctx)` is the *pointer* size (8 on LP64, was 4 on ILP32),
so it zeroed only 8 bytes instead of `sizeof(*ctx)`. Fixed to `sizeof(*ctx)` in
**both** `olympia/rnd.c` and `mapgen/rnd.c` (G3's MD5 RNG, G2 lineage).
Golden-safe: the digest is `memcpy`'d out *before* the wipe, so the produced MD5
— and the RNG built on it — is unchanged.

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
`md5_int` change was needed here** (G2 required `return (int) buf[0]` under
Phase 6): G3's `word32` is `uint32_t` (the `unsigned long` typedef is commented
out in `rnd.c`), so `buf[0]`→`int` is a 32→32 conversion never flagged by shorten
— in G3 the `md5_int` site is a *signedness* change, deferred to Phase 7.

### Phase 7 — `sign-conversion` ✅ (#15)

`-Wsign-conversion -Werror=sign-conversion` is locked in the **portable** section
of `olympia_compile_flags()` (GCC + Clang — *not* behind the Clang guard that
holds Phase 6's `-Wshorten-64-to-32`). This is the signed/unsigned
implicit-conversion class: architecture-independent (it bites the same on ILP32
and LP64), but a large population. No `-Wno-sign-conversion` suppression existed
to drop. **Mirrors G2's Phase 7 minus the seed fix** — G1's Phase 7 canonicalised
a `seed[3]` signed/unsigned `extern` mismatch in its `drand48`/`erand48` RNG;
G2/G3 use the MD5 RNG, so there is **no `seed[3]`** and **no deliberate golden
change** this phase. All changes are representation-preserving → golden
byte-identical on both gates.

**47 sites**, all matching what the implicit conversion already did:

- **MD5 RNG (`olympia/rnd.c` + `mapgen/rnd.c`, identical twins).** `rnd()`:
  `range = (unsigned)(high-low)`, `r = (int)range`, `mask |= (unsigned)r`,
  `return (int)(num + (unsigned)low)` — modulo-2³² identities. `xMD5Update()`:
  `t + (word32)len` (`len >= 0`). The `memcpy`/`memset` length args
  (`(size_t)len`, `(size_t)(count+8)`) only surface under the asan-ubsan preset's
  instrumentation — fixed too so the lock holds under **both** presets. The
  digest is `memcpy`'d out before any wipe, so the produced MD5 — and the RNG on
  it — is unchanged.
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
  **G3-specific vs G2:** G3's guard constants are `0xDEADBEEF`/`0xBABEFACE` (both
  exceed `INT_MAX`, so unsigned→int), giving two extra `(int)` casts per
  allocator beyond G2's lone `(int)size`. The guards are internal metadata, never
  emitted, so `gate`/`loc`/`road` are byte-identical.
- **The fixed `spaces` buffer** — `(size_t)spaces_len` in the `perm.c` subscript
  and `my_malloc((size_t)spaces_len+1)` in `sout.c`.
- **`mapgen/island.c`** — `(size_t)(target_size + 1)` on the island `malloc`
  count (G3-only, no G1/G2 precedent; `target_size` is a non-negative count). The
  third target, `island-g3`, contributed its own site.

### Phase 8 — `return-type` + `return-mismatch` ✅ (#16)

`-Wreturn-type -Werror=return-type` and `-Wreturn-mismatch
-Werror=return-mismatch` are locked in the **portable** section of
`olympia_compile_flags()` (GCC + Clang — *not* behind the Clang guard; G2 kept
this class portable and the macOS clang build accepts `-Wreturn-mismatch`). This
is the register-garbage class: a non-void function that falls off the end (or
hits a bare `return;`) leaves the caller reading whatever is in the return
register — 8 bytes on LP64. It is the exact class behind G2's `fact/100` "st -32"
flicker (`i_use()` fell off the end and its garbage return became
`command->status`). G3 was verified deterministic with **no such flicker**, so
there is **no deliberate golden change** this phase — every fix is golden-neutral
and both gates stay byte-identical. Both `-Wno-` lines (`-Wno-return-type`,
`-Wno-return-mismatch`) were dropped in the lock commit.

**Inventory: 60 `-Wreturn-type`, 0 `-Wreturn-mismatch`** (identical under both
presets; the two `-Wno-` lines override `CMAKE_C_FLAGS`, so inventory by
sed-dropping them first or probing a throwaway). Apple clang did **not** truncate
here (these are warnings until `-Werror`, and `-- -k 0` built every TU), but
re-inventory was reconciled against an unlimited error limit. Two fix shapes:

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

**G3-specific traps that held:** `build.c` `i_repair` is the `repair` **interrupt
handler** in `glob.c`'s command table (`int (*)(struct command *)`), so it MUST
stay `int` — fixed with shape (b) `return TRUE`, never void-converted (G2 had to
revert the equivalent). `order.c` `queue` is already variadic (`(...)`/`vsprintf`
with a `proto.h` prototype since Phase 4), so void-converting it carries no
register-ABI hazard. The G3 count is 60 sites (45 mapgen + 6 main.c + 9 engine
singles), smaller than G2's ~91 — G3 has its own mapgen/main source, so sibling
counts were not trusted (re-inventoried).

### Phase 9 — format-string / vararg checking (`-Wformat`) ✅ (#7)

`-Wformat -Werror=format` is locked in the **portable** section of
`olympia_compile_flags()` (GCC + Clang; G1/G2 kept this class portable and macOS
clang accepts it). The `-Wno-format` / `-Wno-format-security` suppressions had
hidden the whole class engine-wide even though the printf-like wrappers carry
`__attribute__((format))`. The worst subclass, `-Wformat-insufficient-args` (a
bare `%s` with no data argument), is **memory-unsafe** — it dereferences a
garbage pointer, 8 bytes on LP64. The non-security format class measures **0**
across all three targets under both presets; both golden gates stay byte-identical
(no re-baseline needed — the changed paths don't fire in the turn-1 fixture).

**Step 1 — make checking possible.** `olympia/queue` (the variadic `vsprintf`
wrapper in `order.c`) was **missing** its format attribute on the `proto.h`
declaration (exactly TAG/G2's bug); the other wrappers (`html`, `out`, `sout`,
`wiout`, `wout`) carry it in `olympia/legacy.h`. Added
`__attribute__((format(printf, 2, 3)))` to queue's `proto.h` decl first so its
call sites get checked. **G3-specific:** every `queue(who, "...")` call site
passes a string *literal* and scans clean — so unlike TAG/G2 the attribute
surfaced **no** new fixes, but it locks the call sites against future drift.

**Inventory: 15 unique sites** (identical under both presets; all in `olympia/` —
`mapgen-g3` / `island-g3` use libc `fprintf` directly and scanned **0**, so don't
trust sibling counts). Three groups:

- **9 fixed** (golden-neutral for the turn-1 fixture → gate stayed `YES` with no
  re-baseline):
  - **Output-neutral (5):** `c2.c:446` `times_masthead` `%*s` field width
    `67 - strlen(turn_s)` (a `size_t`) cast to `(int)` — the LP64-correct,
    representation-preserving fix; `garr.c:427` vestigial `add_s(n)` extra arg
    removed (+ dropped the unused `int n`); `main.c:656` `sizeof(struct box)`
    `%d`→`%zu` (startup stdout, not in the golden DB); `stack.c:204/400`
    vestigial `just_name()` extra args on the VECT unstack/drop messages.
  - **Memory-unsafe (3):** `c2.c:880` `board_message` `"%s%s%s boarded %s%s"` had
    5 specs / 4 args → removed the stray leading `%s` (the sibling unboard at
    `c2.c:1020`, `"%s%s disembarked from %s%s"`, proves 4 args); `scry.c:13`
    `"%s is in %s."` had 1 arg → added `just_name(target)` subject; `scry.c:17`
    same → added `box_name(target)` subject.
  - **Dropped-output (1):** `storm.c:1256` `d_death_fog` `"Killed %s %s."` had
    2 specs / 3 args, dropping `box_name(target)` → reformatted to
    `"Killed %s %s of %s."` so the victim is named.
- **6 deferred, later fixed (#20)** — `-Wformat-security` non-literal format
  sites (intentional `out(who, sout(...))`-style idioms): `immed.c:103/108`,
  `io.c:2843`, `main.c:573`, `produce.c:733/735`. At the Phase 9 capstone these
  were left for a later hardening pass, with `-Wno-format-security` /
  `-Wno-format-nonliteral` kept (placed **after** `-Wformat`, which re-enables
  them, and once — CMake de-dups earlier copies). **G3-specific vs G2:**
  `io.c:2843` and `main.c:573` are extra G3 sites G2 did not have; G2 *wrapped*
  its 5 in a follow-up. **Issue #20** since wrapped all 6 (literal `"%s"` format)
  and dropped both `-Wno-` suppressions, so `-Werror=format` now enforces the
  whole class — not just `-Werror=format` minus `-security` / `-nonliteral`.

### Phase 10 — `implicit-int-conversion` (Clang-guarded, code-quality) ✅ (#17)

`-Wimplicit-int-conversion -Werror=implicit-int-conversion` is locked in the
**Clang-only** `if (CMAKE_C_COMPILER_ID MATCHES "Clang")` block of
`olympia_compile_flags()`, alongside Phase 6's `-Wshorten-64-to-32` — **the
opposite of Phase 9** (format was portable). `-Wimplicit-int-conversion` is a
Clang-only diagnostic spelling; GCC folds this class into the broader
`-Wconversion` (not enabled here), so the pair MUST stay behind the Clang guard
or GCC builds break. There was **no `-Wno-implicit-int-conversion` suppression to
drop** — this phase only *adds* the pair. This was the **LAST warning phase** of
the ladder; every `-Werror` class is now locked.

Explicitly a **code-quality / tech-debt** track, off the 64-bit critical path:
`int`→`short`/`char` narrowing behaves identically on ILP32 and LP64. Every site
is a narrowing of an `int` (or compound int expression) into a `short` / `schar`
/ `char` / `uchar` entity-struct field; every fix is a representation-preserving
explicit cast to the destination type (the implicit truncation already happens,
the cast only documents it). Compound RHS is wrapped whole, e.g.
`f = (schar)(aura * 5)`; simple RHS uses `(type) rhs`. **No deliberate golden
change** — both gates stay byte-identical.

**Inventory: 167 sites** (identical under both presets; re-inventoried with the
flag added warn-only to the Clang block, since a bare `-DCMAKE_C_FLAGS` probe
won't land in the Clang-guarded target options). **Count trap:** the negation
sub-form `p->barrier = -(c->who)` reports under
`-Wimplicit-int-conversion-on-negation`, a **distinct** bracket sub-tag — match
the class by **prefix** (`grep -oE '\[-Wimplicit-int-conversion'`), not an exact
`[-Wimplicit-int-conversion]` grep, or you undercount by the on-negation site and
hit a discrepancy when `-Werror` surfaces it. Two commits:

- **92 sites in `olympia/io.c`** — the entity-restore `switch`
  (`p->field = (type) atoi(t)`) plus three `new->field = (type) var`
  initializers; landed as its own commit (the bulk; G1/G2 pattern).
- **75 long-tail sites across 28 other TUs** — one commit. Includes the lone
  on-negation site `scry.c:628` → `(short)(-(c->who))`. Because it was caught by
  the prefix-match inventory it was fixed here in the long-tail commit rather than
  surfacing at the `-Werror` lock (G2 had to fix its equivalent in the lock
  commit).

**G3-specific vs G1/G2:** G1/G2 each found 162 sites; G3 found **167** — G3 has
its own `io.c` and G3-only feature code, so the sibling counts were not trusted
(re-inventoried). G3-only long-tail sites with no sibling precedent include
`add.c` (the sbaillie generated-password feature: `noble_points`, `fast_study`).
G3's `z.c` `lower_array` build (`(char) i` / `(char)(i - 'A' + 'a')`) matches G1's
`z.c` shape but lives in both `olympia/z.c` and `mapgen/z.c` here.

### Step B — flag consolidation + dead scaffolding removal ✅ (#12)

End-of-runway housekeeping (not a warning class), landed as its own commits
separate from the source fixes:

- **Consolidated the flags.** The per-target `target_compile_options(...
  ${LEGACY_C_FLAGS} ...)` blocks were replaced with a single
  `olympia_compile_flags(tgt)` helper applied identically to all three targets
  (`olympia_compile_flags(island-g3)`, `(mapgen-g3)`, `(olympia-g3)`). The helper
  carries the surviving `-Wno-*` suppressions plus the `-Wfoo -Werror=foo` pairs
  (one per line, `# Phase N` comments). The enforced set is now uniform across all
  three targets.
- **Retired the dead scaffolding** (deleted outright): `legacy_build_flags()`,
  `phase_1..5_build_flags()`, `LEGACY_C_FLAGS`, `LEGACY_C_FLAGS_STRICT` — all
  unused once the flags were consolidated.
- **Optimization owned by the build type.** The old hardcoded `-Og -g` in the
  per-target blocks was clobbering the preset's `-O`/`-g` (target options append
  *after* `CMAKE_C_FLAGS_<CONFIG>`). Removed; `CMAKE_BUILD_TYPE` / the presets now
  own it (debug → `-O0 -g`, release → `-O3 -DNDEBUG`, asan-ubsan → its preset
  override). Golden-neutral — G3 output is deterministic across `-O` levels.

## Golden gate

**Golden output is the contract.** Every modernization edit had to keep it
byte-identical; behavior changes that alter output must be deliberate and
re-baselined in the same change with a note on why.

Two standing gates:

1. **Debug.** `tests/olympia/golden_check.sh` (adapted from G2) gates the
   post-turn DB in `run/olympia/lib` as a sorted sha256 **manifest**
   (`tests/olympia/golden/manifest.sha256`). Run `./run/mapgen/mapgen.sh`, then
   `./run/olympia-g3.sh` (a full `-r -S` turn), then `golden_check.sh` (prints
   `YES`); re-baseline with `--update`. The manifest is one `<sha256>  <relpath>`
   line per run-output file, so any content change anywhere shows up as a line
   that no longer matches.
2. **asan-ubsan** (standing since Phase 5). The same flow under ASan/UBSan must
   run clean: build the `asan-ubsan` preset and re-run with
   `OLYMPIA_PRESET=asan-ubsan` — the golden check must still print `YES` and
   produce **zero** ASan/UBSan diagnostics.

The baseline was captured *after* the issue-1 list-triage fixes (the engine could
not complete a turn before them), so it reflects the corrected tree. It is
date-independent via the `test-use-const-report-date` flag (above). Unlike G2, G3
output is **deterministic across clean rebuilds** (verified), so the gate has **no
flaky-file holdout** (no G2-style `fact/100` `st -32` flicker). `tests/mapgen/golden`
remains a **stale 32-bit baseline** — *not* the gate; the mapgen check is
`tests/mapgen/regress/secret-sea-route/check.sh`.

## Known bugs deferred past the 64-bit effort

These were post-modernization tracks, intentionally **not** part of the phase
ladder. **All three are now resolved:**

- **Bug #4 (combat) — ✅ fixed.** `construct_guard_fight_list`'s guard check
  passed an int box-id to `fights_lookup`, which compared `fight` *pointers* to
  that integer and so was always -1 (the "don't count a guard stacked-with /
  allied-to the pillagers" rule never fired). Replaced with a `->unit == i`
  membership scan over `l_a`. The change *is* a real behavior change to combat
  resolution, but the turn-1 golden fixtures don't exercise the guard path, so
  the manifest stayed **byte-identical** — no re-baseline was needed. The
  corrected behavior is therefore **not yet pinned by a regression fixture** (no
  fixture triggers combat); pinning it is deferred to the planned test-coverage
  work.
- **Issue #20 (format-security) — ✅ fixed.** The 6 non-literal `-Wformat-security`
  sites (Phase 9, above) were wrapped so the format string is a literal
  (`out(who, "%s", buf)` / `sout("%s", dir)` / `printf("%s", cmd)`), and
  `-Wno-format-security` / `-Wno-format-nonliteral` were dropped — `-Werror=format`
  now covers the whole format class with no sub-suppression. Output-neutral; both
  gates stayed green.
- **Issue #19 (mapgen allocator) — ✅ fixed.** `mapgen/z.c`'s hand-rolled
  boxing/guard allocator (`my_malloc` / `my_realloc` / `my_free`) was replaced
  with thin stdlib-forwarding wrappers, retiring the guard-misalignment and
  guard-constant-sign band-aids (Phases 5 and 7) along with it.

## Warning policy

The long-term policy for what is an error, what is suppressed, and how a new
warning is triaged. (This folds in GitHub issue #9, "Establish Post-64-Bit
Warning Policy".) The authoritative list is the conventions block +
`olympia_compile_flags()` in `CMakeLists.txt`; this section is the rationale.

The project deliberately does **not** adopt a blanket global `-Werror`. Compiler
vendors regularly introduce new warnings, and a global `-Werror` turns a routine
compiler upgrade into a broken build even when no functional defect exists.
Instead the project uses a **warning ratchet**: enable a class, drive it to zero,
then promote *that class* to `-Werror` with an explicit `-Wfoo -Werror=foo` pair.
This is exactly the method the Phase 1–10 ladder used.

**Three tiers:**

1. **Enforced (`-Werror`).** Every class on the Phase 1–10 ladder, plus the
   project-wide format class (Phase 9). Each was driven to **zero** across all
   three targets and locked. They are written as an explicit `-Wfoo -Werror=foo`
   pair, one class per line — the bare `-Wfoo` is redundant (the `-Werror=`
   already enables it) but is kept deliberately as a record that the class is at
   zero and locked. **Do not** collapse the pairs or relax any to a non-error.

2. **Suppressed (`-Wno-foo`).** Legacy idioms this ~54K-line codebase still leans
   on and that are **not** being chased — each stylistic / low-risk, none a
   64-bit hazard. The current G3 set in `olympia_compile_flags()`:
   - `-Wno-comment` — `//` inside `/* … */` block comments in legacy source.
   - `-Wno-compare-distinct-pointer-types` — legacy pointer comparisons.
   - `-Wno-dangling-else` — unbraced nested `if/else` in legacy control flow.
   - `-Wno-deprecated-declarations` — deprecated libc calls.
   - `-Wno-extra-tokens` — stray tokens after `#endif`/`#else`.
   - `-Wno-incompatible-library-redeclaration` — engine functions whose names
     collide with libc prototypes.
   - `-Wno-logical-not-parentheses` — `!x == y`-style legacy idioms.
   - `-Wno-macro-redefined` — macros redefined across headers.
   - `-Wno-multichar` — multi-character character constants.
   - `-Wno-non-literal-null-conversion` — `0`/`'\0'`-as-pointer idioms.
   - `-Wno-parentheses` — assignment/bitwise precedence without parens.
   - `-Wno-tautological-constant-out-of-range-compare` — narrow-type range
     compares.

   `-Wno-format-security` / `-Wno-format-nonliteral` were **retired** when issue
   #20 wrapped the 6 non-literal format sites, so the whole format class is now
   enforced (see Phase 9).

   These stay suppressed until someone opens a dedicated cleanup track and drives
   the whole class to zero in one focused pass, then promotes it to `-Werror` —
   never partially. As of the #4/#19/#20 closures there are **no open cleanup
   tracks** of this kind.

3. **Clang-only spellings.** `-Wshorten-64-to-32` (Phase 6) and
   `-Wimplicit-int-conversion` (Phase 10) are Clang-only diagnostics (GCC folds
   them into the broader `-Wconversion`); they sit behind
   `if (CMAKE_C_COMPILER_ID MATCHES "Clang")`. `-Wreturn-mismatch` (Phase 8) is
   **portable in G3 — not** Clang-gated (it sits in the common set, same as G2);
   keep it there.

**Triaging a new warning** (a compiler upgrade surfaces a new class, or a new
file trips something):

- If it is a **64-bit correctness hazard** (truncation, pointer/int confusion,
  width, sign, missing return → garbage register), treat it like a ladder phase:
  drive the class to **zero** across all three targets, then add the
  `-Wfoo -Werror=foo` pair to `olympia_compile_flags()`. Never lock a class with
  live hits remaining.
- If it is **stylistic / low-risk**, either fix the few sites or add a documented
  `-Wno-foo` to the suppression list with a one-line reason. Prefer fixing if the
  count is small.
- **Every** flag change must keep the golden gate `YES` on **both** presets
  (debug and asan-ubsan), byte-identical, asan/ubsan clean — the same invariant
  every ladder phase held. A pure flag flip (enabling/relaxing enforcement) is its
  **own commit**, separate from any structural CMake refactor and from any source
  change.
- **No CI.** Gates are run locally (maintainer decision); warning enforcement is
  not wired into CI.
