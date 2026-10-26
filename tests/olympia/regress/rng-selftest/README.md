# rng-selftest — the `-R` self-test draws in a fixed order

Pins the fix for #241. On a terminal, `test_random()` (`olympia/z.c`, the
`-R` flag) prints its first 100 draws as a 10×10 grid. Each row used to be
one `printf()` with ten `rng_draw(&s, 1, 10)` arguments. C leaves the order
of argument evaluation unspecified, so the order of numbers within a row
was the compiler's: right to left on x86-64 GCC, left to right on clang
(and on GCC 16 for arm64). This is the same kind of bug as #38.

Now each row is drawn into an array, left to right, and then printed. The
grid reads in draw order on every compiler.

## Checks

`-R` runs before any DB is loaded, so the stream is rooted at the all-zero
master seed and needs no `lib`.

1. `EXPECT.txt`: the non-tty output, one draw per line, byte for byte.
   This path makes one draw per `printf()`, so it was never affected; it
   is pinned as the spec of `-R`.
2. The tty output, run under a pseudo-terminal (python3 `pty`), with each
   grid row split into one number per line, equals the non-tty output.

Check 2 fails on a build that evaluates the old `printf()` arguments right
to left. On clang it passed before the fix too. A hand-reversed row fails
it.
