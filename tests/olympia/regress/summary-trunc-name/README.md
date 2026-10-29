# summary-trunc-name — the unit summary truncates long names

Coverage for the fix for #359. `summary_trunc_name()` in `olympia/report.c`
fits a name into the unit summary's 15 columns. It strips a leading stop word
(`the`, `of`, `a`, ...), cuts back to the last space at or before byte 15, and
then strips trailing stop words.

For a name with no space in its first 15 bytes, `prev_word()` walks back to
the start and returns NULL. The stop-word loop then passed that NULL back into
`prev_word()`, which compares it with `>` against the string. A relational
comparison with a null pointer is undefined in C. In practice it is false and
the name is cut to its first 15 bytes. Now the loop stops when the pointer is
NULL, with the same output.

No sanitizer in our presets checks pointer comparisons, so this fixture passes
before and after the fix. It pins the output a port must match.

## Scenario

No `scenario.patch` of its own. Each case unpacks the `trade-market`
scenario (Greyfell, 57081), removes its orders, and renames Buyer One [4126]
in `fact/300`. One turn runs.

| case | name | summary name |
|---|---|---|
| unbroken | `abcdefghijklmnopqrst` | `abcdefghijklmno` |
| stop-words | `The Lord of the Rings` | `Lord` |
| word-break | `Sword of Kings Forever` | `Sword of Kings` |
| short | `Buyer One` | `Buyer One` |

`stop-words` drops the leading `The`, cuts `Rings`, then strips `the` and `of`
until the walk passes the first word.

## Checks

For each case: exit status 0; no AddressSanitizer or UBSan report on stderr;
and faction 300's unit summary line for 4126 (`save/1/300`) ends with the
summary name.
