# Build configuration and the modernization record

> Split out of [CLAUDE.md](../../CLAUDE.md). Read this when you change build flags, `CMakeLists.txt`, presets, prototypes or headers, or triage a new compiler warning.

## Presets and targets

Presets (`CMakePresets.json`): `debug` (default), `release`, `asan-ubsan`.
The `asan-ubsan` preset sets `OLYMPIA_SANITIZE=ON` with address+undefined on
**all three** targets.

There are **three** targets (one more than G1/G2): `olympia-g3` (engine),
`mapgen-g3` (map generator), and `island-g3` (island generator —
`mapgen/island.c` + `mapgen/rnd.c`).

## 32-bit build (Linux only — for regenerating golden files)

```bash
mkdir build32 && cd build32
cmake -DBUILD_32BIT=ON ..   # requires gcc-multilib
cmake --build .
```

## Compiler flags and the C standard

- Build config lives in `CMakeLists.txt`. All compiler flags live in **one
  shared helper**, `olympia_compile_flags(tgt)`, applied identically to all three
  targets — `(island-g3)`, `(mapgen-g3)`, `(olympia-g3)`. The helper carries the
  `-Wno-*` suppressions plus the enforced `-Wfoo -Werror=foo` pairs (one pair per
  line, `# Phase N` comments). Optimization/debug (`-O`/`-g`) is owned by
  `CMAKE_BUILD_TYPE` / the presets, **not** the helper.
  `olympia_enable_sanitizers()` is called on all three targets. **Before changing
  any of this, read [BUILD_HISTORY.md](../../BUILD_HISTORY.md) and its
  [warning policy](../../BUILD_HISTORY.md#warning-policy).**
- **C11 standard** is set project-wide (`CMAKE_C_STANDARD 11` / `…_REQUIRED ON` /
  `CMAKE_C_EXTENSIONS OFF`) and declared per target via
  `target_compile_features(<tgt> PRIVATE c_std_11)`. The per-target call is
  documentation/intent only (inert — the global standard already forces
  `-std=c11`); it guards against divergence if new targets are added.

## Modernization status

The C11/64-bit modernization ran as a phased warning ladder and is **complete**.
Every targeted warning class is enforced as `-Werror` via
`olympia_compile_flags()` in `CMakeLists.txt` (applied to all three targets:
`olympia-g3`, `mapgen-g3`, `island-g3`), and the golden flow runs clean under
AddressSanitizer + UndefinedBehaviorSanitizer. The per-phase scaffolding has been
removed. The 32→64-bit refactoring the ladder cleared the way for (converting
the entity lists to work on 64-bit, issues #1/#2) is also **complete**; the
forward track is test coverage ahead of the Go port.

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
[BUILD_HISTORY.md](../../BUILD_HISTORY.md)** — it has the full phase-by-phase record,
the traps each class hid (and the G3-specific divergences: the MD5 RNG, the third
`island-g3` target, the HTML-report/tunnel/`add.c` feature code), the rationale
behind every locked-in flag, and the
[warning policy](../../BUILD_HISTORY.md#warning-policy) for triaging new warnings.

## Known bugs deferred past the 64-bit effort

Post-modernization tracks, intentionally **not** part of the phase ladder (full
detail in [BUILD_HISTORY.md](../../BUILD_HISTORY.md#known-bugs-deferred-past-the-64-bit-effort)).

All cleared: **#4** (combat guard-check pointer/int compare) is fixed with a
proper `->unit` membership scan; **#19** (mapgen allocator) and **#20**
(non-literal format strings) are resolved. The #4 branch turned out to be
**unreachable** through its only caller — `attack_guard_units` builds `l_a` with
`add_allies = FALSE` (pillager's stack only) while guards are found via
`loop_here(province)` (province-direct only), so a guard can never be in both.
An A/B build (fixed vs buggy) yields a byte-identical battle report, so the fix
is correct-on-principle hardening of dead code and **no black-box fixture can
pin it** (write-up in
[tests/olympia/regress/guard-pillage/README.md](../../tests/olympia/regress/guard-pillage/README.md)).
