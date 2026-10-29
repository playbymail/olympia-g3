# gm-immediate-missing — GM console commands with a missing argument

Pins the fix for the GM console half of issue #366. The turn-order half is
in [missing-argument](../missing-argument/README.md).

`olympia-g3 -i` (immediate mode) runs one command per line as the GM
player, The Fates [200], through one `struct command`. Its parse vector
keeps its slots between commands, and `oly_parse_cmd()` frees the previous
line first. So a slot past a command's last word is NULL, if no command
filled it, or points into an earlier command's freed line. With no
argument:

| Command | Before the fix | Now |
|---|---|---|
| `be` | printed slot 1 (`'%s' not a valid box.`) | `Must specify a box.` |
| `additem` | printed slot 1 (`%s is not a valid item.`) | `Must specify an item.` |
| `poof` | printed slot 1 (`%s is not a location.`) | `Must specify a location.` |
| `know` | printed slot 1 (`%s is not a skill.`) | `Must specify a skill.` |
| `makeloc` | looked slot 1 up as a subkind | `Must specify a subkind.` |

After a longer command, each was a heap-use-after-free under ASan.

## What `check.sh` asserts

It feeds these commands to `olympia-g3 -l ./lib -i` on a copy of the shared
base world (`tests/olympia/fixtures/world.tgz`):

```
be                        (no command has filled a slot yet)
be 0 aaaa bbbb cccc       be
additem 1 2 3 4           additem
poof 1 2 3 4              poof
know 1 2 3 4              know
makeloc 1 2 3 4           makeloc
```

The longer command of each pair fills slots 1–4 and fails, except
`additem 1 2 3 4`, which gives the GM 2 gold and warns that the GM isn't a
character. The console's replies (the lines after each `200> ` prompt)
must match `EXPECT.txt` byte for byte. The startup banner is left out; it
prints `sizeof(struct box)`, which differs between builds.

This is the first regress fixture that runs the GM console. A port that
runs the spec needs `-i` and these five commands.

## Run it

```bash
./check.sh                              # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh    # same, clean under ASan/UBSan
./check.sh --update                     # re-baseline after a deliberate change
```
