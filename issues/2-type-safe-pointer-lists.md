# Issue 2 — Type-safe pointer lists (retire the generic `plist`)

**Status:** open — in progress. **`exit_views_list` and `trades_list` migrated**;
the remaining plist fields (`items`, `skills`, `orders`, `admits`) remain.
**Type:** modernization (64-bit list-triage, follow-on to issue 1).
**Motivation:** make the entire class of bug behind issue 1 a **compile error**
instead of a runtime segfault.

> **Progress — `exit_views_list` (✅ done).** All `struct exit_view **`
> producers/consumers now use the typed API: `dir.c`'s `exits_from_loc*` and
> their seven `***l` helpers, plus the ~14 consumer sites across `seed/day/
> beast/garr/immed/move/npc/savage/storm/c1`. `plist_append/clear/len/scramble`
> with `(plist)` casts → `exit_views_append/clear/len/scramble` (casts gone);
> `dir.h` signatures updated in lockstep. 76 line changes, 12 files, **0 new
> warnings**, golden gate **byte-identical** (`YES`), mapgen regress `YES`. No
> `oly.h` field changed (exit_view lists are all transient), so zero save/load
> risk — exactly as scoped. Note: with the casts removed, a reintroduced
> `ilist_len(exit_views_list)` now produces an `incompatible-pointer-types`
> *warning* (previously the `(plist)` cast silenced it entirely); it becomes a
> hard error once `olympia-g3` reaches Phase 2 `-Werror=incompatible-pointer-types`.

> **Progress — `trades_list` (✅ done).** The first **persisted** field migrated
> (`bx[]->trades`, `oly.h:488` → `trades_list`). Covers `buy.c` (the market
> engine: `seller_list`/`buyer_list`/`scan_trades`/`list_market_items`, the
> `seller_comp` qsort, append/clear/delete on `->trades`), the **save/load**
> path in `io.c` (`trade_list_print` / `trade_list_scan`), and the `loop_trade`
> macro in `loop.h` (`trades_copy`/`trades_len`/`trades_reclaim`). 41 line
> changes, 5 files, **0 new warnings**, golden gate **byte-identical** (`YES`,
> and this run exercises `-S` save → on-disk `fact/*` files), mapgen `YES`.
> Crucially distinct from the look-alike `ilist trades_to_check` (a genuine
> `int` list of box-ids), which was left untouched. Also fixed a latent
> same-class bug surfaced by the retype: `immed.c`'s clear-city-trades used
> `ilist_clear(&bx[i]->trades)` on the plist → now `trades_clear` (not on the
> turn path, so golden-neutral, but now correct).

## Problem

The engine stores pointer collections (a character's items, a faction's trades,
a character's skills, a location's exits, …) in a **generic, untyped** reallocing
array, `plist`:

```c
typedef void **plist;                       /* lib/lists.h:151 */
extern int  plist_len(plist l);
extern void plist_append(plist *l, void *n);
/* … */
```

Because every element is a bare `void *`, the type system cannot tell a
`plist` of `struct exit_view *` apart from a `plist` of `struct trade *`, nor a
`plist` (8-byte elements, 8-byte hidden header fields) apart from an `ilist`
(`int *`, 4-byte elements/header). Call sites paper over this with casts:

```c
ll_l = (struct trade **) plist_copy((plist) bx[who]->trades);
for (ll_i = 0; ll_i < ilist_len(ll_l); ll_i++)   /* WRONG accessor — no diagnostic */
```

`ilist_len(ll_l)` on a `plist` reads the wrong header word (the **capacity**,
not the length), the loop runs off the end, and a NULL tail slot is
dereferenced. The compiler is silent the whole way: `(plist)` erases the element
type, and `ilist`/`plist` are unrelated typedefs the cast bridges by force.

### This is not hypothetical — it caused three crash waves (issue 1)

All three startup/turn segfaults fixed under
[[issue 1]](1-startup-segfault-plist-ilist-mismatch.md) were the **same** defect:
a `plist` queried with an `ilist` accessor (or the wrong length in a `qsort`).

| wave | site | list | bug | commit |
|------|------|------|-----|--------|
| 1 | `loop.h` (4 macros) | `items` / `skills` / `trades` | `ilist_len`/`ilist_reclaim` on a `plist` | `4d57c14` |
| 2 | `exits_from_loc_nsew*` + 18 callers | `exit_view **` | `ilist_clear`/`ilist_len` on a `plist` | `9b5171b` |
| 3 | `report.c` inventory `qsort` | `items` | `qsort` count = `ilist_len`, not `plist_len` | `ec7aa0d` |

Every one of these would have been a **build failure** under type-safe lists,
because the typed accessor would not accept the wrong list type, and there would
be no `(plist)` cast to silence it.

## The fix already exists — it just isn't used

`lib/lists.h` already declares a **full set of per-type list APIs**, and each is
already **implemented and compiled** into the build
(`CMakeLists.txt:262–264`):

```c
typedef struct exit_view **exit_views_list;        /* lib/lists.h:58, impl lib/exit_views.c */
extern int  exit_views_len(exit_views_list l);
extern void exit_views_append(exit_views_list *l, struct exit_view *n);
extern void exit_views_clear(exit_views_list *l);
/* … _copy / _delete / _lookup / _prepend / _reclaim / _rem_value / … */
```

Equivalent typed lists exist for `item_ents`, `skill_ents`, `trades`, `admits`,
`orders`, `roads`, `tiles`, `fights`, `req_ents`, `flag_ents`, `wait_args`,
`cstrings`, `accept_ents`. Each stores a **concrete element type** (e.g.
`struct exit_view *`), so:

- `exit_views_len(l)` only accepts an `exit_views_list` — passing a
  `trades_list`, or mixing in an `ilist`/`item_ents_list` accessor, **fails to
  compile**. No cast is needed at the call site, so none is there to hide a
  mismatch.
- The accessor arithmetic is keyed to the element type
  (`exit_views_base(l) = l - 2` in `struct exit_view **` units), so the
  length/capacity offsets are correct **by construction**.

**Current adoption: zero.** Grep finds **0** call sites of any typed-list API in
`olympia/` or `mapgen/`; the engine uses the generic `plist`/`ilist` everywhere
(**196** `plist` call/cast sites across **22** files). The typed `.c` files are
compiled but effectively dead until adopted (their `_test()` entry points are
never called either).

## Layout compatibility (golden-safe)

`lib/plist.c` and the typed implementations (e.g. `lib/exit_views.c`) use the
**identical** memory layout: two hidden slots at the front, `base = l - 2`,
length at `base[0]`, capacity at `base[1]` (both stored as `int` via `memcpy`),
user-visible data at `&base[2]`. For a pointer list the element width is the same
8 bytes either way — only the *static type* differs. So migrating a `plist` field
to its typed equivalent is a **drop-in, behavior-preserving** change: same bytes,
same algorithm, just correct-by-type accessors. This matters because the olympia
golden gate (still to be captured — see issue 1 / playbook Step 0) must stay
byte-identical across modernization steps.

> `ilist` (`typedef int *ilist`) is already element-type-specific and is **not**
> the problem — it stays. The dangerous generic type is `plist` (`void **`).
> Lists of box-id `int`s (`prov_dest`, `link_from`, `link_to`, `units`,
> `deliver_lore`, `neutral`/`hostile`/`defend`, …) correctly remain `ilist`.

## Proposed work

Retire `plist` from the engine in favor of the existing typed lists.

1. **Type the entity fields.** Change the raw `struct X **` declarations to the
   typed typedefs so assignments are checked at the source. The five
   pointer-list fields on the core entities (`olympia/oly.h`):

   | field | now | becomes |
   |-------|-----|---------|
   | `items` (`oly.h:487`) | `struct item_ent **` | `item_ents_list` |
   | `trades` (`oly.h:488`) | `struct trade **` | `trades_list` |
   | `orders` (`oly.h:505`) | `struct order_list **` | `orders_list` |
   | `admits` (`oly.h:510`) | `struct admit **` | `admits_list` |
   | `skills` (`oly.h:575`) | `struct skill_ent **` | `skill_ents_list` |

   …plus the `exit_view **` producers/returns in `dir.c`
   (`exits_from_loc*`) → `exit_views_list`.

2. **Replace generic calls with typed calls, dropping the casts.** At each of the
   ~196 sites, `plist_copy((plist) bx[who]->items)` → `item_ents_copy(bx[who]->items)`,
   `plist_len((plist) l)` → `<type>_len(l)`, `plist_reclaim((plist *) &l)` →
   `<type>_reclaim(&l)`, etc. The `loop.h` macros (`loop_inv`, `loop_char_skill`,
   `loop_char_skill_known`, `loop_trade`) become typed in one place each.

3. **Let the compiler find the rest.** With the fields typed and the casts gone,
   any remaining `ilist_*`/`plist_*`/wrong-`qsort`-count mismatch becomes a
   diagnostic. Fix each as a real bug (as issue 1 did), not with a new cast.

4. **Delete `plist` once unused.** When `grep -rn 'plist' olympia/ mapgen/` is
   empty, remove the `plist` typedef + API from `lib/lists.h`/`lib/plist.c`
   (keep `ilist`). Optionally wire the typed `_test()` entry points into a unit
   check.

### Suggested sequencing

- Do it **per list type**, smallest blast radius first (e.g. `trades` and
  `exit_views` are already well-scoped from issue 1), one type per commit, build
  + run a full `-r -S` turn after each (and, once it exists, the olympia golden
  gate). Keep each commit behavior-identical.
- `exit_views` is the natural first migration: issue 1 wave 2 already enumerated
  every producer and consumer.

## Scope / magnitude

- ~**196** `plist` call/cast sites across **22** `olympia/*.c` files, plus the
  4 `loop.h` macros and the entity field decls in `oly.h`.
- No new code to write for the common cases — the typed APIs and their
  implementations already exist and are built.
- Risk is mechanical-but-broad; mitigated by the per-type sequencing, the
  layout compatibility above, and the full-turn / golden checks.

## Acceptance

- Entity pointer-list fields and `exits_from_loc*` use typed list typedefs.
- No `(plist)` / `(plist *)` casts remain in `olympia/`; ideally the `plist`
  type is deleted.
- A full `-r -S` turn still completes and the (once-captured) olympia golden
  output is byte-identical; mapgen goldens unaffected.
- Re-introducing an issue-1-style mismatch now fails the build.
