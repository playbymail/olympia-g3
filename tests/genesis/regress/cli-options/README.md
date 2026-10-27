# cli-options — genesis options parse and are reported the same everywhere

Pins the fix for #344. `main()` in `genesis/genesis.c` parsed its options
with the C library's `getopt_long()`, so what the errors said depended on the
platform:

| argv | macOS | glibc |
|---|---|---|
| `--bogus` | ``genesis-g3: unrecognized option `--bogus'`` | `genesis-g3: unrecognized option '--bogus'` |
| `-x` | `genesis-g3: invalid option -- x` | `genesis-g3: invalid option -- 'x'` |
| `--size` | ``genesis-g3: option `--size' requires an argument`` | `genesis-g3: option '--size' requires an argument` |

The program name differed too: macOS prints the executable's file name
whatever `argv[0]` is, glibc prints `argv[0]` as given.

Now `gen_getopt_long()` parses them, the same way on every platform. It is
the BSD `getopt_long()` that macOS has, so macOS output is unchanged:

- options after a non-option argument (one not starting with `-`, or a lone
  `-`) are still parsed; with `POSIXLY_CORRECT` set, parsing stops at it;
  `--` ends the options;
- `--name`, or a `-` inside a short-option cluster (`-D-size`), is a long
  option. `--name=value` gives its argument; otherwise a long option that
  needs one takes the next argument;
- a long option may be shortened to a prefix that is unique, or whose matches
  all mean the same thing; an exact name always wins;
- a short option that needs an argument takes the rest of its cluster, or
  else the next argument;
- each error prints one line and genesis then prints its usage and exits 1:

  | error | line |
  |---|---|
  | unknown short option | `genesis-g3: invalid option -- c` (`illegal option` with `POSIXLY_CORRECT`) |
  | missing short argument | `genesis-g3: option requires an argument -- c` |
  | unknown long option | ``genesis-g3: unrecognized option `--name=value'`` (all of it) |
  | ambiguous prefix | ``genesis-g3: option `--name' is ambiguous`` |
  | `=value` on a flag | ``genesis-g3: option `--name' doesn't allow an argument`` |
  | missing long argument | ``genesis-g3: option `--name' requires an argument`` |

  A cluster that ends in `-` (`-D-`) is an error with no line.
- the prefix is always `genesis-g3:`, not `argv[0]`, as island prints a fixed
  name (#300). The usage text still shows `argv[0]` as given, as before.

## Scenario

No inputs. Each case runs `genesis-g3` in its own empty directory with a
fixed `argv[0]` (bash's `exec -a`) and, for `posix` cases,
`POSIXLY_CORRECT=1`. Cases that parse cleanly either fail a range check
(`--size 9`, which shows the option was read) or generate a size-10 world.

## Checks

`EXPECT.txt` has, for each case, its environment, `argv`, exit status,
stdout and stderr, byte for byte. The world files are not compared; the
other genesis gates cover them.

Before the fix, glibc failed every case with an option error; macOS already
gave every result in `EXPECT.txt`.

Re-baseline with `./check.sh --update` (the C build only).
