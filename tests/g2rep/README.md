# g2rep gates

Checks for [tools/g2rep](../../tools/g2rep/README.md), the report formatter
(#368).

```sh
cmake --build --preset debug --target g2rep
tests/g2rep/regress/render/check.sh                              # YES
OLYMPIA_PRESET=asan-ubsan tests/g2rep/regress/render/check.sh    # YES
G2REP_BIN=path/to/formatter tests/g2rep/regress/render/check.sh  # a port's
```

| Gate | Pins |
|---|---|
| `regress/render` | text and `-h` output for each raw report in `input/` (a golden player report, a battle report, a report with day/unit prefixes, second indents and `{html\|text}` spans, an order confirmation and hand-written edge cases), with no stderr and exit 0; plus the usage errors (`EXPECT/usage.log`) |

## The oracle

`oracle/rep.c` is the original `g2rep` source, copied verbatim from
`g3/g2rep/rep.c` in
[playbymail/olympia-tag-v0](https://github.com/playbymail/olympia-tag-v0)
(AGPL-3.0). `check.sh --update` builds it with `cc -std=gnu89 -w` and writes
`EXPECT/` from **its** output, never from the formatter under test. That way the
gate pins the original program's behavior, and a change to the port can't
re-baseline itself. `CC` selects the compiler.

To add a case, put a raw report (from `lib/save/<turn>/<pl>`, or `lib/log/203`
after `olympia-g3 -E`) in `regress/render/input/` and run `--update`.
