# CLAUDE.md

Guidance for working in the **Olympia G3** repository.

## What this is

G3 is the third-generation Olympia play-by-mail (PBM) strategy game engine
(~54K lines of C) — the GitHub-era version with refinements over G2, and the
ancestor of the TAG engine. This repo is a standalone extraction of G3 from the
original multi-engine monorepo; it builds on its own with CMake.

The code is legacy C originally targeting **32-bit** systems. The C11/64-bit
modernization and the 32→64-bit list refactor are **complete**, and so are the
fixture backlogs: per command (`tests/ultron/backlog.tsv`, #116), per `use`
(`tests/ultron/use-backlog.tsv`, #180) and per turn phase
(`tests/ultron/phase-backlog.tsv`, #227). The engine is being **ported to
Rust + Rhai** in [mdhender/rhorri](https://github.com/mdhender/rhorri), and the
port is driven from that repo. This repo is now the **reference
implementation**: its golden trees and regress fixtures are the spec the port
is checked against, so keep them independent of the target language, and
follow the [C engine policy](#c-engine-policy-reference-implementation) below.

## C engine policy (reference implementation)

The C engine is frozen except for the changes below. The port must reproduce
its output byte for byte, so every change here is a change to the port's spec.

**Allowed changes:**

1. **Bug fixes, each with a pinning regress fixture** in the same PR. Fix the
   bug in C first, then in the port. The port reproduces C behavior, bugs
   included, until a fix lands here.
2. **New spec:** regress fixtures, Ultron work, coverage dumps and
   `--state-export` fields (#114).
3. **Harness changes that help the port run the spec,** such as letting a
   fixture's `check.sh` run a different engine binary. These must not change
   any golden output.
4. **Documentation.**

**Not allowed:** features, refactors, cleanup, dead-code removal, style or
warning fixes that touch engine sources, and "modernization". If a compiler
upgrade forces a source change, it must be byte-identical on both gates.

**The contracts.** The port keeps these identical, so treat any change to them
as a behavior change, made only when a bug fix needs it and called out in the
PR:

- **The DB format:** every file `-S` writes under `lib/`, reports included.
- **The RNG streams:** the MD5 primitive (`lib/rnd.c`), the `lib/rng.{c,h}`
  layer, and every stream's tag, keys and draw order
  ([doc/claude/rng-streams.md](doc/claude/rng-streams.md)).
- **The CLI and dump formats** the fixtures call: the flags, `--coverage`,
  `--use-coverage`, `--phase-coverage` and `--state-export`.

**Every behavior change files a matching rhorri issue.** If a PR changes golden
output or a fixture's `EXPECT` files, open an issue in `mdhender/rhorri` that
links the PR, so the port follows it. Name the rhorri issue in the PR body.

**When the port and C disagree,** first decide which one is wrong. If it's C,
fix it here under rule 1, then fix the port. If it's the port, fix only the
port.

**New fixtures are built here,** against the C engine, because the reference
engine is what produces the expected output. Scenario authoring stays in
`olyscript-g3` Lua. The fixtures the port runs are frozen `scenario.patch` /
`scenario.tgz` saved games, so the port doesn't need the Lua bindings to pass
them.

## Read only what your task needs

This file holds what every task needs. Task-specific detail lives in
[`doc/claude/`](doc/claude/); open a file when its trigger applies.

| Read | When you |
|---|---|
| [doc/claude/build.md](doc/claude/build.md) | change build flags, `CMakeLists.txt`, presets, prototypes or headers; triage a new compiler warning; need the modernization phase table or the deferred-bug record |
| [doc/claude/testing.md](doc/claude/testing.md) | need more than the two standing gates below: what the golden manifest covers, re-baselining, the per-subsystem regress gates |
| [doc/claude/ultron-fixtures.md](doc/claude/ultron-fixtures.md) | add or change a regress fixture, work a `tests/ultron/*backlog.tsv` cell, or touch the Ultron harness |
| [doc/claude/rng-streams.md](doc/claude/rng-streams.md) | add, move or remove a random draw; touch `lib/rng.{c,h}` or a `begin_*()` stream; need to know why a change did or did not re-baseline a golden tree |
| [BUILD_HISTORY.md](BUILD_HISTORY.md) | change build flags, prototypes or headers (**required**; it has the [warning policy](BUILD_HISTORY.md#warning-policy)) |
| [doc/turn-execution-order.md](doc/turn-execution-order.md) | need the order the turn's phases run in |

## Build

Requires CMake (>= 4.1), Ninja, and Clang or GCC.

```bash
cmake --preset debug
cmake --build --preset debug
# Binaries: build/debug/{olympia-g3,mapgen-g3,island-g3}
```

Presets: `debug` (default), `release`, `asan-ubsan`. Three targets: `olympia-g3`
(engine), `mapgen-g3` (map generator), `island-g3` (island generator). Details,
the 32-bit build and the compiler-flag rules are in
[doc/claude/build.md](doc/claude/build.md).

## Test — golden snapshots (must stay green)

Any change must keep the golden tests passing. A change that isn't a
deliberate bug fix (see the [C engine policy](#c-engine-policy-reference-implementation))
must produce **byte-identical** engine output.

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

The gate is a sorted sha256 manifest of the post-turn DB; re-baseline with
`golden_check.sh --update`, only for a deliberate output change. Per-subsystem
gates: [doc/claude/testing.md](doc/claude/testing.md).

## Layout

- `olympia/` — G3 engine sources (55 `.c`) and headers
- `mapgen/` — map generator (`mapgen.c`, `z.c`), island generator
  (`island.c`), and the MD5-based RNG (`rnd.c`, like G2)
- `lib/` — shared support code (entity lists, tiles, roads, allocation, …)
- `tests/` — golden fixtures (and the stale mapgen baseline)
- `run/` — run/test driver scripts and scratch run dirs
- `doc/` — assorted G3 design/reference notes, plus the modernization playbook
  and `phase4-tools/`; `doc/claude/` holds the task-specific agent guidance
  indexed above
- `BUILD_HISTORY.md` — the full phase-by-phase modernization record + warning
  policy

## Conventions

- Legacy C style: tabs, ANSI prototypes for definitions, terse names. Match the
  surrounding file; don't reformat untouched code.
- **Golden output is the contract.** Behavior changes that alter engine output
  must be deliberate bug fixes, with the snapshot updated in the same change, a
  note on why, and a matching rhorri issue (see the
  [C engine policy](#c-engine-policy-reference-implementation)).
- All compiler flags live in one CMake helper, `olympia_compile_flags(tgt)`,
  applied to all three targets. **Read
  [doc/claude/build.md](doc/claude/build.md) and
  [BUILD_HISTORY.md](BUILD_HISTORY.md) before changing it.**
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
  `Co-Authored-By: Claude Opus <noreply@anthropic.com>` trailer.
