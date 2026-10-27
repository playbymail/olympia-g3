# load-comment-lines — a comment or stray line between boxes

Pins the fix for #316. `read_boxes()` (`olympia/io.c`) reads a box file one
box at a time. On a `#` line it did `continue` without reading the next
line, and on a line that isn't a box header it printed
`read_boxes: unexpected line ...` without reading the next line either. Both
looped forever: silently on a comment, printing without end otherwise. Now
both branches read the next line.

`save_db()` writes neither, so only a hand-edited box file can do this.

## Scenario

No `scenario.patch`. Each case extracts the base world
`tests/olympia/fixtures/world.tgz` and inserts lines before the header of
box 99 in `lib/item`, a box in the middle of the file:

| case | inserted | `unexpected line` reports |
|---|---|---|
| comment | `# a comment between boxes` | 0 |
| blank | an extra blank line | 1 |
| stray | `not a box header` | 1 |
| mixed | `# one`, a blank line, `# two`, `stray` | 2 |

The engine runs with `-l ./lib -S`: no `-r`, so it loads the DB, runs
`check_db()` and saves it. The unedited world, loaded and saved the same
way, is the reference.

## Checks

For each case: exit status 0 within 20 seconds (before the fix every case
hangs and is killed, exit 142); the number of `unexpected line` reports;
and the saved `lib` identical to the reference, so the inserted lines are
dropped and every box after them still loads.
