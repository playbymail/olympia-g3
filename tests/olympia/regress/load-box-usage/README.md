# load-box-usage — the entity space usage report

Pins the fix for #310. `print_box_usage()` in `olympia/code.c` prints, at
the end of every `load_db()`, how many boxes are used in each id range. Two
of its ranges disagreed with the entity coding table at the top of the same
file:

- `locs` was 20000–59999. It missed the provinces at 10000–19999 and
  overlapped `play`, `lloc`, the regions and the start of `subl`.
- `rest` started at 79900, not 79000.

Each range also counted `high - low + 1` slots but printed and divided by
`high - low`, so a full range reported more than 100%.

Now `locs` is 10000–49999, `rest` is 79000–149999 (`MAX_BOXES - 1`), and each
total is `high - low + 1`. `char` stays 1000–9999, the range `new_ent()`
allocates characters from.

## Scenario

No `scenario.patch`. The fixture extracts the base world
`tests/olympia/fixtures/world.tgz` and runs `-l ./lib`: it loads the DB and
exits.

## Checks

The report on stderr, from `entity space usage:` to its last range, matches
`EXPECT.usage`. `./check.sh --update` rewrites it from the C engine.
