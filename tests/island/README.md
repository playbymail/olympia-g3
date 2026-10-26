# island gates

Regression gates for `island-g3`, which reads a map on stdin, adds one
random island, and prints the new map (#292). They are the reference
expectations for ports of island, such as the planned Go port in
`mdhender/g3g0`.

## How a gate works

Each `regress/<name>/check.sh` (except `ocean-glyphs`, below) lists its
cases in `CASES` and calls `island_gate` from [island.sh](island.sh). An
entry is `name|map|randseed|stage|stage...`:

- `map` and `randseed` name input files. The gate's own directory is tried
  first, then [fixtures/](fixtures). A `randseed` of `-` means none.
- Each stage is one island run's arguments, split on blanks; it may be
  empty. The first stage reads `map`, and each later one reads the stage
  before's stdout, as in `island < map | island | island`. Every stage
  reads and advances the same `randseed`, so the order matters.

Each case runs in its own empty temporary directory, with the generator
named `island-g3` in `argv[0]` so the usage line is stable. The gate then
compares:

- `EXPECT.log`: per stage, the arguments, the exit status and stderr.
- `EXPECT.sha256`: each stage's stdout (`out.1`, `out.2`, ...) and the final
  `randseed`, as `<case>/<file>`.

A gate prints `YES` and exits 0 on a pass. On a failure it prints `NO`, the
differences, and exits 1. Some gates also check cases against each other
(`island_extra`). Under `OLYMPIA_PRESET=asan-ubsan` a sanitizer report goes
to stderr and fails the log comparison, so `YES` there also means no
diagnostics.

## The gates

| Gate | Covers |
|---|---|
| `defaults` | no arguments on an all-ocean map, three seeds, three islands |
| `ocean-glyph-output` | exact output for each ocean glyph (`; , : . ~` space `" '`) |
| `ocean-glyphs` | the #24 invariants for the same glyphs (its own script, no EXPECT files) |
| `size` | `-s 50`, `-s 1`; `-s 0`, `-5` and `-1000` are the random size (#294) |
| `border-shelf` | `-b` and `-c` at 0, 6 and a negative value (clamped to 0) |
| `existing-land` | placement around land already on the map |
| `chain` | four stages from one map; the same sizes in two orders differ |
| `no-room` | `-s` larger than the water: `Not enough room to expand island!`, the partial island, exit 0 |
| `map-shape` | a non-square map; rows of a different length are skipped |
| `usage-errors` | an unknown option and a missing argument: the usage line, exit 1; it names `island-g3` even when run by its full path (#300) |
| `write-failure` | `randseed` is a directory: `couldn't write randseed:Is a directory`, exit 1 |
| `empty-input` | no map rows (an empty file, blank lines, CRLF blank lines): `No map on stdin!`, exit 1, `randseed` unchanged (#295) |
| `missing-randseed` | no `randseed`: `randseed could not be opened.` on stderr, stdout the map alone, an all-zero seed (#298) |
| `map-bounds` | 120 rows of 119 characters works; a taller map, a longer row (even one that would be skipped) or a line `fgets` splits is an error, exit 1 (#299) |

## Running against another generator

```bash
./tests/island/regress/defaults/check.sh            # the C build (debug preset)
OLYMPIA_PRESET=asan-ubsan ./tests/island/regress/defaults/check.sh
ISLAND_BIN=/path/to/port/island ./tests/island/regress/defaults/check.sh
for g in tests/island/regress/*/check.sh; do echo "$g: $($g | head -1)"; done
```

`ISLAND_BIN` follows the `GENESIS_BIN` and `MAPGEN_BIN` rules. A relative
path is taken from the current directory. A missing or non-executable path
exits 2, with no fallback to C. `--update` exits 2 while it is set: only the
C build writes `EXPECT.sha256` and `EXPECT.log`.

## Not covered

- Arguments are split on blanks with no quoting.
