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
baseline** — *not* the gate; the mapgen checks are
`tests/mapgen/regress/*/check.sh`.

## Subsystem gates

Each prints `YES` on success. Run the ones whose area your change touches (all of
them for engine changes), on `debug` and with `OLYMPIA_PRESET=asan-ubsan`:

| Gate | Pins |
|---|---|
| `tests/olympia/regress/*/check.sh` | one fixture each: guard-pillage (combat/pillage), combat-stack-flee (#212 losing stack flees together), inventory-give, inventory-refused (inventory), move-go, move-land, move-ship (movement), player-* (player), production-harvest, production-refused (production), trade-routes (#46 buyer secret), save-seed-unwritable (#240 failed seed save is fatal, not a crash; no EXPECT files), rng-selftest (#241 `-R` tty grid in draw order), mint-top-id (#245 top id range stops at `MAX_BOXES - 1`), wait-not-weather (#247 `wait not rain`/`fog`/`wind` under a storm of strength 2 or more), trade-opium (#252 a sold-out opium market raises the city's addiction level), raze-rebuild (#246 a deleted box leaves the kind/subkind chain cache), token-swear (#251 an NPC token's units swear to the new holder when it is given), order-unrecognized (#248 an order that fails to parse is reported and the unit's next order runs), sail-stale-storm (#250 a ship arrives with a dead storm in its bound list), wait-gm-stack (#249 `wait top`/`stack` from the GM player), coast-rocks (#254 a ship next to a mountain coast strikes submerged rocks), move-out-first (#253 `move <destination>` from a sublocation moves out first, as `move <direction>` does), fly-out-first (#265 `fly <destination>` from a sublocation flies out first, as `fly <direction>` does), sail-out-first (#266 `sail <destination>` from a ship docked at an island sails out first, as `sail <direction>` does); `--update` re-baselines |
| `tests/olympia/regress/run-all.sh [name...]` | runs every fixture's `check.sh` (not `check-lua.sh`) and reports PASS/FAIL/ERROR per fixture; see [another engine](#running-the-spec-against-another-engine) |
| `tests/olympia/regress/{guard-pillage,move-ship}/check-lua.sh` | the same scenario authored in Lua (`olyscript-g3`) must match the same EXPECT files |
| `tests/mapgen/regress/*/check.sh` | the mapgen checks: secret-sea-route (adjacent ocean found in the last direction slot), save-seed-unwritable (#240), map-glyphs (#274 `#` holes in row 0 and beside another hole, #272 random gates go to the second province drawn, plus #276 coverage: Uldim/Summerbridge boundaries, sea lanes, `*` cities, a `Land` mismatch and a `Regions` collision; pins stderr too), unnamed-regions (#273 regions with no `Regions` entry), seed-no-province (#278 `Regions`/`Land` entries on a hole or off the map are reported and skipped), last-column (#275 random provinces and safe-haven marking reach the last map column), lone-boundary (#281 a boundary square reached by a second region's flood is a wall, not an assert), hole-edges (#285 holes in the last row and column are bridged), corner-hole (#287 a hole at (`max_row`, `max_col`); also pins the saved `randseed`). `tests/mapgen/golden` is a stale 32-bit baseline, not a gate. `MAPGEN_BIN` runs them against another map generator, as `OLYMPIA_ENGINE_BIN` does for the engine; see [tests/mapgen/mapgen.sh](../../tests/mapgen/mapgen.sh) |
| `tests/genesis/regress/*/check.sh` | the genesis-g3 world generator (#290), one argument vector per case: defaults, seed-parsing (`strtoull` base 0), sizes (incl. the ocean cap), coloring-retry (4-coloring retries), island-iterations, region-pool-wrap (`Ironvale 2`), defer-oceans (frontier, lakes, `Great Lake`, tiny water filled), ocean-growth-bfs, start-cities (0/1/16 and a spacing retry), image (`--image` BMPs, row padding), validation-errors (each range check), write-failures (an output path that is a directory). Each pins the exit status and stderr (`EXPECT.log`) and every file written (`EXPECT.sha256`); see [tests/genesis/README.md](../../tests/genesis/README.md). `GENESIS_BIN` runs them against another generator |
| `tests/island/regress/*/check.sh` | the island-g3 generator (#292): defaults, ocean-glyph-output (exact output per ocean glyph), ocean-glyphs (#24 invariants), size, border-shelf, existing-land, chain (`island < map \| island \| ...` sharing one `randseed`), no-room, map-shape, usage-errors (#300 the usage line names `island-g3`, not `argv[0]`), write-failure, missing-randseed (#298 the message goes to stderr, not into the map), empty-input (#295 an empty map is an error, not a hang), map-bounds (#299 a map bigger than 120 rows or 119 columns is an error, not an overflow). Each pins the exit status and stderr (`EXPECT.log`) and each stage's stdout and the final `randseed` (`EXPECT.sha256`); see [tests/island/README.md](../../tests/island/README.md). `ISLAND_BIN` runs them against another generator |
| `tests/rng/check.sh` | the `rng` layer self-check plus the "no gameplay `rnd()`" audit (see [rng-streams.md](rng-streams.md)) |
| `tests/ultron/check.sh` | `backlog.tsv`, `use-backlog.tsv` and `phase-backlog.tsv` stay consistent with the engine's tables and existing fixtures (see [ultron-fixtures.md](ultron-fixtures.md)) |

One-turn regress fixtures are stored as a `scenario.patch` over the shared base
world; see [tests/olympia/fixtures/README.md](../../tests/olympia/fixtures/README.md).

## Running the spec against another engine

A port (`mdhender/rhorri`, `mdhender/g3g0`) runs the same gates, from a pinned
checkout of this repo, against its own engine executable (#269). Set
`OLYMPIA_ENGINE_BIN` to it. A relative path is taken from the current
directory. It is resolved by
[tests/olympia/engine.sh](../../tests/olympia/engine.sh), which every
`tests/olympia/regress/*/check.sh` and `run/olympia-g3.sh` source:

```bash
export OLYMPIA_ENGINE_BIN=/abs/path/to/port/engine
export OLYMPIA_RUN_DIR="$(mktemp -d)"         # golden turn output, outside the checkout

./tests/olympia/regress/run-all.sh            # PASS/FAIL/ERROR per fixture + summary
./run/olympia-g3.sh                           # full turn in $OLYMPIA_RUN_DIR
./tests/olympia/golden_check.sh               # YES: $OLYMPIA_RUN_DIR/lib matches the manifest
```

- **Unset**, everything runs `build/${OLYMPIA_PRESET:-debug}/olympia-g3` as
  before. **Set** to a path that is missing, a directory or not executable,
  every gate exits 2 with `error: OLYMPIA_ENGINE_BIN=... is not an executable
  file`; it never falls back to the C engine.
- The engine gets the same arguments, frozen inputs and checks either way:
  coverage cells, `EXPECT.sha256`, `EXPECT.json`, exit statuses, stderr. The
  replay needs only the engine. `check-lua.sh` (scenario authoring through
  `olyscript-g3`) stays C-only, and `run-all.sh` does not run it.
- **Expected output is written only by the C engine.** `check.sh --update`
  and `golden_check.sh --update` exit 2 while `OLYMPIA_ENGINE_BIN` is set.
  `run/olympia-g3.sh` records the engine in `<run dir>/.olympia.engine`, and
  `golden_check.sh --update` also refuses a run that was not the default
  engine. `run-all.sh` never re-baselines.
- **Scratch:** each `check.sh` already works in its own `mktemp -d` (under
  `$TMPDIR`). `OLYMPIA_RUN_DIR` moves the golden turn out of `run/olympia`.
  It is created if missing, its `lib/`, `lib-before/` and `lib-after/` are
  replaced, and a directory under `tests/` is refused. `golden_check.sh` reads
  the same variable.
- `run-all.sh [name...]` prints `PASS`/`FAIL`/`ERROR` per fixture, then the
  failing check's own output, indented, and a `pass N fail N error N` line.
  It exits 0 only when every fixture passed. `FAIL` means the output differs
  (exit 1). `ERROR` means the check could not run (exit 2).
- Passing the C engine explicitly
  (`OLYMPIA_ENGINE_BIN=build/debug/olympia-g3`) gives the same `run-all.sh`
  report and golden `YES` as the default.

The mapgen checks take `MAPGEN_BIN` instead (#276): the same rules, set
in [tests/mapgen/mapgen.sh](../../tests/mapgen/mapgen.sh), with `--update`
refused while it is set. The genesis checks take `GENESIS_BIN` (#290), set
in [tests/genesis/genesis.sh](../../tests/genesis/genesis.sh), and the island checks
take `ISLAND_BIN` (#292), set in [tests/island/island.sh](../../tests/island/island.sh),
by the same rules. The rng and Ultron gates still run the C
build only. The C
sanitizer gate and the source audits check the C implementation, not a port.
The `check.sh` scripts call `shasum -a 256`, which a Linux container may not
have.
