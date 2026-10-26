# genesis gates

Regression gates for `genesis-g3`, the world generator that writes mapgen's
inputs (#290). They are the reference expectations for ports of genesis, such
as the Go port in `mdhender/g3g0`.

## How a gate works

Each `regress/<name>/check.sh` lists its cases in `CASES`, one
`name|arguments` entry per argument vector, and calls `genesis_gate` from
[genesis.sh](genesis.sh). Each case runs in its own empty temporary
directory. The gate then compares:

- `EXPECT.log`: per case, the arguments, the exit status and genesis's
  stderr. The stderr lines record which retry paths a seed takes (`N oceans
  not 4-colorable`, `couldn't space N start cities`, the ocean cap warning,
  ...). stdout must be empty.
- `EXPECT.sha256`: the sha256 of every regular file the case leaves behind,
  as `<case>/<file>`: `Map`, `Regions`, `Land`, `Cities`, `randseed`, and
  `world.bmp` where `--image` is used. A case that fails before writing has
  no lines.

A gate prints `YES` and exits 0 on a pass. On a failure it prints `NO`, the
differences, and exits 1. Some gates also check outputs against each other
(`genesis_extra`), such as `0x10`, `020` and `16` writing the same world.

Under `OLYMPIA_PRESET=asan-ubsan` a sanitizer report goes to stderr, so it
fails the `EXPECT.log` comparison: `YES` there also means no diagnostics.

## The gates

| Gate | Covers |
|---|---|
| `defaults` | no arguments, and three other seeds, each a different world |
| `seed-parsing` | `--seed` is `strtoull` base 0: `0x10`, `020` and `16` agree |
| `sizes` | `--size 10`, `36`, `99`; `--size 30 -n 50` clamped to the ocean cap |
| `coloring-retry` | seeds whose ocean count isn't 4-colorable, so `add_oceans()` retries with one fewer |
| `island-iterations` | `-i 2` and `-i 10`, and `-i 2` at size 10 |
| `region-pool-wrap` | a size-99 world that runs out of pool names (`Ironvale 2`) |
| `defer-oceans` | `-D`: frontier growth, lakes, `Great Sea` recast as `Great Lake`, tiny water filled with land, size 10 |
| `ocean-growth-bfs` | `-D --ocean-growth bfs` (with lakes), and `frontier` given explicitly |
| `start-cities` | `--start-cities 0`, `1`, `16`, and a spacing retry at size 10 |
| `image` | `--pixels 1` and `64`, `--grid 4`, a BMP whose rows need padding; `--image` leaves the world files unchanged |
| `validation-errors` | every range check (exit 1, nothing written); `--pixels`/`--grid` are ignored without `--image` |
| `write-failures` | each output file planted as a directory (perror, exit 1, the earlier files kept); `--image` into a missing directory |

## Running against another generator

```bash
./tests/genesis/regress/defaults/check.sh             # the C build (debug preset)
OLYMPIA_PRESET=asan-ubsan ./tests/genesis/regress/defaults/check.sh
GENESIS_BIN=/path/to/port/genesis ./tests/genesis/regress/defaults/check.sh
for g in tests/genesis/regress/*/check.sh; do echo "$g: $($g | head -1)"; done
```

`GENESIS_BIN` follows the `MAPGEN_BIN` rules (`tests/mapgen/mapgen.sh`). A
relative path is taken from the current directory. A missing or
non-executable path exits 2. `--update` exits 2 while it is set: only the C
build writes `EXPECT.sha256` and `EXPECT.log`.

## Caveats

- **`randseed` byte order.** `write_randseed()` `fwrite`s two `uint64_t`s in
  host byte order, so the `randseed` lines hold only on little-endian hosts.
- **libc messages.** No case passes an unknown option: `getopt_long`'s
  messages come from libc and differ between macOS and glibc. The
  `write-failures` lines carry `strerror(EISDIR)`, "Is a directory" on both.
- **Unreached paths.** These gates don't reach `couldn't place N ocean
  origins`, `N deferred oceans not 4-colorable`, `no land for start cities`,
  `no open water left for oceans`, the two `internal error` exits, or the
  `assert()`s. No seed scan has reached them so far.
- Arguments are split on blanks, with no quoting, so a case can't pass an
  argument that contains a space.
