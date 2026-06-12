# Issue 2 — Type-safe pointer lists (retire the generic `plist`)

**Status:** open — in progress. **`exit_views_list`, `trades_list`,
`orders_list`, `admits_list`, `item_ents_list`, `skill_ents_list`, and
`order_list.l → cstrings_list`, and `fights_list` (combat.c) migrated** — all
five `oly.h` entity pointer-list fields from the table below (plus `exit_views`,
the inner order-text list, and the combat engine) are now typed. A handful of
**other** plist lists remain (see *Remaining plist types to retire* at the end);
the `plist` typedef cannot be deleted yet (~39 ops, 7 files).
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

> **Progress — `orders_list` (✅ done).** The per-player `orders` field
> (`oly.h:505` → `orders_list`), confined to `order.c` (`plist_len(p->orders)` →
> `orders_len`, the `plist_append((plist *) &p->orders, …)` → `orders_append`).
> 6 line changes, 2 files, **0 new warnings**, golden **YES**, mapgen `YES`.
> Care point: `struct order_list` has its *own* inner list member `l`
> (`p->orders[i]->l`) — a distinct plist left untouched here (the substring
> `plist_len(p->orders)` doesn't match `plist_len(p->orders[i]->l)`, so the field
> ops are cleanly separable). Orders are rebuilt from the text spool, not
> serialized as a plist, so `io.c` needed no change.

> **Progress — `admits_list` (✅ done).** The per-player `admits` field
> (`oly.h:510` → `admits_list`): `perm.c` (the admit-permission engine —
> `admits_len`, `admits_append`, the `admit_comp` qsort comparator) and the
> **save/load** path in `io.c` (`admit_print` / `admit_scan`). 11 line changes,
> 3 files, **0 new warnings**, golden **YES**, mapgen `YES`. Notable: the retype
> exposed *another* latent same-class bug — `admit_print` (the **save** loop)
> used `ilist_len(p->admits)` on the plist, which would over-read into NULL tail
> slots and `admit_print_sup` would deref `->targ` → crash. It is golden-neutral
> here only because this fixture has **zero** admits (`p->admits == NULL`,
> verified: no ` am ` lines in fixture or saved DB), so the loop never ran; the
> fix makes it correct for any DB that does carry admits. The inner
> `struct admit.l` (a genuine `ilist` of box-ids) was left untouched.

> **Progress — `item_ents_list` (✅ done).** The per-entity `items` field
> (`oly.h:487` → `item_ents_list`), a **persisted** inventory list. Covers the
> `loop_inv`/`next_inv` macro in `loop.h` (`item_ents_copy`/`item_ents_len`/
> `item_ents_reclaim`), `report.c` (the `inv_item_comp` qsort comparator params
> + the four `plist_len(bx[num]->items)` qsort-count sites in the two inventory
> views), `u.c` (three `plist_len(bx[who]->items)` scans + the `add_item`
> `plist_append`), and the **save/load** path in `io.c` (`item_list_print` /
> `item_list_scan`, whose by-ref param `struct item_ent ***l` → `item_ents_list
> *l`). 19 line changes, 5 files, **0 new warnings**, golden gate
> **byte-identical** (`YES`, exercises `-S` save → on-disk `fact/*` files),
> mapgen `YES`. This is the field whose `qsort`-count and `ilist_len` mismatches
> were issue-1 waves 1 and 3 — now correct-by-type.

> **Progress — `skill_ents_list` (✅ done).** The per-char `skills` field
> (`oly.h:575` → `skill_ents_list`), a **persisted** list. Covers `loop.h`'s
> **two** macros (`loop_char_skill`/`loop_char_skill_known`, both copying
> `rp_char(who)->skills` → `skill_ents_copy`/`skill_ents_len`/
> `skill_ents_reclaim`), `use.c` (the heavy file: both `rep_skill_comp` /
> `flat_skill_comp` qsort comparator param pairs, `has_skill`/`p_skill_ent`'s
> `plist_len(p->skills)` scans, `add_skill`'s `plist_append`, a
> `plist_rem_value` on `->skills`, and the two `list_skills`/
> `list_partial_skills` local-copy lists with their `plist_copy`/`plist_len`/
> `plist_reclaim` ops), and the **save/load** path in `io.c`
> (`skill_list_print` / `skill_list_scan`, by-ref param `struct skill_ent ***l`
> → `skill_ents_list *l`). 32 line changes, 4 files, **0 new warnings**, golden
> gate **byte-identical** (`YES`, exercises `-S` save), mapgen `YES`. Carefully
> left untouched: the unrelated `req_ents` local `l` in `use.c`'s
> requirement-scan helpers (`plist_len(l)` at ~366–460), which is a different
> list, not skills.

> **Progress — `order_list.l` → `cstrings_list` (✅ done).** The inner
> order-text list `struct order_list.l` (`oly.h:543`, `char **l` — a list of
> saved order strings), distinct from the `orders` field migrated earlier. All
> nine plist ops live in `order.c`: `top_order`/`pop_order`/`queue_order`/
> `prepend_order`'s `plist_len`/`plist_delete`/`plist_append`/`plist_prepend` on
> `p->l`, the `plist_len(p->orders[i]->l)` save-scan, and the two
> `plist_len(l->l)` sites in the order display — all → `cstrings_*` (casts
> dropped). `str_save()` returns `char *`, which `cstrings_append`/`_prepend`
> accept. 10 line changes, 2 files, **0 new warnings**, golden gate
> **byte-identical** (`YES`), mapgen `YES`. Carefully left untouched: the many
> unrelated `char **l` locals elsewhere (`c2.c`, `eat.c`, `display.c`, …) that
> are *not* `order_list.l`; passing a `cstrings_list` to a function still
> declared `f(char **l)` is type-compatible, so no lockstep change is forced.
> After: `grep "plist_.*->l" olympia/order.c` is empty.

> **Progress — `fights_list` (✅ done).** The first list migrated *beyond* the
> issue's five-field table — the entire `combat.c` combat engine. All fight
> lists are **transient locals** (`l` / `l_a` / `l_b` / `enemy`, plus the
> `struct fight ***l` by-ref builders `add_to_fight_list`/`add_fighters`/
> `add_fight_stack`/`look_for_allies`/`reclaim_fight_list`), so **no `oly.h`
> field and no save/load** is touched. 75 `struct fight **` type sites →
> `fights_list` (the `***l` by-ref forms → `fights_list *l`), 51
> `plist_len` → `fights_len`, and the lone `plist_append`/`plist_reclaim`/
> `plist_lookup` → `fights_*`. ~80 line changes, 1 file, **0 new warnings**,
> golden gate **byte-identical** (`YES` — a turn exercises combat heavily),
> mapgen `YES`. This removed the **last `(plist)` read-form cast** in the engine
> (`combat.c:804`) and dropped the remaining plist-op count 93 → 39.
> **Latent bug documented, not fixed:** `construct_guard_fight_list`'s
> `plist_lookup((plist) l_a, i)` (now `fights_lookup(l_a, i)`) looks up an **int
> box-id `i`** in a list of `struct fight *` — comparing pointers against a
> small int, so it effectively always returns `-1` (the "already stacked with
> the pillagers?" guard never fires). The retype preserves this exact behavior
> (same implicit int→pointer conversion); fixing it (a `->unit == i` membership
> scan) would change combat output, so it is deferred as a separate behavior
> change, out of scope for a golden-identical retype.

> **Progress — `flag_ents_list` (✅ done).** The `c1.c` signal-flag list
> (`static struct flag_ent **flags`, `c1.c:1088` — `struct flag_ent` is
> file-local, transient, not persisted) → `flag_ents_list`. Three sites:
> the decl, `v_flag`'s `plist_append((plist *) &flags, …)` → `flag_ents_append`,
> and **a latent same-class bug fixed by the retype** — `flag_raised` iterated
> `ilist_len(flags)` on the **plist** (`c1.c:1096`), reading the wrong header
> word; → `flag_ents_len`. Golden-neutral here (this fixture raises no `flag`
> signals, so `flags == NULL` and both accessors return 0), now correct for any
> turn that does. 3 line changes, 1 file, **0 new warnings**, golden **YES**,
> mapgen `YES`.

## Remaining plist types to retire (future work)

All five `oly.h` entity fields in the table above, plus `exit_views`,
`order_list.l`, and now **`fights_list` (✅ done)**, are typed. **The `plist`
typedef cannot be deleted yet** — ~**39** `plist_` ops remain across **7** files
(was 93 / 8 before `fights_list`), on lists that were out of this issue's
five-field scope. Each already has a ready typed equivalent in `lib/lists.h`;
retiring them is the same mechanical drop-in (census → classify → line-asserted
retype → build → golden gate). Grouped by target typed list, in rough ascending
blast-radius:

| target list | what / where | sites | persisted? |
|-------------|--------------|-------|------------|
| ~~`flag_ents_list`~~ | ✅ **done** (`c1.c` signal `flags`) — see progress note below | — | no (transient static) |
| `accept_ents_list` | the `accept` field (`oly.h:605`, `struct accept_ent **`) — `c1.c:414` (`plist_append`), `c1.c:430` (`plist_len`) | ~2 | check (field-level) |
| `wait_args_list` | the `c->wait_parse` field (`oly.h:868`, `struct wait_arg **`, "not saved") — `c1.c:1177/1183/1195/1216/1301/1306/1309` | ~7 | no |
| `req_ents_list` | `use.c`'s requirement-scan locals `struct req_ent **l` (`use.c:379/427`, `plist_len` at `388/395/413/438/445/460`) **and** the save/load pair `req_list_print`/`req_list_scan` (`io.c:666/700`, by-ref `struct req_ent ***l`) | ~10 | **yes** |
| `cstrings_list` | the `c->parse` field (`oly.h:857`, `char **`; `numargs` already calls `cstrings_len`) built by `parse_line()` (`input.c:33/84`) and used at `input.c:231/271/291/299`; plus local order-text `char **l` in `c2.c` (`155/166/201/218/300/305/473/515`) and `eat.c` (`931/935`) | ~16 | no (rebuilt) |
| ~~`fights_list`~~ | ✅ **done** (`combat.c` combat engine) — see progress note below | — | no (per-turn) |

After the remaining five are migrated, `grep -rn 'plist' olympia/ mapgen/` should be empty
and the `plist` typedef + `lib/plist.c` can be deleted (acceptance item 4); the
typed `_test()` entry points can optionally be wired into a unit check.

> **Not on the list: `roads_list` / `tiles_list`.** Their typed APIs exist
> (`lib/roads.c` / `lib/tiles.c`, compiled into both `mapgen-g3` and
> `olympia-g3`), but they are **dead code** — `struct road` / `struct tile` are
> not even defined in `olympia/`, and grep finds **zero** call sites and **zero**
> `plist` ops touching a road/tile list anywhere in the engine. Nothing holds
> road/tile data in a `plist` under another name, so there is nothing to retire.
> The "equivalent typed lists exist for … `roads`, `tiles`, …" sentence above
> only enumerates the *available* APIs, not lists in active use. (If the
> `_test()`-entry-point unit check lands, these two are the first dead APIs it
> would exercise.)

> **Caveat — separate latent-bug class, *not* a "retire plist" item.** A few
> sites call `plist_len()` on a list that is **already a correctly-typed
> `ilist`** (4-byte elements): `use.c:366` (`p->may_use`, `ilist`), and
> `input.c:446/449/753` + `sort_load_queue(ilist l)` over `load_q[]`
> (`static ilist load_q[]`). On 64-bit these read the wrong header word — the
> same issue-1 defect, in the other direction. They want `ilist_len`, not a
> typed-list retype. Golden-neutral on this fixture, but worth fixing when the
> `combat.c`/`input.c` sweeps land. Left untouched here to keep each commit's
> blast radius to one list type.

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
   pointer-list fields on the core entities (`olympia/oly.h`) — **all done**:

   | field | was | becomes | status |
   |-------|-----|---------|--------|
   | `items` (`oly.h:487`) | `struct item_ent **` | `item_ents_list` | ✅ `9309ee0` |
   | `trades` (`oly.h:488`) | `struct trade **` | `trades_list` | ✅ `925ac54` |
   | `orders` (`oly.h:505`) | `struct order_list **` | `orders_list` | ✅ `2b31593` |
   | `admits` (`oly.h:510`) | `struct admit **` | `admits_list` | ✅ `12cee80` |
   | `skills` (`oly.h:575`) | `struct skill_ent **` | `skill_ents_list` | ✅ `155586d` |

   …plus the `exit_view **` producers/returns in `dir.c`
   (`exits_from_loc*`) → `exit_views_list` (✅ `df39ab9`), and the inner
   order-text list `struct order_list.l` (`char **`, `oly.h:543`) →
   `cstrings_list` (✅ `977ef0b`).

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
