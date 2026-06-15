# Olympia G3

**G3** is the third-generation Olympia play-by-mail (PBM) strategy game engine
(~54K lines of C) — the GitHub-era version with refinements over G2, and the
ancestor of the TAG engine.

Sibling engine repositories:

- [olympia-g1](https://github.com/playbymail/olympia-g1)
- [olympia-g2](https://github.com/playbymail/olympia-g2)
- [olympia-tag](https://github.com/playbymail/olympia-tag)

This repository is a standalone extraction of the G3 engine from the original
multi-engine Olympia monorepo. It builds on its own with CMake.

The code is legacy K&R-style C originally targeting 32-bit systems. A modernization
effort is underway to make it compile cleanly on 64-bit systems.

> [!IMPORTANT]
> **This is a modernization project, not a development project — no new features.**
> The goal is to bring the existing G3 engine to clean C11 on 64-bit while
> preserving its exact behavior. **Golden output is the contract:** every change
> must keep the golden tests passing (byte-identical), and any behavior change
> must be deliberate, justified, and re-baselined in the same change (PR). New game
> features, gameplay tweaks, and scope expansion are out of bounds. See
> [BUILD_HISTORY.md](BUILD_HISTORY.md) for the full modernization record.

## Targets

- `olympia-g3` — the main game engine
- `mapgen-g3` — the map generator (inputs `Map`/`Land`/`Cities`/`Regions`,
  outputs `gate`/`loc`/`road`)
- `island-g3` — the island generator

## Building

Requires CMake (>= 4.1), Ninja, and a Clang or GCC toolchain.

```bash
cmake --preset debug
cmake --build --preset debug
# Binaries: build/debug/{olympia-g3,mapgen-g3,island-g3}
```

Presets (see `CMakePresets.json`): `debug` (default), `release`, `asan-ubsan`
(AddressSanitizer + UndefinedBehaviorSanitizer on all three targets).

Without presets:

```bash
mkdir build && cd build && cmake .. && cmake --build .
```

### 32-bit build (Linux, for regenerating golden files)

```bash
mkdir build32 && cd build32
cmake -DBUILD_32BIT=ON ..   # requires gcc-multilib
cmake --build .
```

## Running / golden tests

Build first (default `debug` preset), then:

```bash
# mapgen: generates gate/loc/road (inputs to the olympia run below)
./run/mapgen/mapgen.sh

# olympia: extracts fixtures, runs a turn, saves the database
./run/olympia-g3.sh

# compare the olympia run output against the golden snapshot
./tests/olympia/golden_check.sh           # YES = match
./tests/olympia/golden_check.sh --update   # refresh the snapshot
```

The scripts auto-detect the repo root and look for binaries at
`build/<preset>/<target>` (override the preset with `OLYMPIA_PRESET=release ...`).

## Layout

- `olympia/` — the G3 engine sources and headers
- `mapgen/` — the map and island generators
- `lib/` — shared support code (entity lists, tiles, roads, allocation, …)
- `tests/` — golden-test fixtures and golden files
- `run/` — run/test driver scripts and scratch run directories
- `doc/` — assorted G3 design/reference notes and the modernization playbook
- `CLAUDE.md` — working guidance (build, test, conventions)
- `BUILD_HISTORY.md` — full phase-by-phase modernization record
- `AUTHORS.md` — authors and credits

## Authors

See [AUTHORS.md](AUTHORS.md). Olympia was created by Rich Skrenta; this
repository is maintained and modernized by Michael Henderson.

## License

GNU Affero General Public License v3 — see [LICENSE](LICENSE). The original
Olympia sources are public domain.
