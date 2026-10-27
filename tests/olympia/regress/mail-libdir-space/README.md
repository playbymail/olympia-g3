# mail-libdir-space — mailing and HTML reports with a libdir holding a space

Pins the fixes for #325 and #326. These functions built shell commands from
paths under the libdir without quoting them:

| function | file | command |
|---|---|---|
| `send_rep()` | `olympia/main.c` | `zcat`/`gzcat %s > %s`, `g2rep %s >> %s`, `g2rep %s \| unexpand -t8 >> %s`, `entab %s %s`, `sendmail -t -f %s < %s` |
| `eat()` | `olympia/eat.c` | `g2rep %s/log/%d \| ...sendmail -t -f %s` |
| `setup_html_dir()` | `olympia/main.c` | `mkdir %s\html\%s` (`-w`) |
| `set_html_pass()` | `olympia/main.c` | `htpasswd [-c] -b %s %s "%s"` |
| `output_html_rep()` | `olympia/main.c` | `g2rep -h %s/save/%d/%d > %s` |
| `copy_public_turns()` | `olympia/main.c` | `copy %s %s` (`-w`), `sed -e '...' < %s > %s` |

With `-l "./my lib"`, every one of them saw `./my` and `lib/...` as two
words. Now:

- each path goes through `sh_quote()` (`olympia/u.c`), which wraps it in
  `'...'`;
- `sendmail -f` gets `sender_addr(from_host)`, the bare address. Before,
  the stock `skrenta@pbm.com (Rich skrenta)` split into three words and
  `sendmail` took `(Rich` and `skrenta)` as recipients;
- `htpasswd` runs with `-i` and reads the password on stdin. Before, the
  player's password went on the command line inside `"..."`, so a password
  holding `"`, `` ` `` or `$` ran in the shell. The Unix branch also
  redirected with `&> /dev/null`, which `sh` reads as "run in the
  background", so the `-c` retry never ran; it is now `> /dev/null 2>&1`.
  The `-w` branch still uses the fixed `lib\.htpasswd`;
- the `-w` `mkdir` calls `mkdir()`, as the Unix branch did, and the public
  turn copy is done in C (`copy_public_turn()`), stopping at the
  `<name="Order template">` line as the `sed` did.

The fix doesn't change golden output: no gate ran these paths before.

## Scenario

The frozen `player-settings` scenario (its player 300 has an email address
and a `public` turn) is extracted into `my lib`. The fixture then moves
`htpasswd_loc` to `<work>/my lib/ht passwords` and sets player 300's
password to `` x"$(touch PWNED)`touch PWNED2`'y ``.

Stub `g2rep`, `zcat`, `sendmail`, `htpasswd` and `unexpand` go first on
`PATH`. Each logs one line: its arguments as `[word]`s, then, for
`sendmail` and `htpasswd`, `<` and the first 60 bytes of its stdin. `g2rep
-h` prints `report <file>`, an order-template line and one more line.

Three runs, all with `-l "./my lib"`:

| run | flags | reaches |
|---|---|---|
| A | `-r -S -M -h` | `send_rep()` (plain report, `notab`), `setup_html_all()` and `copy_public_turns()` |
| B | `-M`, after gzipping `save/1/300` | `send_rep()`'s `zcat` path |
| C | `-E -M`, one spooled order message with a wrong password | `eat()`'s ack, through `unexpand` |

## Checks

- Every run exits 0.
- The stubs' log matches `EXPECT.calls`, with the work dir written
  `@WORK@`. Run C's lines are sorted: its stubs run as one pipeline and
  log in either order.
- No `PWNED` file exists.
- `html/300/index.html` starts with `report ./my lib/save/1/300`, and
  `public/1.300` is just that line.

Before the fix the log shows split words (`g2rep [./my]
[lib/save/1/300]`), `htpasswd -b` with the password as an argument, and no
mail sent.
