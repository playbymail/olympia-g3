# Olympia G3

**G3** is the third-generation Olympia play-by-mail (PBM) strategy game engine
(~54K lines of C) — the GitHub-era version with refinements over G2.

This repository is a standalone extraction of the G3 engine from the original
multi-engine Olympia monorepo. It builds on its own with CMake.

The code is legacy K&R-style C originally targeting 32-bit systems. A modernization
effort is underway to make it compile cleanly on 64-bit systems.

## Targets

- `g3-olympia` — the main game engine
- `g3-mapgen` — the map generator (inputs `Map`/`Land`/`Cities`/`Regions`,
  outputs `gate`/`loc`/`road`)
- `g3-island` — the island generator

## Building

Requires CMake (>= 4.1), Ninja, and a Clang or GCC toolchain.

```bash
cmake --preset debug
cmake --build --preset debug
# Binaries: build/debug/{g3-olympia,g3-mapgen,g3-island}
```

Presets (see `CMakePresets.json`): `debug` (default), `release`, `asan-ubsan`
(AddressSanitizer + UndefinedBehaviorSanitizer for `g3-olympia`).

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
# mapgen: generates gate/loc/road and can be compared to tests/g3/mapgen/golden
./run/g3/mapgen/mapgen.sh

# olympia: extracts fixtures and runs the engine
./run/g3-olympia.sh
```

The scripts auto-detect the repo root and look for binaries at
`build/<preset>/<target>` (override the preset with `OLYMPIA_PRESET=release ...`).

## Layout

- `g3/olympia/` — the G3 engine sources and headers
- `g3/mapgen/` — the map and island generators
- `lib/` — shared support code (entity lists, tiles, roads, allocation, …)
- `tests/g3/` — golden-test fixtures and golden files
- `run/` — run/test driver scripts and scratch run directories

## License

GNU Affero General Public License v3 — see [LICENSE](LICENSE). The original
Olympia sources are public domain.
