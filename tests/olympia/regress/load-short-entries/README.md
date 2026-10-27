# load-short-entries — short and empty list entries in a box file

Pins the fixes for #311 and #312.

**#311.** `skill_list_scan` and `req_list_scan` (`olympia/io.c`) read some
fields of each entry into locals with `sscanf()`. The locals were never
set, so on a line with too few numbers, `know`, `experience` or `consume`
was stack garbage. Now each entry starts them at 0, like the fields
`sscanf()` reads straight into the zeroed entry.

**#312.** A bare `sl`, `il`, `tl` or `rq` tag hands its scanner `""`, and
the test for a trailing `\` read `s[-1]`, one byte before the string. The
`*s` guard from #318 (PR #319) covers this: the empty entry parses as all
zeros, is reported as bad, and is dropped. These cases pin it.

`save_db()` always writes every field, so only a hand-edited or truncated
box file can do either.

## Scenario

No `scenario.patch`. Each case extracts the base world
`tests/olympia/fixtures/world.tgz`, puts a field before the blank line that
ends one box file, and loads and saves the DB (`-l ./lib -S`, no `-r`):

| case | file | field | saved, or reported on stderr |
|---|---|---|---|
| skill-short | `fact/207` | `CH`, ` sl 920` | ` sl	920 0 0 0 0` |
| skill-two | `fact/207` | `CH`, ` sl 920 2 \`, `921` | ` sl	920 2 0 0 0 \`, `921 0 0 0 0` |
| req-short | `skill` | `SK`, ` rq 77 2` | ` rq	77 2 0` |
| req-two | `skill` | `SK`, ` rq 77 2 1 \`, `78 3` | ` rq	77 2 1 \`, `78 3 0` |
| skill-bare | `fact/207` | `CH`, ` sl` | `skill_list_scan(9999): bad skill 0` |
| item-bare | `item` | `il` | `item_list_scan(403): bad item 0` |
| trade-bare | `loc` | `tl` | `trade_list_scan(78999): bad item 0` |
| req-bare | `skill` | `SK`, ` rq` | `req_list_scan(922): bad item 0` |

The `-two` cases check that the second entry starts at 0 too, rather than
carrying values over from the first.

## Checks

For each case: exit status 0 with no sanitizer report; the case's stderr
report exactly once, and no other `list_scan` report; and the saved entry
exactly once. Before #311's fix the four short cases save garbage; before
#319, the four bare cases abort under `asan-ubsan` (exit 134).
