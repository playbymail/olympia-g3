# cli-options — options parse and are reported the same everywhere

Pins the fix for #343. `main()` in `olympia/main.c` parsed its short
options with the C library's `getopt()`, so what the errors said depended
on the platform:

| | macOS (BSD `getopt`) | glibc |
|---|---|---|
| unknown option | `olympia-g3: illegal option -- x` | `olympia-g3: invalid option -- 'x'` |
| missing argument | `olympia-g3: option requires an argument -- l` | `olympia-g3: option requires an argument -- 'l'` |

The parsing itself already matched: `main.c` defines `_POSIX_C_SOURCE`, so
glibc gives it the POSIX `getopt()`, which does not move options after a
non-option argument to the front. The fixture pins that too, so a port
cannot drift.

Now `oly_getopt()` parses them, the same way on every platform. It is the
BSD `getopt()` that macOS has, so macOS output is unchanged:

- parsing stops at the first argument that does not start with `-`, at a
  lone `-`, and after `--`;
- any other argument starting with `-` is a cluster of option letters;
- `-l` and `-G` take the rest of their cluster, or else the next argument;
- an unknown option (including `:`) prints
  `<argv[0]>: illegal option -- <c>` and a missing argument prints
  `<argv[0]>: option requires an argument -- <c>`, with `argv[0]` exactly as
  the engine was run; both count as an error, and any error prints the
  usage and exits 1 once parsing ends;
- `-?` is an option in the option string: it prints the usage with no
  diagnostic;
- `-R` and `-t` run as soon as they are parsed, so errors before them are
  printed but the run exits 0.

The long arguments (`--coverage`, `--use-coverage`, `--phase-coverage`,
`--state-export`, `test-use-const-report-date`) are taken out of `argv`
before option parsing and are not covered here.

## Scenario

No `scenario.patch`. The fixture extracts the base world
`tests/olympia/fixtures/world.tgz` once and runs each case in it with a
fixed `argv[0]` (bash's `exec -a`), so the engine's own file name never
shows. A case that stops parsing before an error just loads the DB
(`-l ./lib`, no `-S`) and exits 0. A case with `-R` runs the RNG self-test,
whose stdout is not checked here (see `rng-selftest`).

## Checks

`EXPECT.txt` has, for each case, its `argv`, the exit status and the stderr
lines that start with `<argv[0]>: ` or `usage: `, byte for byte. The rest
of stderr (load messages) and stdout are not compared.

Before the fix, glibc failed every case with a diagnostic; macOS already
gave every result in `EXPECT.txt`.

Re-baseline with `./check.sh --update` (the C engine only).
