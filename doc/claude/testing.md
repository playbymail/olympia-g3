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
| `tests/olympia/regress/*/check.sh` | one fixture each: guard-pillage (combat/pillage), combat-stack-flee (#212 losing stack flees together), inventory-give, inventory-refused (inventory), move-go, move-land, move-ship (movement), player-* (player), production-harvest, production-refused (production), trade-routes (#46 buyer secret), save-seed-unwritable (#240 failed seed save is fatal, not a crash; no EXPECT files), rng-selftest (#241 `-R` tty grid in draw order), mint-top-id (#245 top id range stops at `MAX_BOXES - 1`), wait-not-weather (#247 `wait not rain`/`fog`/`wind` under a storm of strength 2 or more), trade-opium (#252 a sold-out opium market raises the city's addiction level), raze-rebuild (#246 a deleted box leaves the kind/subkind chain cache), token-swear (#251 an NPC token's units swear to the new holder when it is given), order-unrecognized (#248 an order that fails to parse is reported and the unit's next order runs), sail-stale-storm (#250 a ship arrives with a dead storm in its bound list), wait-gm-stack (#249 `wait top`/`stack` from the GM player), coast-rocks (#254 a ship next to a mountain coast strikes submerged rocks), move-out-first (#253 `move <destination>` from a sublocation moves out first, as `move <direction>` does); `--update` re-baselines |
| `tests/olympia/regress/{guard-pillage,move-ship}/check-lua.sh` | the same scenario authored in Lua (`olyscript-g3`) must match the same EXPECT files |
| `tests/mapgen/regress/{secret-sea-route,save-seed-unwritable}/check.sh` | the mapgen checks (`tests/mapgen/golden` is a stale 32-bit baseline, not a gate) |
| `tests/island/regress/ocean-glyphs/check.sh` | the island generator |
| `tests/rng/check.sh` | the `rng` layer self-check plus the "no gameplay `rnd()`" audit (see [rng-streams.md](rng-streams.md)) |
| `tests/ultron/check.sh` | `backlog.tsv`, `use-backlog.tsv` and `phase-backlog.tsv` stay consistent with the engine's tables and existing fixtures (see [ultron-fixtures.md](ultron-fixtures.md)) |

One-turn regress fixtures are stored as a `scenario.patch` over the shared base
world; see [tests/olympia/fixtures/README.md](../../tests/olympia/fixtures/README.md).
