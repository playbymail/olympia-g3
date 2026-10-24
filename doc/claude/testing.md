# Test gates

> Split out of [CLAUDE.md](../../CLAUDE.md). Read this when you need more than the two standing gates in CLAUDE.md: what the golden manifest covers, re-baselining, or the subsystem gates.

## The olympia golden gate

`tests/olympia/golden_check.sh` (adapted from G2)
gates the post-turn DB in `run/olympia/lib` as a sorted sha256 **manifest**
(`tests/olympia/golden/manifest.sha256`). Run `./run/olympia-g3.sh` (a full
`-r -S` turn) first, then `golden_check.sh` (prints `YES`); re-baseline with
`--update`. It is date-independent (the `test-use-const-report-date` flag — see
[BUILD_HISTORY.md](../../BUILD_HISTORY.md)). G3 output is **deterministic across clean rebuilds**, so the
gate has **no flaky-file holdout**. `tests/mapgen/golden` is a **stale 32-bit
baseline** — *not* the gate; the mapgen check is
`tests/mapgen/regress/secret-sea-route/check.sh`.

## Subsystem gates

Each prints `YES` on success. Run the ones whose area your change touches (all of
them for engine changes), on `debug` and with `OLYMPIA_PRESET=asan-ubsan`:

| Gate | Pins |
|---|---|
| `tests/olympia/regress/*/check.sh` | one fixture each: guard-pillage (combat/pillage), move-go, move-land, move-ship (movement), trade-routes (#46 buyer secret); `--update` re-baselines |
| `tests/olympia/regress/{guard-pillage,move-ship}/check-lua.sh` | the same scenario authored in Lua (`olyscript-g3`) must match the same EXPECT files |
| `tests/mapgen/regress/secret-sea-route/check.sh` | the mapgen check (`tests/mapgen/golden` is a stale 32-bit baseline, not a gate) |
| `tests/island/regress/ocean-glyphs/check.sh` | the island generator |
| `tests/rng/check.sh` | the `rng` layer self-check plus the "no gameplay `rnd()`" audit (see [rng-streams.md](rng-streams.md)) |
| `tests/ultron/check.sh` | `backlog.tsv` stays consistent with `cmd_tbl` and existing fixtures (see [ultron-fixtures.md](ultron-fixtures.md)) |

One-turn regress fixtures are stored as a `scenario.patch` over the shared base
world; see [tests/olympia/fixtures/README.md](../../tests/olympia/fixtures/README.md).
