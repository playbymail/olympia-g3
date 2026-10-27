# order-quoted-comment — a # inside quoted order text is kept

Pins the fix for #315. `remove_comment()` (`olympia/input.c`) cuts an order
at its first `#`, and was meant to skip quoted text first, so that
`name "Joe #1"` keeps its `#`. Its inner loop started on the opening quote
and stopped at once, so quotes were never skipped: every `#` cut the
order. When a quote was the last character, the scan also stepped past the
string's NUL and kept reading, which is undefined behavior.

Now a quote counts only at the start of a token, as in `parse_line()`,
which splits the order into arguments. A `#` inside quoted text is kept,
an unterminated quote runs to the end of the line, and an apostrophe
inside a word (`Joe's`) is ordinary text, so a comment after it is still
cut. The same function strips comments from mailed orders (`eat.c`).

## Scenario

`order-quoted-comment.lua`, frozen as `scenario.patch` over the base world
by `build-scenario.sh`. Six factions start in Greyfell, and each noble
renames itself with one order:

| noble | order | new name | before the fix |
|---|---|---|---|
| 4126 | `name "Joe #1"` | `Joe #1` | `Joe` |
| 8651 | `name Joe's keep # note` | `Joe's keep` | same |
| 8159 | `name 'Ann #2' # note` | `Ann #2` | `Ann` |
| 7012 | `name "Bob # x` | `Bob # x` | `Bob` |
| 6947 | `name Cal "` | `Cal ` | same, after reading past the NUL |
| 8731 | `name Dee # "hi"` | `Dee` | same |

`Cal ` keeps a trailing space: `parse_line()` makes an empty argument of
the lone quote, and `rest_name()` joins it with a space. That is unchanged.

## Checks

Exit status 0 with no sanitizer report; each new name in `lib/fact/30x`
and each echoed order in `lib/save/1/30x`; `EXPECT.sha256` over each
faction's report and unit state; `EXPECT.json`, the `--state-export`
snapshot. Re-baseline with `./check.sh --update`.
