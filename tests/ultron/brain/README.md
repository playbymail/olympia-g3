# Chaos Goblin — the first Ultron brain

`chaos_goblin.py` is step 3 of the Ultron first cut
([doc/ultron-harness-architecture.md §7](../../../doc/ultron-harness-architecture.md#7-first-cut-scope-proposed)).
It runs out of process: it reads the engine's state export, the fixture backlog,
and optionally the latest coverage dump, and writes plain player order files. It
never links against or calls the engine. Python 3, standard library only.

```bash
olympia-g3 -l lib test-use-const-report-date --state-export state.json
./chaos_goblin.py --state state.json --out lib/orders --seed 1 \
                  [--coverage coverage.tsv] [--orders-per-unit 8]
olympia-g3 -r -l lib -S test-use-const-report-date --coverage coverage.tsv
```

It writes `<out>/<faction>` for every faction in the export, replacing any file
already there, one `<unit>:<order>` per line. The orders then run through the
normal `-r -S` turn and `check_allow()`, like any player's. They never go through
immediate mode or `oly.order()`.

## How it picks

Every order is one weighted pick of a **cell**, a `(verb, outcome)` pair from
`backlog.tsv`. A cell weighs 1, plus 4 if its backlog cell is `todo`, plus 4 if
`--coverage` is given and counts it zero. Alias verbs weigh half, and the
`gm-immediate` and `directive` families are skipped. `quit` is left out unless
`--allow quit` is given, because it would end the faction for later turns.
`--exclude VERB` leaves out others.

The order is then shaped toward the picked outcome:

| Outcome | Shaping |
|---|---|
| `ok` | arguments from the state (units present, held items and quantities, known skills, exits), issued by the unit, or by the faction for a faction-only verb |
| `rejected` | issued by an entity the verb's `allow` string leaves out: the faction for a unit verb, the unit for a faction-only or GM verb. Verbs that allow both (`cpr`) have no `rejected` cell. |
| `fail` | the same arguments, garbled: junk added, one replaced, some dropped, or a random id |

The state informs the pick and does not gate it. Many `ok` picks still come back
`fail` or `rejected`, which counts as coverage too.

## Reproducibility

The same `--seed` and the same inputs give byte-identical order files. The
script uses its own `random.Random(seed)` and never iterates a set, so
`PYTHONHASHSEED` has no effect.

## Check

`./check.sh` exports the trade-routes scenario's state, runs the goblin twice
with one seed and once with another, and runs one turn on the result. It prints
`YES` when the same seed gives identical files, a different seed changes them,
the turn exits 0, and more than the four baseline verbs fire.

## First rounds (2026-10-24)

One round with seed 1 and 8 orders per unit on trade-routes fired 10 verbs
(baseline: 3). One turn per seed for seeds 1–40, 20 orders per unit, on
trade-routes and on guard-pillage:

| Scenario | Verbs fired | with `rejected` | with `ok` | with `fail` | Crashes |
|---|---|---|---|---|---|
| trade-routes | 110 | 86 | 53 | 73 | 0 |
| guard-pillage | 110 | 93 | 56 | 78 | 0 |

Seeds 1–20 of both were also run on the `asan-ubsan` preset, with no
diagnostics.
