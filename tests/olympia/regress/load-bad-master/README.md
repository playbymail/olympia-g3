# load-bad-master — an out-of-range entry in lib/master

Pins the fix for #321. `fast_scan()` in `olympia/io.c` reads each line of
`lib/master` as `num kind.subkind` and passed the numbers straight to
`alloc_box()`. Nothing checked them:

- a kind or subkind out of range indexed outside `box_head[]` or
  `sub_head[]` (an AddressSanitizer global-buffer-overflow, or a SIGSEGV, or
  silently wrong boxes);
- kind 0 (`T_deleted`) or a box number out of range failed an assert in
  `alloc_box()` (exit 134).

`master` is only an index that `save_db()` writes for a fast load. Now
`fast_scan()` checks every entry before it allocates any box. On a bad entry
it reports it and returns FALSE, and `load_db()` falls back to
`scan_all_boxes()`, which reads the box files. The report is:

```
fast_scan: bad master entry: 150000 4.0
```

A valid entry has `0 < num < MAX_BOXES`, `T_deleted < kind < T_MAX` and
`0 <= subkind < SUB_MAX`.

## Scenario

No `scenario.patch`. Each case extracts the base world
`tests/olympia/fixtures/world.tgz` and rewrites the master entry for box 1
(`1<tab>4.0<tab>item`):

| case | entry |
|---|---|
| kind-high | `1 99.0` |
| kind-negative | `1 -3.0` |
| kind-deleted | `1 0.0` |
| subkind-high | `1 4.99` |
| number-high | `150000 4.0` |

The engine runs with `-l ./lib -S`. The same load and save of the unedited
world is the reference.

## Checks

For each case: exit status 0; no AddressSanitizer or UBSan report on stderr;
one report of the bad entry and the `fast_scan failed, scan_all_boxes()`
stage line; and the saved `lib` matches the reference file for file. Before
the fix, kind-deleted and number-high exit 134 and subkind-high exits 139.
kind-high and kind-negative load, but save a different DB (and kind-negative
is an AddressSanitizer report under `asan-ubsan`).
