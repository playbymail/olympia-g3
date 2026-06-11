# Olympia G3

**G3** is the third-generation Olympia play-by-mail (PBM) strategy game engine
(~54K lines of C) — the GitHub-era version with refinements over G2.

This repository is a standalone extraction of the G3 engine from the original
multi-engine Olympia monorepo. It builds on its own with CMake.

The code is legacy K&R-style C originally targeting 32-bit systems. A modernization
effort is underway to make it compile cleanly on 64-bit systems.

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
(AddressSanitizer + UndefinedBehaviorSanitizer for `olympia-g3`).

Without presets:

```bash
mkdir build && cd build && cmake .. && cmake --build .
```

### 32-bit build (Linux, for golden-file generation)

```bash
mkdir build32 && cd build32
cmake -DBUILD_32BIT=ON ..   # requires gcc-multilib
cmake --build .
```

## Running / golden tests

Build first (default `debug` preset), then:

```bash
# mapgen: generates gate/loc/road and can be compared to tests/mapgen/golden
./run/mapgen/mapgen.sh

# olympia: extracts fixtures and runs the engine
./run/olympia-g3.sh
```

The scripts auto-detect the repo root and look for binaries at
`build/<preset>/<target>` (override the preset with `OLYMPIA_PRESET=release ...`).

## Layout

- `olympia/` — the G3 engine sources and headers
- `mapgen/` — the map and island generators
- `lib/` — shared support code (entity lists, tiles, roads, allocation, …)
- `tests/` — golden-test fixtures and golden files
- `run/` — run/test driver scripts and scratch run directories

## License

GNU Affero General Public License v3 — see [LICENSE](LICENSE). The original
Olympia sources are public domain.
