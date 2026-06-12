# Issue 1 — `olympia-g3 -i` (immediate mode) segfaults during startup

**Status:** open — deferred to **after Phase 4**.
**Severity:** blocker for the olympia golden gate (the engine can't complete a
turn, so the playbook "Step 0" baseline can't be captured). See the Phase 3.5
note in `CLAUDE.md`.

## Symptom

```bash
./run/olympia-g3.sh            # runs olympia-g3 -l ./lib -i </dev/null
# ... SIGSEGV (exit 139) during INIT
```

Output reaches, then crashes:

```
INIT: post_production()
compute_civ_levels()
location_trades()
Segmentation fault: 11
```

Reproduces on a freshly extracted fixture DB (`tests/olympia/fixtures/lib.tgz`,
with `lib/master` removed as the run script does).

## Where it crashes

- `find_trade(who=56761, kind=1, item=93)` at `olympia/buy.c:500`, inside the
  `loop_trade` macro (`olympia/loop.h:333`).
- `EXC_BAD_ACCESS (code=1, address=0x4)` — a NULL pointer + offset 4.
- Call path (intermediate frames inlined at `-Og`):
  `post_production() → location_trades()` (`buy.c:1065`)
  `→ loc_trade_sup()` / `opium_market_delta()` `→ find_trade()` `→ loop_trade`.

`loop_trade(who, e)` expands to:

```c
assert(valid_box(who));
ll_l = (struct trade **) plist_copy((plist) bx[who]->trades);
for (ll_i = 0; ll_i < ilist_len(ll_l); ll_i++)
    if (valid_box(ll_l[ll_i]->item) && ll_l[ll_i]->qty > 0) { e = ll_l[ll_i]; ...
```

## Ruled out

### Not the empty input stream
A tester suggested the crash came from reading an empty stream (`</dev/null`).
**Refuted** — the crash is identical regardless of stdin, and happens during
INIT *before* the interactive input loop reads anything:

| stdin | result |
|-------|--------|
| `</dev/null` (empty)        | SIGSEGV at `location_trades()` |
| `printf 'quit\n' \|` (non-empty) | SIGSEGV at `location_trades()` |
| `(sleep 5) \|` (never EOF)  | SIGSEGV at `location_trades()` |

### Not the custom `assert` macro (on its own)
olympia-tag reportedly fixed *its* `-i` crash by deleting the legacy custom
`assert` and using the stdlib (`<assert.h>`). The custom macro in `olympia/z.h`
is a real latent hazard — an unbraced if-statement:

```c
#define assert(p)  if(!(p)) asfail(__FILE__, __LINE__, #p);
```

In any `if (c) assert(x); else ...` it silently steals the `else`
(dangling-else). **But applying that fix to g3 did NOT fix this crash.** We
removed the custom macro, pulled in `<assert.h>` via `legacy.h`, confirmed it
took effect (`buy.c.o` no longer references `asfail`), and the segfault
persisted byte-for-byte. (Change was reverted; see "Recommended next steps".)

Why it doesn't help here: `assert(valid_box(who))` only guards `who`. It never
fired (no `asfail`/abort under the old macro either), which means **`bx[who]` is
a valid, non-NULL box.** The NULL is deeper.

## Current best diagnosis (unconfirmed)

The NULL is a **bad/NULL entry in the box's `trades` list**, not `who`:
`loop_trade` copies `bx[who]->trades` and then dereferences `ll_l[ll_i]->item`
(and `->qty`). A NULL or dangling `struct trade *` entry, read at the `item`
field (offset 4), yields the `0x4` fault. This is consistent with either:

- a NULL/dangling entry **persisted in the fixture DB** (so no code change alone
  fixes it — the loader reads the bad entry from disk), and/or
- a **64-bit pointer-truncation hazard** in how trades are loaded/stored (the
  exact class Phase 4 targets: implicit-int returns truncating pointers, etc.).

Not yet pinned to the exact NULL (box pointer vs. trade-list entry) because the
`-Og` build inlines the intermediate frames and lldb couldn't evaluate the
locals. Needs a `-O0` or `asan-ubsan` build to confirm.

## Why defer to after Phase 4

Phase 4 gives every function a real prototype and adds the real libc/`<assert.h>`
headers, which (a) surfaces 64-bit pointer hazards in the trade-load/parse path
that may *be* this bug, and (b) is the natural home for the stdlib-`assert`
switch. Revisiting on a post-Phase-4 tree, with the `asan-ubsan` preset, is the
efficient path.

## Recommended next steps (post-Phase 4)

1. **Pin the exact NULL.** Build `asan-ubsan` (or a one-off `-O0`) and rerun
   `olympia-g3 -l ./lib -i`. ASan should name the precise faulting pointer and
   line (box vs. trade-list entry).
2. **Adopt stdlib `assert`** as part of Phase 4 (remove the custom macro from
   `olympia/z.h`; `#include <assert.h>` — `z.h` already includes `legacy.h`
   first, so adding it there covers every TU). Correct modernization matching
   olympia-tag; documented here as it does *not* fix this crash by itself.
3. **Diff against olympia-tag**, which runs `-i` cleanly: compare `loop_trade`
   (`loop.h`), `find_trade`/`loc_trade_sup` (`buy.c`), and the trade
   load/parse path for an added NULL guard or a pointer fix. (Comparison was
   interrupted before completing.)
4. **Then capture the olympia golden gate** (playbook Step 0) — currently
   blocked by this crash.

## Repro recipe

```bash
cmake --build --preset debug
cd run/olympia
export G3_MAPGEN_SEED_1=18481 G3_MAPGEN_SEED_2=28078 G3_MAPGEN_SEED_3=26982
rm -rf lib && tar zxf ../../tests/olympia/fixtures/lib.tgz && rm -f lib/master
lldb -b -o run -o bt -- ../../build/debug/olympia-g3 -l ./lib -i </dev/null
# frame #0: find_trade(who=56761, kind=1, item=93) at buy.c:500, address=0x4
```
