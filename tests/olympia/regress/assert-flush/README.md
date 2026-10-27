# assert-flush — an assertion failure flushes stdio first

Pins the fix for #339. `asfail()` in `olympia/z.c` prints the failed
assertion on stderr and calls `abort()`. macOS's `abort()` flushes open
streams and glibc's does not, so whatever was still buffered survived on
macOS and was lost on Linux. That could be the bytes of a database file
being written, or stdout sent to a file.

Now `asfail()` calls `fflush(NULL)` before `abort()`, so every platform keeps
the buffered output, as macOS already did. The exit status is still 134
(SIGABRT). A crash, such as SIGSEGV (139), is not an assertion and still
flushes nothing. `mapgen/z.c` has its own `asfail()` with the same change.

## Scenario

No `scenario.patch`. The fixture extracts the base world
`tests/olympia/fixtures/world.tgz`, lists box 1 twice in `lib/master`, and
runs `-l ./lib` with stdout sent to a file. `fast_scan()` calls
`alloc_box()` for box 1 twice. The second call fails its duplicate-box
assert while the startup banner (`sizeof(struct box) = N`) is still in
stdout's buffer.

## Checks

Exit status 134; stderr reports `alloc_box: DUP box 1` and the assertion
failure; stdout holds the `sizeof(struct box)` line. Before the fix, on Linux,
stdout is empty. On macOS the fixture passes either way.
