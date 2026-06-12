# Prototypes & declarations modernization — playbook

A field guide for turning the three "Phase 4" warning classes into hard
errors on a legacy Olympia C engine:

- `-Werror=strict-prototypes`
- `-Werror=missing-prototypes`
- `-Werror=implicit-function-declaration`

This was worked out doing G1. **G2, G3, and TAG share the same ancestry and
the same hazards** — read this before repeating the exercise. The goal each
time: clean `-Werror` for those three flags with **byte-identical golden
output** (no behaviour change).

### Step 0 — validate the golden baseline *before* you touch anything

**Do this first, every time, on a clean checkout.** The entire contract for this
work is "byte-identical golden output," which is meaningless if the baseline was
already red (or never generated) when you started. Before the first edit:

1. Build clean and run the engine end-to-end:
   `cmake --build --preset debug && ./run/mapgen/mapgen.sh && ./run/olympia-<engine>.sh`
2. Run the golden gate and confirm it prints `YES`:
   `./tests/olympia/golden_check.sh`
3. If there is **no** `golden_check.sh` yet for this engine (g3/tag will not have
   one), create it first — copy g2's `tests/olympia/golden_check.sh` as the
   baseline and adapt `OLYMPIA_ENGINE` and any per-engine flaky-file handling —
   then run `./tests/olympia/golden_check.sh --update` once on the **pristine,
   unmodified** tree to capture the baseline, and commit that golden separately
   *before* starting modernization. A golden captured after you've already
   changed code bakes your change into the contract and is worthless.
4. Re-run the gate once or twice across clean rebuilds to learn the engine's
   *inherent* non-determinism (see g2's `st -32` flicker under "Verification
   gate"). You must know what already flickers on an untouched tree so you don't
   later misattribute it to your change.

Only once the gate is green on the untouched tree should you begin Phase 3.5/4.

### Look at the finished G1 first

G1 is **done** through Phase 4 — all three classes are `-Werror` and measure 0.
Before starting g2/g3/tag, read the completed work as a worked example. As of
this writing the changes are **not pushed**, so read them from the local
checkout:

```
/Users/wraith/Software/playbymail/olympia-g1
```

Specifically worth a look:
- `git log --oneline` there — the Phase 4 work is the run of `Phase 4:` commits
  (`git show <sha>` for each); they are small and single-purpose by area.
- `olympia/proto.h` and `mapgen/proto.h` — the generated prototype headers, and
  how they're wired in (`oly.h` tail; the map generator's own header).
- `olympia/z.h` / `mapgen/z.h` — the libc-include chokepoint (see "Legacy
  shadow macros vs. real system headers" below).
- `CMakeLists.txt` — the flipped `-Werror` flags inlined per target and the
  `LEGACY_C_FLAGS` suppressions that were deleted.
- `CLAUDE.md` "Modernization status" — the phase ladder and what each phase did.
- `doc/phase4-tools/` — the reusable scripts.

### Do a Phase 3.5 (dead-code removal) first, too

G1 ran a **Phase 3.5 — remove dead/unused source files** *before* Phase 4, and
it paid off: prototyping is much easier when you aren't generating prototypes
for, or chasing warnings in, files that nothing compiles or links. g2/g3/tag
each carry their own dead `lib/*.c` modules and `#if 0` blocks — add the same
step. The method (from G1's CLAUDE.md "Phase 3.5"):

- Find `.c` files that are in no `target_sources` / build target — they never
  compile, so their warnings are noise and their list types are often unused.
  Delete them and prune the now-dangling declarations.
  - G1 removed: `accept_ents.c`, `effects.c`, `entity_builds.c`,
    `checked_alloc.c`, `ring_buffer.c`.
  - **G2 removed only `effects.c`, `entity_builds.c`, `ring_buffer.c`(+`.h`)** —
    in G2 `accept_ents.c` and `checked_alloc.c` are *live* (both in
    `olympia-g2`'s `target_sources`), so they stayed. **The dead-file set is
    not the same across engines — grep each basename against `CMakeLists.txt`
    yourself; don't copy G1's list.**
- Keep anything the upcoming 64-bit work will need even if currently unwired
  (G1 and G2 both kept `plist.c` — a `void *` list — for later).
- Verify byte-identical golden output after a clean build before moving on
  (`./tests/olympia/golden_check.sh` → `YES`).

Doing this first shrinks the Phase 4 surface and avoids "fixing" code destined
for deletion.

---

## The one thing to internalize

The three flags are not independent, and the most dangerous interactions are
invisible until you probe for them:

1. **K&R definitions are still present** even when `-Wold-style-definition`
   reports zero. Clang reports a K&R definition (`int f(a,b) int a; char *b;
   {`) under **`-Wdeprecated-non-prototype`**, *not* `-Wold-style-definition`.
   G1's CLAUDE.md claimed K&R defs were "already gone" — that was measured
   with the wrong flag. G1 actually had **95** of them (54 in the map
   generator alone).

2. **`-Werror=strict-prototypes` promotes `-Wdeprecated-non-prototype` to a
   hard error**, because clang treats the deprecated-non-prototype diagnostic
   as belonging to the strict-prototypes group for definitions. So the moment
   you flip `-Werror=strict-prototypes`, every surviving K&R or empty-paren
   *definition* breaks the build — even though `-Wno-deprecated-non-prototype`
   is in the flag list. (Flag *ordering* matters: the later
   `-Wstrict-prototypes` re-enables the group that the earlier
   `-Wno-deprecated-non-prototype` silenced. See "Flag ordering" below.)
   **Conclusion: you must convert every K&R/empty-paren definition to ANSI.
   There is no flag-only shortcut.**

3. **Under C11 + clang, `implicit-function-declaration` is a hard error by
   default** (ISO C99+ dropped implicit declarations). That is *why* the
   legacy flag list carries `-Wno-implicit-function-declaration`. On a 64-bit
   target this is the dangerous class: an implicitly-declared function is
   assumed to return `int`, which **truncates a returned pointer to 32 bits**.

---

## Order of operations (each step keeps golden green; flip the flags LAST)

1. **Convert K&R definitions to ANSI.** Probe for them with
   `-Wdeprecated-non-prototype` (see below). Filter to the message *"a
   function definition without a prototype"* — the same flag also fires on
   *calls* through old-style decls (*"passing arguments to X..."*) and on
   conflicting empty-paren *declarations*, which are not definitions.
2. **Convert empty-paren definitions `name()` → `name(void)`.** These are
   also under `-Wdeprecated-non-prototype` / `-Wstrict-prototypes`. Note the
   asymmetry in step "Empty-paren defs hidden behind a decl" below.
3. **Generate a prototype header from the definitions** and include it
   everywhere. This is the single biggest lever — it clears almost all of
   `missing-prototypes` *and* the internal `implicit-function-declaration`
   calls at once. (Details + gotchas below.)
4. **Delete now-redundant empty-paren forward declarations** — the big
   command-handler blocks (`int v_foo(), d_foo();`) in the dispatch-table
   files, scattered `extern T foo();` lines, and empty-paren decls in headers.
5. **Add libc `#include`s** for the standard functions still called
   implicitly (string.h, stdlib.h, unistd.h, time.h, …). On a strict SDK this
   is the hard part, not a rubber stamp — the engine's own `bzero`/`abs`/`wait`
   macros collide with the real headers. See "Adding libc headers" below.
6. **Flip the three flags to `-Werror`**, delete the now-dead
   `-Wno-implicit-function-declaration` and `-Wno-deprecated-non-prototype`.
7. **Update CLAUDE.md.**

---

## Measurement / probe recipe

The legacy flag list *suppresses* the very warnings you need to count, and
suppression ordering hides them. Probe on a throwaway copy:

```bash
rm -rf /tmp/probe && cp -r . /tmp/probe && cd /tmp/probe && rm -rf build*
# strip the suppressions you want to surface
sed -i '' '/-Wno-implicit-function-declaration/d; /-Wno-deprecated-non-prototype/d' CMakeLists.txt
# enable as plain warnings; keep the build alive so you see ALL of them
cmake -S . -B b -G Ninja \
  -DCMAKE_C_FLAGS="-Wstrict-prototypes -Wmissing-prototypes \
    -Wno-error=implicit-function-declaration -Wno-error=int-conversion \
    -Wno-error=incompatible-pointer-types -Wno-error=int-to-pointer-cast \
    -Wno-error=pointer-to-int-cast" >/dev/null 2>&1
cmake --build b > probe.log 2>&1
```

Then dedupe to unique source sites (raw counts are inflated ~N× because a
header warning repeats per including TU):

```bash
grep -E '\[-Wstrict-prototypes\]' probe.log \
  | grep -oE '(olympia|lib|mapgen)/[a-z0-9_.]+:[0-9]+:[0-9]+' \
  | sort -u | wc -l
```

Gotchas that cost real time on G1:
- **`-Wimplicit-function-declaration` added via `CMAKE_C_FLAGS` is overridden**
  by `-Wno-implicit-function-declaration` in `target_compile_options` (target
  options come *after* `CMAKE_C_FLAGS`). You must *delete* the `-Wno-` line
  from `CMakeLists.txt`, not just add the positive flag.
- Re-enabling `implicit-function-declaration` makes it a **hard error** (C11),
  which stops each TU at its first hit and *undercounts*. Use
  `-Wno-error=implicit-function-declaration` to keep it a warning so the build
  completes and you see the full list.

---

## K&R → ANSI conversion

Olympia K&R defs are extremely regular:

```
int add_road(from, to_loc, hidden, name)
struct tile *from;
int to_loc;
int hidden;
char *name;
{
```

Conversion rule that's provably behaviour-neutral: **rewrite only the
parameter list on the name line, delete the K&R declaration lines, leave the
return type byte-for-byte untouched.** (A script that does exactly this is in
`run/scratch/kr2ansi.py`.) Process bottom-to-top so line numbers stay valid.

Cases to handle: pointer params (`int *row`), multi-var lines
(`int row, col;`), pointer-to-struct (`struct tile *from`), typedef'd list
types (`tiles_list l`), array params (`unsigned short seed16v[3]`), trailing
comments on the name line, implicit-int return (leave it — don't add `int`;
that's a separate `-Wimplicit-int` concern, not in scope).

**Macro-generated K&R defs exist.** G1's `z.c` has a `NEST(TYPE,f,F)` macro
that expands to a K&R definition (the drand48 family). ctags can't see them,
and the converter can't either — fix the macro by hand.

**The RNG is golden-critical.** Olympia ships a vendored SysV `drand48.c`
(`drand48/erand48/lrand48/mrand48/srand48/seed48/lcong48/nrand48/jrand48` +
a static `next()`). The local definitions deliberately override libc so the
pseudo-random sequence — and thus all golden output — is deterministic.
Convert it carefully; never "simplify" it.

---

## Generating the prototype header

The high-leverage move. Two approaches, in order of robustness:

- **Source-based extraction (preferred).** For each function clang flags as
  `missing-prototypes` you get `file:line:name`. Read the definition: params
  are on the name line (single line in this code base), return type is the
  name-line prefix or the immediately-preceding line, else implicit `int`.
  Emit `extern <ret> <name>(<params>);`. See `run/scratch/gen_proto3.py`.
- **universal-ctags** (`--_xformat="%N %{typeref} %{signature}"`) works but its
  `typeref` is unreliable for implicit-int functions (it grabs a neighbouring
  type) and emits `struct:tag` colon syntax. Use it only as a cross-check.

**Why this clears three birds:** every definition now has a visible matching
prototype (`missing-prototypes` gone), and every caller that includes the
master header sees it (`implicit-function-declaration` gone for internal
calls). What remains implicit is *only libc*.

### Gotchas (all hit on G1)

- **The compiler verifies you.** A wrong extracted prototype → `conflicting
  types` error; a wrong arg type at a call site → `int-conversion` /
  `incompatible-pointer-types` (already `-Werror` from earlier phases). So
  extraction mistakes fail loudly rather than corrupting behaviour.

- **C prototype-scope rule / file-private structs.** If a function takes a
  `struct foo *` where `struct foo` is defined privately inside one `.c`
  file (not in any header), the *first* mention of `struct foo` — inside the
  generated prototype's parameter list — creates a **distinct prototype-scope
  tag**, and you get `conflicting types` / "incompatible `struct foo *` to
  `struct foo *`". **Fix: forward-declare those tags at the top of the
  prototype header** (`struct foo;`) so the prototypes bind to the real
  file-scope tag. Find them with: structs defined in `.c` files. (G1: build_ent,
  harvest, make, wield, fight, cookie_monster_tbl.)

- **Type visibility / include placement.** The prototype header references
  engine structs, list typedefs, `FILE`, etc. Include it at the **end of the
  master header** (`oly.h`), after all type definitions, and make sure
  `FILE` is available (add `#include <stdio.h>`). The header will look broken
  to an IDE/LSP analyzing it in isolation — that's expected; it only compiles
  in context.

- **The one file that doesn't include the master header.** G1's `z.c` (the
  low-level util/RNG layer) deliberately doesn't include `oly.h`, so it never
  saw the prototype header and its own functions stayed `missing-prototypes`.
  Declare those in the low-level header it *does* include (`z.h`), not the
  generated one.

- **Separate build targets need separate headers.** The map generator is its
  own executable that doesn't include `oly.h`; it needs its own generated
  prototype header included from *its* header.

---

## Removing redundant empty-paren declarations

Once the prototype header exists, the legacy forward declarations are dead
weight and each is a `strict-prototypes` site:

- **Dispatch-table handler blocks.** Files with a command table carry a big
  block like `int v_look(), v_stack(), ...;` declaring every handler. Delete
  the whole block — the handlers are in the prototype header. (G1: ~357 sites
  across `use.c` + `glob.c`.)
- **Scattered `extern T foo();`** local decls — redundant, delete.
- **Empty-paren decls embedded in macros** (G1's `loop_known` macro held
  `extern int int_comp();`). Give them the real prototype.
- **Header empty-paren decls** (`extern void foo();`) — give the full
  prototype, matching the definition.

### Empty-paren defs hidden behind a decl (subtle)

An empty-paren *definition* `void f() {}` that has a **prior empty-paren
declaration** is NOT separately flagged by `-Wstrict-prototypes` (only the
declaration is). But the instant you fix that declaration to `f(void)`, the
`()` definition *becomes* flagged (and `-Werror=strict-prototypes` makes it
fatal). **So fix the declaration and its definition together.** Don't trust
the strict-site list alone for definitions — sweep all `name()` definitions
tree-wide (probe with `-Wdeprecated-non-prototype`, message "a function
definition without a prototype").

---

## Adding libc headers: legacy shadow macros vs. real system headers

Once the engine's own functions are prototyped, the only implicit calls left
are **libc** (G1: ~23 names — `strchr strcmp strcpy strncmp strncpy strcat
strlen memset malloc realloc free atoi abort exit system mkdir chmod open close
read unlink sleep time getpid isatty`). These are the headline 64-bit hazard:
an implicit `strchr`/`malloc` is assumed to return `int`, **truncating the
returned pointer to 32 bits.** You must give them real prototypes by including
the real headers (`string.h`, `stdlib.h`, `unistd.h`, `time.h`, `fcntl.h`,
`sys/stat.h`, …) — but on a strict SDK (macOS was where this bit) the legacy
code fights back. Budget real time for this; it was the single hardest part of
G1's Phase 4.

**The trap: the engine #defines libc names as function-like macros.** Olympia
defines `bzero`/`bcopy`/`abs` (in `z.h`) and `wait` (in `oly.h`) as macros.
When you include the matching system header *after* the macro is active, the
macro rewrites the system's *declaration* and you get a cascade of
`conflicting types` / `expected ')'` / `expected parameter declarator` errors
deep inside `/usr/include`:

```
/usr/include/_strings.h:75:7: error: conflicting types for 'memset'
  note: expanded from macro 'bzero'   (#define bzero(a,n) memset(a,'\0',n))
/usr/include/_stdlib.h:148: error: expected ')'   from macro 'abs'
/usr/include/sys/wait.h:246: error: expected ')'  from macro 'wait'
```

Note the transitive pulls: `<string.h>` drags in `<strings.h>` (→ `bzero`,
`bcopy`); `<stdlib.h>` drags in `<sys/wait.h>` (→ `wait`) and declares `abs`.

**The fix — ordering, not deletion.** A function-like macro that is defined
*after* the real declaration simply shadows the name for subsequent code; that
is legal and harmless, and it preserves the legacy macro's exact semantics
(important: `bcopy`→`memcpy` is *not* overlap-safe like real `bcopy`, so you
must keep the macro, not switch to libc). So: **include the system headers
before the shadow macros are defined.**

Find every colliding macro up front:

```bash
grep -rnE '^[ \t]*#[ \t]*define[ \t]+(abs|labs|div|wait|exit|system|atoi|malloc|calloc|realloc|free|rand|srand|qsort|getenv|bzero|bcopy|mem(set|cpy|move)|str[a-z]+|index|rindex|time|clock|read|write|open|close|stat|link|unlink|sleep|getpid|kill|signal)\b' \
  <engine>/*.h lib/*.h
```

**Use the lowest-level header as a single chokepoint.** In G1 every engine TU
includes `z.h` *before* `oly.h` (verify this ordering across all `.c` first —
it's what makes the trick safe). `z.h` is also where `bzero`/`bcopy`/`abs` live.
So put the libc `#include`s at the **very top of `z.h`, above those macros**:

- every TU now sees real libc prototypes (one edit, ~50 files);
- the shadow macros are defined after the system declarations → no collision;
- `z.h` pulls `<sys/wait.h>` (via `stdlib.h`) before `oly.h`'s later `wait`
  macro, so that one is covered too, for free, by the include ordering.

`mapgen` is a separate target with its own `mapgen/z.h` — it already had its
includes above its macros (which is why it didn't break); match that.

The **one file that doesn't go through the chokepoint** is `z.h`/`z.c`'s own
RNG layer if it doesn't include the master header. G1's `z.c` includes `z.h`
directly, so the chokepoint covers it; just confirm. Watch the vendored
`drand48` family: `z.c` *defines* `erand48` (via the `NEST` macro), so a local
`extern double erand48()` is a redundant self-redeclaration — delete it and let
the in-file definition serve. In `mapgen`, `erand48` is **libc** (no local
def), so `<stdlib.h>` declares it; verify `seed` is `unsigned short[3]` so the
prototype typechecks, then delete the local decl.

**qsort is the sleeper.** Comparators look fine until `<stdlib.h>` gives `qsort`
a real prototype — *then* every K&R comparator mismatches
`int(*)(const void*,const void*)`. If a prior pass "canonicalized comparators"
but qsort was never prototyped, stragglers survive invisibly (G1: `rank_comp`
surfaced only when `stdlib.h` landed). Re-grep all `qsort(` sites after the
headers go in. (Fix per "Latent bugs" below.)

`-Wno-incompatible-library-redeclaration` is worth keeping in the legacy flag
list through this step — it absorbs the harmless signature drift between a few
legacy decls and the real libc ones without masking anything you care about.

---

## Latent bugs this exposes (feature, not chore)

Giving everything real prototypes makes the compiler check calls it never
checked before. On G1 this surfaced genuine defects — expect the same on
g2/g3/tag, and **fix them as real bugs, don't paper over them**:

- **Arg-count mismatch.** `make_appropriate_subloc(row, col, 0)` called with 3
  args, defined with 2. K&R silently discarded the extra; the body never used
  it. (Dropped the dead arg.)
- **"Poor man's varargs."** `queue(int who, char *s, long a1..a9)` doing
  `sprintf(buf, s, a1..a9)`, called with however many args the format string
  consumes. Real fix: make it genuinely variadic (`...` + `vsprintf`).
- **Wrong return-type declaration.** A file locally declared
  `extern char *clear_wait_parse()` but the function returns `void`. The
  prototype header (extracted from the definition) is authoritative; delete
  the bogus local decl.
- **qsort comparator function-pointer mismatch.** K&R comparators
  (`int cmp(int *a, int *b)`) are compatible with `qsort`'s
  `int(*)(const void*,const void*)` *only because* they're unprototyped.
  Giving them real prototypes exposes `-Wincompatible-function-pointer-types`
  at every `qsort` call. Fix: convert each comparator to the canonical
  `(const void *, const void *)` signature, casting back to the real type via
  local variables so the body stays byte-identical. **Caveat:** this only fires
  once `qsort` itself has a prototype, i.e. after `<stdlib.h>` is included. If
  comparators were canonicalized in an earlier pass while `qsort` was still
  implicit, stragglers hide until the header lands (G1: `rank_comp` surfaced
  only then). Re-grep every `qsort(` site after adding the libc headers.
- **Orphan declarations.** Forward decls for functions that don't exist
  anywhere (G1: `fetch_inside_name`, `wrap_done`). Just delete them.
- **`int`/pointer return truncation** — the headline 64-bit hazard. Watch for
  functions implicitly assumed to return `int` whose value is used as a
  pointer.

---

## Flag ordering (CMakeLists)

The legacy `-Wno-*` suppressions and the new positive flags live in the same
`target_compile_options`. Clang applies left-to-right, last-wins. To turn a
class into an error you must *remove* its `-Wno-` line, not merely append the
positive flag after it. When you flip to `-Werror`, delete:
`-Wno-implicit-function-declaration` and `-Wno-deprecated-non-prototype`
(the latter because converting all K&R/empty-paren defs makes it 0, and
keeping it would re-mask any regression).

---

## Verification gate

After every meaningful change, and especially before/after the flag flip:

```bash
cmake --build --preset debug          # clean, no errors
./run/mapgen/mapgen.sh && ./run/olympia-g2.sh   # engine runs, writes run/olympia/lib
./tests/olympia/golden_check.sh                 # YES = match (exit 0)
```

G2's golden differs from G1's in **mechanism, not contract**. G2's run output is
~3500 files / ~140 MB — too large to commit as a literal tree — so
`tests/olympia/golden_check.sh` goldens a **sha256 manifest** (one
`<hash>  <relpath>` line per file) instead of the files themselves. Any byte
change in any file flips a manifest line and the gate prints `NO` with the
offending paths. `--update` regenerates the manifest from the current run; only
run it on a tree whose output change you intend. (G3/tag will each need their
own `golden_check.sh` — copy this one and adjust, per "Step 0" above.)

Note: `tests/mapgen/golden` is a **stale 32-bit baseline** and diverges from
64-bit output even on a clean tree — it is *not* the gate.

> **Known non-determinism in G2 (read before trusting the gate).** The engine
> has a pre-existing build-to-build non-determinism: `run/olympia/lib/fact/100`
> intermittently gains/loses a single `` st -32 `` line. It flickers across
> *clean rebuilds of byte-identical source* (a given binary is deterministic
> across reruns, but two clean builds of the same source can disagree on this
> one line). The original hypothesis was a missing-prototype / 64-bit bug. **That
> is now disproven: Phase 4 is complete (all three classes 0, `-Werror`
> enforced) and the flicker survived** — re-checked with 6 clean rebuilds, 5
> with no `` st -32 `` line and 1 with it. So it is *not* a prototype bug. New
> leading suspect: an uninitialized read / UB or address-dependent ordering;
> probe it with the `asan-ubsan` preset in Phase 5. `golden_check.sh` still holds
> `fact/100` out of the manifest and compares it line-by-line against a committed
> reference: a lone `` st -32 `` add/remove passes but is reported (`note: known
> 'st -32' flicker`); any other difference fails. **Keep the special case — do
> NOT fold `fact/100` back into the manifest.** Any diff beyond that one line, at
> any time, is a real regression.

---

## G2 results & engine-specific traps (done)

G2's Phase 4 is complete: 65 K&R defs (38 mapgen / 27 olympia), ~270 empty-paren
defs, 15 qsort comparators, `olympia/proto.h` (653 protos) + `mapgen/proto.h`
(75). All three classes 0, `-Werror` on both targets, golden unchanged. Three
traps that did **not** appear in G1 and are worth carrying to g3/tag:

- **Variadic conversion + arm64 ABI are coupled.** A "poor man's varargs"
  function (G2: `queue(int,char*,long a1..a9)` → `vsprintf`) must become
  `(...)` *and* gain a visible prototype at every call site in the **same
  step**. On Apple arm64, calling a variadic function with no prototype in scope
  uses the fixed-arity register convention while the variadic callee reads
  varargs off the stack → garbage → **segfault** (G2 crashed in
  `queue_npc_orders`). Converting the definition first, before the generated
  `proto.h` was wired in, broke the run. Do both in one move.
- **A second RNG translation unit.** G2 replaced G1's `drand48`/`z.c` RNG with
  an MD5-based `rnd.c` (one per target) that includes *neither* `z.h` nor
  `oly.h`. Treat it like `z.c`: make it `#include "z.h"` (safe — the
  `bzero`/`bcopy` macros are `#ifdef SYSV`, off on macOS, so the golden-critical
  hash is untouched) and declare its cross-file functions in `z.h`. Make the
  purely file-local helpers (`byteSwap`, mapgen's `MD5`) `static`.
- **File-private macros in a prototype's parameter type.** G2's `tunnel.c` has
  `print_map(int map[SZ+2][SZ+2][MAX_LEVELS], int l)` where `SZ`/`MAX_LEVELS`
  are `#define`d inside that `.c`. Such a function cannot go in `proto.h` (the
  macros aren't in scope there). If it's file-local, make it `static`; if it's
  also *unused* (so `static` would warn), keep it non-static with a **local**
  prototype placed after the macro defs. Generally: file-local non-static funcs
  → `static`; only the genuinely cross-file ones belong in `proto.h`.

## Reusable tooling

Working scripts from the G1 pass are preserved in `doc/phase4-tools/`:

- `kr2ansi.py` — K&R definition → ANSI (params only; return type untouched).
- `gen_proto3.py` — source-based prototype-header generator from a warning log.
- `fix_comp.py` — qsort comparators → canonical `(const void*, const void*)`.
- `fix_void_defs.py` — empty-paren definitions → `(void)`.

They have G1-specific paths and file lists baked in (e.g. `fix_comp.py`'s
comparator table) but are small and self-documenting; adapt them for
g2/g3/tag. The general method matters more than the exact scripts.
