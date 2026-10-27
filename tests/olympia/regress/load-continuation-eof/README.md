# load-continuation-eof — a continued field on a file's last line

Pins the fix for #313. The list scanners in `olympia/io.c` read a field
that goes on past a trailing `\` by calling `readlin_ew()` for the next
line. They used that line without checking it, so when the `\` was on the
last line of a box file, `readlin_ew()` returned NULL and `load_db()`
crashed with SIGSEGV.

Now each scanner stops when `readlin_ew()` returns NULL. It keeps the
entries it has read, as if the last line had no `\`. The fixed scanners
are `boxlist0_scan`, `boxlist_scan`, `admit_scan`, `ilist_scan`,
`known_scan`, `skill_list_scan`, `item_list_scan`, `trade_list_scan` and
`req_list_scan`.

`save_db()` never ends a file with a `\`, so only a truncated or
hand-edited file can do this.

## Scenario

No `scenario.patch`. Each case extracts the base world
`tests/olympia/fixtures/world.tgz`, removes the blank line at the end of
one box file, and appends a field whose last line ends in `\`:

| case | file | appended |
|---|---|---|
| boxlist | `lib/fact/205` | `an 206 \` |
| boxlist0 | `lib/loc` | `LO`, ` pd 0 10001 \` |
| admit | `lib/fact/205` | `PL`, ` am 206 1 \` |
| known | `lib/fact/205` | `PL`, ` kn 26000 \` |
| skill_list | `lib/fact/207` | `CH`, ` sl 920 2 0 0 0 \` |
| item_list | `lib/item` | `il 10 1 \` |
| trade_list | `lib/loc` | `tl 1 10 1 0 0 0 0 0 \` |
| req_list | `lib/skill` | `SK`, ` rq 77 1 1 \` |

`ilist_scan` has no callers, so no case reaches it.

The engine runs with `-l ./lib` only: no `-r` and no `-S`, so it loads the
DB, runs `check_db()` and exits.

## Checks

For each case: exit status 0, and no AddressSanitizer or UBSan report on
stderr. Before the fix every case exits 139.
