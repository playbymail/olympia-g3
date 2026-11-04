# g2rep

`g2rep` turns the engine's report markup into the text a player reads, or into
HTML with `-h`.

```sh
g2rep lib/save/<turn>/<player>      > report.txt
g2rep -h lib/save/<turn>/<player>   > report.html
g2rep lib/log/203                   > confirmation.txt   # after olympia-g3 -E
```

The engine runs it by name from `PATH`: `send_rep()` (`-M`) for turn reports,
`eat()` for order confirmations, and `setup_html_dir()` for HTML reports. Build
it with the other targets (`build/<preset>/g2rep`) and put that directory on
`PATH` before you run `olympia-g3 -M` or `-E` with mail.

## Input

`bottom_out()` in `olympia/sout.c` writes one line per output line:

```
who:html:unit:indent[/second-indent]:day:text
```

| Field | Meaning |
|---|---|
| `who` | the section (an entity number, or a code from `olympia/sout.h`: 0 banner, 1 include, 20 errors, 22 order queues, 23 original message, ...) |
| `html` | 0 for both outputs, 1 for text only, 2 for HTML only |
| `unit` | if not empty, printed as a `unit: ` prefix |
| `indent` | first-line indent; `/second-indent` is added for continuation lines |
| `day` | if not empty, printed as a `%2d: ` prefix |

The lines for the different sections are interleaved in the order the turn
produced them. `g2rep` prints only the include section (`who` 1). Each
`#include N` line there is replaced by every line of section `N`, so the include
section sets the order of the report.

Inside the text, `{html|text}` keeps the HTML side for `-h` and the text side
otherwise, and `{html}` appears only in HTML. A `~` prints as a space. Text
lines wrap at 76 columns (72 with a day prefix), minus the unit prefix, with two
spaces after `.`, `:`, `?` or `!` where words are joined. HTML lines don't
wrap.

The output of a turn report has no mail headers: `send_rep()` writes those. An
order confirmation does have them (`From:`, `To:`, `Subject: Acknowledge`, ...),
because `eat()` puts them in its banner section.

## Source

This is a C11 port of the original `g2rep`, `g3/g2rep/rep.c` in
[playbymail/olympia-tag-v0](https://github.com/playbymail/olympia-tag-v0)
(AGPL-3.0). The original is K&R C that modern compilers reject. A verbatim copy
is kept in [tests/g2rep/oracle](../../tests/g2rep/oracle) as the test oracle.

For any input the engine writes, the port's output is byte-identical to the
original's. When the port was written, it was compared in both modes against 1,137 raw
report files: 1,126 from one turn of every regress fixture, the 8 from the
golden run, two order confirmations, and one hand-written edge-case file. The port differs only where the original had
undefined behavior:

- an indent outside 0..150 is clamped (the original indexed outside its space
  buffer);
- a unit field longer than 97 characters is truncated (the original overflowed
  a 100-byte buffer);
- a line that ends with no newline right after a `}` stops at its end (the
  original read past it).

The gate is [tests/g2rep](../../tests/g2rep/README.md).
