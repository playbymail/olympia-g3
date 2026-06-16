# trade-routes — per-game buyer secret regression (issue #46)

This fixture pins the behaviour of the **trade-route buyer secret** that
issue #46 added to `d_find_buy()` (`olympia/buy.c`). It is the second behavioural
regress alongside `guard-pillage`, and like it, runs a single frozen scenario
through the engine and hashes the result.

## What `d_find_buy` does

When a noble issues `FIND BUY <tradegood>` (the `use 733 …` skill) in a city, the
engine decides whether *that* city is a buyer for the good with a 50% test:

```c
if (md5_int(city_sold, where, item, SECRET) & 1)   /* odd -> no buyer */
```

The set of buyer cities must be **stable for the life of a game** (a buyer this
turn is a buyer next turn), so the draw is deliberately **turn-INDEPENDENT** — it
is *not* on the per-turn `economy_rng` stream. Before #46 the `SECRET` was a
hardcoded `0xb05c0e`, which gave the buyer map zero per-game entropy (two games on
the same map shared an identical route table) and was source-derivable. #46
replaced it with a per-game secret derived from an optional GM seed
(`splitmix64`, folded 64→32): with no seed the secret stays `0xb05c0e` *unmixed*
(default, byte-identical); with `-G <seed>` (or the `lib/trade-route-seed` input
file) it is per-game and the original seed is persisted to `lib/trade_routes`.

## The scenario

`build-scenario.sh` (one-time authoring tool — **not** run by `check.sh`) drives
the engine's own bootstrap from the bare-map fixture:

- mints one faction (400 "Trade Test", noble "Trader One") via the add-player path;
- teaches it Trade(730) + Find-tradegood-for-sale(732) + Find-market(733);
- **setup turn**: the noble runs `use 732` (FIND SELL) in the source city
  **Areth Pirn (57019)**, minting one tradegood (**myrrh**) and a PRODUCE record
  there (the bare map's only `sub_tradegood`, so its id is parsed back out of
  `lib/item`);
- poofs the noble into the buyer city **Greyfell (57081)** — ≥ 8 provinces from
  the source, the distance `d_find_buy` requires — and hands it 5 myrrh;
- queues the **measured** order `use 733 <myrrh>` (FIND BUY) and freezes the
  pre-turn library as `scenario.tgz`.

## What `check.sh` asserts

It runs the measured turn three times on fresh extractions and hashes the noble's
report (`lib/save/<turn>/400`, the FIND BUY verdict + resulting routes):

| run | secret | verdict | pinned in |
|-----|--------|---------|-----------|
| 1 | default `0xb05c0e` | Greyfell **buys** myrrh at 139 | `EXPECT.sha256` |
| 2 | `-G 1` | **No buyer** for myrrh | `EXPECT-seeded.sha256` |
| 3 | `-G 1` | byte-identical to run 2 | (determinism) |

and additionally requires:

- the two pinned hashes **differ** — proof the secret actually feeds the buyer
  test (not a dead arg);
- `-G 1` persists `lib/trade_routes` = `1`, while the default flow writes **no**
  such file (the #46 persistence side effect).

A regression in the secret derivation, the `splitmix64` fold, the persistence, or
the `md5_int` keying flips one of these and fails the gate — in this subsystem's
own small golden tree, **not** the main manifest.

## Running

```bash
cmake --build --preset debug
./check.sh                 # prints YES
OLYMPIA_PRESET=asan-ubsan ./check.sh   # same, clean under ASan/UBSan
```

Re-baseline (only after a deliberate behaviour change):

```bash
./build-scenario.sh        # regenerate scenario.tgz
./check.sh --update        # rewrite both EXPECT files
```

The flow is date-independent via the `test-use-const-report-date` flag.

## Notes

- The seed `1` is simply the smallest GM seed whose derived secret flips this
  particular `(57019, 57081, myrrh)` verdict from buyer→no-buyer; md5 avalanche
  flips roughly half of all verdicts for any given seed.
- `check.sh` re-extracts a fresh `lib` for every run, so the test is independent
  of run order and leaves no state behind. It exercises the FIND BUY command path
  that neither the main manifest nor `guard-pillage` reaches.
