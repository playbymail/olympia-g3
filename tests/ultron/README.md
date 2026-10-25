# Ultron fixture backlog

`backlog.tsv` lists every command the engine dispatches, together with the
fixture that exercises each outcome of it. It is the fixture to-do list ahead of
the Go port: the golden output is the only spec a port can be checked against,
and a verb or outcome without a fixture is behavior the port can get wrong
without anyone noticing. The baseline it starts from is in
[doc/ultron-harness-architecture.md §7.1](../../doc/ultron-harness-architecture.md#71-coverage-hook--landed):
only 4 of 147 verbs fire, and none is ever rejected or fails.

`./check.sh` keeps the list honest. It prints `YES` when every `cmd_tbl` verb in
`olympia/glob.c` has exactly one row, and every fixture a cell names exists.

## Format

Tab-separated, one row per `cmd_tbl` verb, grouped by family:

| Column | Meaning |
|---|---|
| `verb` | the `cmd_tbl` name, matching the `verb` column of `coverage.tsv` |
| `family` | the system the verb belongs to (see [Families](#families)) |
| `allow` | the `cmd_tbl` allow string: who may issue it |
| `alias_of` | the earlier verb that shares its `start` function, if any |
| `ok` | fixture where `start` returns TRUE |
| `rejected` | fixture where `check_allow()` refuses it |
| `fail` | fixture where `start` returns FALSE |

The three outcome columns match the `coverage.tsv` columns of the same name. Each
holds one of:

- `todo`: not exercised by any fixture yet.
- `golden`: exercised by the main golden turn (`tests/olympia/golden`).
- a fixture name: the directory under `tests/olympia/regress/` that exercises it.
- `n/a`: not part of the player order path, so no fixture is wanted. These are
  the `gm-immediate` verbs (immediate mode only, which skips `check_allow()`) and
  the order-file `directive` rows (`begin`, `unit`, … consumed by the order
  loader, with no `start` function).

`coverage.tsv`'s `unimplemented` column has no backlog column: every verb with
an `n/a` row is either never dispatched in a turn or has no `start`, and every
other verb has one.

## Working through it

The Chaos Goblin brain in [`brain/`](brain/README.md) generates order files
weighted toward the `todo` cells below. `loop.py` runs it for N turns on a
scenario and lists the `todo` cells the run hit, which shows what a scenario can
reach before a fixture is built for it. It also freezes any crash it finds as a
candidate fixture ([harness doc §7.4](../../doc/ultron-harness-architecture.md#74-loop-driver--landed)).
`./check-loop.sh` checks the loop itself.

1. **Pick a `todo` cell.** Prefer rows with an empty `alias_of`: an alias runs
   the same `start` as its target, so it adds little once the target is covered.
   Within that, prefer `ok` before `rejected`/`fail`, and families with the most
   `todo` cells.
2. **Build a fixture** under `tests/olympia/regress/<name>/`, following
   `guard-pillage` and `trade-routes`: a GM-built scenario (`build-scenario.sh` or
   an `olyscript-g3` `.lua`), the player order files, a `scenario.patch` over the
   shared base world (see [`tests/olympia/fixtures`](../olympia/fixtures/README.md);
   a multi-turn setup like `trade-routes` keeps a full `scenario.tgz`), and a
   `check.sh` that runs one `-r -S` turn and compares a hashed manifest with
   `EXPECT.sha256` and the `--state-export` snapshot with `EXPECT.json`. The
   hashes (reports included) are the strict gate; the JSON shows what changed
   when they fail. The orders under test go in plain order files and through the
   normal turn, never through immediate mode.
3. **Prove the cell.** Run the fixture's turn with `--coverage <path>` and confirm
   the target verb has a nonzero count in the target column. One fixture can
   clear several cells; record it in each. Have `check.sh` assert it too (run
   the turn with `--coverage` and fail when a target verb's count is zero, as
   the `move-*` fixtures do), so the cell stays true as the engine changes.
4. **Record it.** Replace `todo` with the fixture name, run `./check.sh`, and land
   the fixture and the backlog update in the same PR.

A cell whose outcome turns out to be unreachable (the way the #4 guard-dedup
branch was) becomes `n/a`, with the reason in the fixture's or the PR's notes.

## Families

The grouping is a first proposal for the vision doc's verb→system map
(open question 2 in the harness doc), and can be refined:

| Family | Verbs |
|---|---|
| movement | go, move, the compass verbs, enter/exit/in/out, fly, sail, board, unload, ferry |
| combat | attack, behind, guard, pillage, surrender, execute, raze |
| attitude | admit, contact, defend, default, hostile, neutral |
| loyalty | swear, oath, pledge, honor/honour |
| social | bribe, incite, terrorize |
| stacking | stack, unstack, promote |
| inventory | give, get/take, discard/drop, claim, reclaim, pay, accept |
| trade | buy, sell, fee |
| governance | decree, garrison, ungarrison |
| construction | build, improve, repair |
| production | make, quarry/stone, wood, yew, fish, catch, mallorn, opium, collect |
| recruitment | recruit, train, form, raise, rally |
| skills | study, research, forget, use |
| magic | trance, bind, breed |
| stealth | hide, sneak, torture |
| exploration | explore, quest, seek, plugh, xyzzy |
| player | faction and report settings, plus stop, wait, die, quit |
| gm | credit, emote, relore (the GM player during a turn) |
| gm-immediate | immediate-mode GM tools (`n/a`) |
| directive | order-file directives (`n/a`) |

`use` is a single verb but dispatches every usable skill and item, so its
cells say little about them. Those have their own tracker, below.

## The use backlog

`use-backlog.tsv` (#181, parent #180) has one row per `use_tbl` skill in
`olympia/use.c` and one per item use key dispatched by `v_use_item()`. Its cells
match the outcome columns of the `--use-coverage` dump
([harness doc §7.5](../../doc/ultron-harness-architecture.md#75-use-coverage--landed)),
and `./check.sh` keeps it honest the same way: every skill and use key has
exactly one row, keyed and named by its `sk_`/`use_` define, and every fixture a
cell names exists.

| Column | Meaning |
|---|---|
| `kind` | `skill` or `item` |
| `key` | the skill id, or the item use key (the `use_*` defines in `olympia/oly.h`) |
| `name` | the `sk_`/`use_` define without its prefix |
| `school` | the skill's school, from the `rs` chain in the world's `lib/skill` (`-` for an item) |
| `start` | the start function `use` dispatches to; `(produce)` for a `use_tbl` row with no start, which `v_use` hands to `skill_produce` |
| `ok` | fixture where the use returns TRUE |
| `fail` | fixture where it returns FALSE |

Cells hold `todo`, `golden`, a fixture name or `n/a`, as in `backlog.tsv`. There
is no `rejected` column: every `use_tbl` allow string is `"c"`, the same as `use`
itself, so `check_allow()` refuses a `use` before it reaches a skill. The dump's
`checks` column (shared checks that fail before dispatch) has no backlog column
either: one fixture pins those for all skills.

`n/a` so far:

- `ok` of the 10 `v_implicit` skills, which always fail ("No direct USE
  function exists").
- `ok` of `shipbuilding` (602): `v_shipbuild` always fails ("Use the BUILD
  order to build ships.").
- `fail` of the 16 skills whose start always returns TRUE: `fight_to_death`,
  `defense`, `archery`, `swordplay`, `breed_hound`, the three brews
  (`v_brew`), `vision_protect`, `meditate`, `tap_health`, `shroud_abil`,
  `adv_med`, `banish_corpses`, `absorb_blast` and `teleport_item`. A missing requirement (a brew's ingredient) fails in
  `meets_requirements`, under `checks`.
- `fail` of `trance` (921). `v_trance` refuses a noble that doesn't know
  Trance, but `v_use` lets one through only when it holds an item whose
  `may_use` lists Trance, and no engine code makes such an item
  (`d_write_spell` and the quest scrolls set `may_study`).
- `fail` of the 4 `(produce)` skills (`make_catapult`, `make_siege`,
  `extract_venom`, `make_ram`). With no start function, `v_use` counts every
  use that passes its shared checks as `ok`; a missing requirement fails in
  `meets_requirements`, which the dump counts under `checks`.
- both cells of `add_ram` (997), `save_quick` (998) and `quick_cast` (999).
  These skills are in `use_tbl` but not in the world's `lib/skill`, so `use`
  rejects them as not a valid skill and counts them under `invalid`.

To prove a cell, run the turn with `--use-coverage <path>` and have the fixture's
`check.sh` assert it with `use_cells` from `tests/olympia/fixtures/coverage.sh`,
as social-bribe and trade-routes do.
