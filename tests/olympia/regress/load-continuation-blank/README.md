# load-continuation-blank — an empty line after a continued field

Pins the fix for #318. `skill_list_scan`, `item_list_scan`,
`trade_list_scan` and `req_list_scan` in `olympia/io.c` read one entry per
line, and test `s[strlen(s)-1] == '\\'` to see whether another follows.
When the line after a trailing `\` was empty, `readlin_ew()` returned `""`
and that test read `s[-1]`, one byte before `readlin()`'s buffer.

Now they test `*s` first, so an empty line ends the list, as it already
does in the `boxlist`, `admit` and `known` scanners. The empty line is
still parsed as one all-zero entry before the test, so the load reports it
on stderr (for example `item_list_scan(403): bad item 0`) and drops it, as
before.

A line of only whitespace was never affected: `readlin_ew()` skips it, so
`s[-1]` is the skipped whitespace, inside the buffer. `save_db()` never
writes an empty continuation line, so only a hand-edited file can do this.

## Scenario

No `scenario.patch`. Each case extracts the base world
`tests/olympia/fixtures/world.tgz` and puts a field whose last line ends in
`\` before the blank line that ends one box file:

| case | file | inserted before the final blank line |
|---|---|---|
| skill_list | `lib/fact/207` | `CH`, ` sl 920 2 0 0 0 \` |
| item_list | `lib/item` | `il 10 1 \` |
| trade_list | `lib/loc` | `tl 1 10 1 0 0 0 0 0 \` |
| req_list | `lib/skill` | `SK`, ` rq 77 1 1 \` |

The engine runs with `-l ./lib` only: no `-r` and no `-S`, so it loads the
DB, runs `check_db()` and exits.

## Checks

For each case: exit status 0, and no AddressSanitizer or UBSan report on
stderr. Before the fix, every case under `asan-ubsan` aborts with a UBSan
report and exits 134. The debug build reads a stray byte and usually
passes, so the asan-ubsan gate is the one that pins this fix.
