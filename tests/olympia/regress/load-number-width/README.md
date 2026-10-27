# load-number-width — numbers in a box file are read whole

Pins the fix for #342. The box-file scanners in `olympia/io.c` read their
numbers with `sscanf("%d ...")`: `skill_list_scan`, `item_list_scan`,
`trade_list_scan` and `req_list_scan`, `olytime_scan` (a char's `dt` and
the `sysclock:` line of `lib/system`) and `scan_command`'s `ar` line. How
much of a long number `%d` reads is up to the C library. macOS reads at most
512 characters and leaves the rest for the next field, so for 512 zeros then
`1`, it read `0` and glibc read `1`. The same DB loaded differently on the two
platforms.

Now `scan_ints()` reads them, the same way on every platform. It follows the
rules glibc's `sscanf` already used:

- a number is leading whitespace, an optional `+` or `-`, then decimal
  digits, read as `strtoll(s, &end, 10)` reads them, with no length limit;
- past the `long long` range it is `LLONG_MAX` or `LLONG_MIN`;
- an `int` field keeps the low 32 bits, so `4294967297` is `1`,
  `LLONG_MAX` is `-1` and `LLONG_MIN` is `0`;
- the two `short` fields of an olytime (turn and day) keep the low 16 bits;
- reading stops at the first field with no digits, and that field and the
  ones after it keep their values.

For a number under 512 characters this is what both C libraries read, so a
DB that loaded the same way before still does.

`readlin()` cuts a box-file line at `LEN - 1` (2047) characters on every
platform, so each case keeps its lines shorter than that.

## Scenario

No `scenario.patch`. A load-only fixture, like `load-short-entries`: each
case extracts the base world `tests/olympia/fixtures/world.tgz`, edits one
file under `lib/` and runs `-l ./lib -S` (load and save, no turn). The
fixture first loads and saves the unedited world once, for the `same` cases
to compare against.

In the table, *Z* is 512 zeros and *N* is 600 nines.

| case | file | edit | result |
|---|---|---|---|
| item-pad | `loc` | *Z* before each number of the first `il` entry (two lines) | saved file same as the unedited world's |
| trade-pad | `loc` | *Z* before the first three numbers of the first `tl` entry | same |
| req-pad | `skill` | *Z* before each number of the first `rq` entry (two lines) | same |
| args-pad | `fact/200` | ` ar 0 0 0 0 0 0 0 0` becomes ` ar `*Z*`1 `*Z*`2 `*Z*`3 4 5 6 7 8` | ` ar 1 2 3 4 5 6 7 8` |
| item-plus | `item` | append `il +`*Z*`1 5` to item 403 | `il	1 5` |
| item-minus | `item` | append `il -`*Z*`1 5` | `item_list_scan(403): bad item -1` |
| item-wrap | `item` | append `il 4294967297 5` | `il	1 5` |
| item-overflow | `item` | append `il `*N*` 5` | `item_list_scan(403): bad item -1` |
| item-underflow | `item` | append `il -`*N*` 5` | `item_list_scan(403): bad item 0` |
| skill-pad | `fact/207` | append `CH` / ` sl `*Z*`920 `*Z*`2 `*Z*`3` to char 9999 | ` sl	920 2 3 0 0` |
| death-pad | `fact/207` | append `CH` / ` dt `*Z*`2 `*Z*`3 `*Z*`4` | ` dt 2 3 4` |
| death-wrap | `fact/207` | append `CH` / ` dt 65538 -65533 4` | ` dt 2 3 4` |
| sysclock-pad | `system` | append `sysclock: `*Z*`2 `*Z*`3 `*Z*`4` | `sysclock: 2 3 4` |

## Checks

For each case: exit status 0, no AddressSanitizer or UBSan report, the
case's `list_scan` report on stderr exactly once (and no other), and the
saved file: byte-identical to the unedited world's for the `same` cases,
otherwise containing the case's line exactly once.

Before the fix, on macOS, every case with *Z* failed: each padded number
read as `0` and its digits shifted into the next field. glibc already gave
every result in the table. The `wrap`, `overflow` and `underflow` cases pass
on both platforms before and after; they pin how an out-of-range number is
stored.
