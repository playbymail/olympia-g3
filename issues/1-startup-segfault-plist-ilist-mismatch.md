# Issue 1 — `olympia-g3` segfaults at startup in `post_production` (all modes)

**Status:** **RESOLVED** — the engine now completes the entire INIT sequence,
enters immediate mode, and exits cleanly (exit 0). Two waves of the same 64-bit
`plist`-queried-as-`ilist` bug were fixed:

1. **`location_trades()`** — the four `loop.h` macros now use the matching
   `plist` accessors (`plist_len` / `plist_reclaim`). (commit `4d57c14`.)
2. **`compute_dist()` and the rest of INIT** — the **`exit_view **` plist cluster**:
   `exits_from_loc_nsew` / `exits_from_loc_nsew_select` cleared their static
   `plist` with `ilist_clear` (vs the sibling `exits_from_loc`'s correct
   `plist_clear`), and **18 callers** iterated the returned `plist` with
   `ilist_len(l)`. Fixed: `dir.c` `ilist_clear → plist_clear` (×2) plus
   `ilist_len(l) → plist_len(l)` at every `exit_view` consumer (seed.c, day.c,
   beast.c, garr.c, immed.c, move.c, npc.c, savage.c, storm.c). Genuine `ilist`
   `l` variables in those files (`static ilist l = ilist_copy(...)` in move.c,
   storm.c, garr.c) were left untouched. See "Wave 2" below.

INIT now reaches `compute_dist()` → `seed_city_near_lists()` → `seed_cookies()`
and on into immediate mode with no crash (mapgen `secret-sea-route` regress still
prints `YES`). The olympia golden gate (playbook Step 0) is no longer blocked by
a startup crash.

**Original status (for history):** open — **root cause confirmed** (a `plist`
queried with the `ilist` length accessor in 4 `loop.h` macros). Fix is a bounded
`loop.h` change; this is Phase 1 list-triage work, *not* Phase 4. See "Root cause
(CONFIRMED)" below.
**Severity:** blocker for **olympia** golden files. The engine can't finish
loading/initializing the DB, so it can't run a turn (`-r -S`) to produce the
saved-DB golden, and the playbook "Step 0" baseline can't be captured. See the
Phase 3.5 note in `CLAUDE.md`. (mapgen goldens are unaffected.)

> **Note:** this is **not** immediate-mode-specific. The crash is in the shared
> **INIT** path (`post_production → location_trades`), which runs before any
> mode-specific work — so it affects *every* invocation (see table below).
> `run/olympia-g3.sh` just hits it first at its `-i` smoke test. **mapgen golden
> files are unaffected** — `mapgen-g3` is a separate binary and works fine.

## Symptom

Every invocation crashes (SIGSEGV, exit 139) at the same spot during INIT:

| invocation | result |
|---|---|
| `-l ./lib` (just load the DB)        | SIGSEGV at `location_trades()` |
| `-r -l ./lib -S` (run a turn + save) | SIGSEGV at `location_trades()` |
| `-i -l ./lib` (immediate mode)       | SIGSEGV at `location_trades()` |

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

## Root cause (CONFIRMED) — `plist` queried with the `ilist` length accessor

The NULL is a `struct trade *` entry read **past the end** of the copied list,
because `loop_trade` mixes the two list ADTs. Verified by debugger + a confirming
code change (below).

`lib/ilist.c` and `lib/plist.c` use the **same header scheme**: `base = l - 2`,
length at `base[0]`, capacity at `base[1]`, data from `base[2]`. But the element
type differs:

- `ilist` is `int *`  → `l - 2` steps back **8 bytes**; header fields are 4-byte.
- `plist` is `void **`→ `l - 2` steps back **16 bytes**; header fields are 8-byte.

`loop_trade` builds `ll_l` as a **plist** (`plist_copy`) but then calls
**`ilist_len(ll_l)`**:

```c
ll_l = (struct trade **) plist_copy((plist) bx[who]->trades);  /* a plist */
for (ll_i = 0; ll_i < ilist_len(ll_l); ll_i++)                 /* WRONG accessor */
```

`ilist_len(ll_l)` reads 8 bytes before `ll_l` — which lands on the plist's
**capacity** field, not its length. Capacity ≥ length, so the loop runs past the
valid entries into the copy's **uninitialized/zeroed tail slots** and
dereferences a NULL `struct trade *` at `->item` (offset 4) → `0x4`.

This matches every observation:
- Empty list (`trades == NULL`): `plist_copy → NULL`, `ilist_len(NULL) → 0`, loop
  body never runs → no crash.
- Non-empty list (≥1 trade): `ilist_len` returns capacity > length → NULL tail
  slot dereferenced → crash.
- The crash is **layout/ASLR-dependent** (the `trades` pointer value and whether
  `find_trade` sees a populated list before `opium_market_delta` populates it
  both vary per run) — which is why a watchpoint run happened to slip past the
  `find_trade` at `buy.c:908` and only wrote `trades` later, at `buy.c:928`.

This is exactly the engine's own startup warning (`main.c:646`, fires when
`sizeof(int) != sizeof(int *)`):

```
The Olympia C code is not 64-bit clean.
at the least: it puts pointers into ilists
```

### Confirmed by experiment
Changing only `loop_trade` to use the matching accessors —
`plist_len((plist) ll_l)` and `plist_reclaim((plist *) &ll_l)` — made the engine
clear `location_trades()` and advance deterministically (3/3 runs) to the **next**
crash, `INIT: compute_dist()`. (Change reverted; the fix should be applied to all
affected macros together — see below.)

### Scope — exactly four macros
Only the loop macros that copy a **pointer**-list (`plist`) but query it with the
**int**-list accessor are affected. The other `ilist_len` loops (`loop_here`,
`loop_units`, `loop_loc_teach`, `loop_all_here`, …) use genuine `ilist_copy`
lists and are **correct**.

| macro | pointer-list copied | `loop.h` | fixed? |
|---|---|---|---|
| `loop_inv` | `bx[who]->items` (`struct item_ent **`) | 287 / 293 | ✅ |
| `loop_char_skill` | `rp_char(who)->skills` (`struct skill_ent **`) | 303 / 309 | ✅ |
| `loop_char_skill_known` | `rp_char(who)->skills` | 318 / 324 | ✅ |
| `loop_trade` | `bx[who]->trades` (`struct trade **`) | 333 / 338 | ✅ |

All four converted to `plist_len((plist) ll_l)` / `plist_reclaim((plist *) &ll_l)`.
The follow-on `compute_dist()` crash is almost certainly one of the other three
(likely `loop_inv`) — but it is **not** in these four macros (they are fixed), so
it is a *different* site. Left as the open "remaining" follow-up above.

## Reclassification — this is Phase 1 (list triage), not Phase 4

Earlier this was filed to revisit "after Phase 4." That was based on the wrong
assumption (a missing-prototype / load-path bug). The real cause is the
ilist→plist 64-bit list triage — the `phase_N_build_flags` "Phase 1 - list
triage" workstream — and is **independent of Phase 4**. The `assert`/`<assert.h>`
change is still worth doing in Phase 4, but does not fix this.

## Recommended fix

In `olympia/loop.h`, for each of the four macros above, change the loop bound and
cleanup to the plist accessors:

- `ilist_len(ll_l)` → `plist_len((plist) ll_l)`
- `ilist_reclaim(&ll_l)` → `plist_reclaim((plist *) &ll_l)`

Then rerun `-i` and keep clearing crashes until the engine completes a turn; each
fix may reveal the next 64-bit-uncleanliness site (`compute_dist` is next).
Once `-i`/`-r` complete, capture the olympia golden gate (playbook Step 0) — the
gate is **blocked only by these crashes**, and mapgen goldens already work.

## Repro recipe

```bash
cmake --build --preset debug
cd run/olympia
export G3_MAPGEN_SEED_1=18481 G3_MAPGEN_SEED_2=28078 G3_MAPGEN_SEED_3=26982
rm -rf lib && tar zxf ../../tests/olympia/fixtures/lib.tgz && rm -f lib/master
lldb -b -o run -o bt -- ../../build/debug/olympia-g3 -l ./lib -i </dev/null
# frame #0: find_trade(who=56761, kind=1, item=93) at buy.c:500, address=0x4
```

## Wave 2 — the `exit_view **` plist cluster (`compute_dist()` and beyond)

After Wave 1 cleared `location_trades()`, INIT advanced and crashed at
`compute_dist_gate` (`seed.c:227`, `EXC_BAD_ACCESS address=0x4`), dereferencing
`l[i]->destination` where the loop bound was `ilist_len(l)` (seed.c:225) and `l`
is the `struct exit_view **` returned by `exits_from_loc_nsew()`. Same class:
`exit_view **` is a **plist** (built via `plist_append((plist *) l, v)` in
`add_province_exit`), but it was iterated with the `ilist` length accessor, which
reads the plist's *capacity* field instead of its length → over-iteration into a
NULL tail slot.

Two defects, both fixed:

- **Producer (`dir.c`).** `exits_from_loc_nsew` (`dir.c:731`) and
  `exits_from_loc_nsew_select` (`dir.c:749`) cleared their `static` plist with
  `ilist_clear(&l)` / `ilist_clear(&ret)` — corrupting the header on the 2nd+
  reuse. The sibling `exits_from_loc` already used `plist_clear((plist *) &l)`
  correctly. Changed both to `plist_clear((plist *) &...)`.
- **Consumers (18 sites).** Every caller that iterates the returned list changed
  `ilist_len(l) → plist_len(l)`: `seed.c` (76, 225, 251), `beast.c` (42),
  `day.c` (29), `garr.c` (272), `immed.c` (561, 590), `move.c` (149, 192, 229),
  `npc.c` (34 `get_exit_dir`, 50), `savage.c` (101, 382, 388), `storm.c`
  (552, 587). The `c1.c` path was already correct (`count_hidden_exits`,
  `hidden_count_to_index`, `find_hidden_exit` in `dir.c` use `plist_len`).

**Deliberately untouched** (genuine `ilist`, not `exit_view`):
`static ilist l = ilist_copy(...)` in `move.c` (852), `storm.c` (1430), and
`garr.c` (171, 857), with their `ilist_clear` / `ilist_len(l)` left as-is.

Verified: clean build; `olympia-g3 -l ./lib -i </dev/null` completes all INIT
stages, enters immediate mode, and exits 0; mapgen `secret-sea-route` regress =
`YES`.
