# The Ultron fixture backlog

> Split out of [CLAUDE.md](../../CLAUDE.md). Read this when you add or change a regress fixture, work a `tests/ultron/backlog.tsv` cell, or touch the Ultron harness (`--coverage`, `--state-export`, the Chaos Goblin, `loop.py`).

## The backlog (ahead of the Go port)

The work left before the Go port is **fixture coverage**. The golden output is the
only spec a port can be checked against, so a verb or outcome without a fixture is
behavior the port can get wrong without anyone noticing. The to-do list is
[`tests/ultron/backlog.tsv`](../../tests/ultron/README.md): one row per `cmd_tbl` verb,
with the fixture that exercises each outcome (`ok` / `rejected` / `fail`) or
`todo`. The work is split into one child issue per verb family under the parent
**#116**. The movement family (#117) is covered by `move-go`, `move-land` and
`move-ship`, and the player family (#118) by `player-settings`, `player-press`,
`player-die` and `player-quit`. Those are also the first fixtures to cover
`rejected`/`fail` cells. The production family (#126) is covered by
`production-harvest` (`ok`) and `production-refused` (`fail`/`rejected`), and
the inventory family (#127) by `inventory-give` and `inventory-refused`,
the combat family (#128) by `combat-attack`, `combat-refused` and
`guard-pillage`, the attitude family (#129) by `attitude-set` and
`attitude-refused`, the recruitment family (#130) by
`recruitment-raise` and `recruitment-refused`, the stacking family
(#141) by `stacking-stack` and `stacking-refused`, the trade family
(#142) by `trade-market` and `trade-refused`, the loyalty family
(#143) by `loyalty-bind` and `loyalty-refused`, the skills family
(#144) by `skills-learn` and `skills-refused`, and the stealth family
(#145) by `stealth-hide` and `stealth-refused`.

The harness to work through it is in place
([doc/ultron-harness-architecture.md §7](../ultron-harness-architecture.md#7-first-cut-scope-proposed)):
the `do_command` coverage hook and `--coverage` dump (#98, #100), the
`--state-export` JSON snapshot (#104), the Chaos Goblin brain (#105, #110), and the
`tests/ultron/loop.py` driver that freezes crashes as fixtures (#106). New fixtures
go under `tests/olympia/regress/<name>/`, following guard-pillage and the move-*
fixtures. A one-turn fixture commits a plain-text `scenario.patch` over the shared
base world `tests/olympia/fixtures/world.tgz` (#121; see
[tests/olympia/fixtures/README.md](../../tests/olympia/fixtures/README.md)), not a full
`scenario.tgz`. Land each fixture with its backlog update, and keep
`tests/ultron/check.sh` printing `YES`.

**Author new fixtures in Lua** (`olyscript-g3`, `olympia/lua_bindings.c`) when
the bindings cover them. A fixture authored in Lua from the start has a
`<name>.lua` that its `build-scenario.sh` runs and freezes as `scenario.patch`
(the `player-*` fixtures; the script also takes `world.tgz`'s `lib/log`, which
a turn discards). guard-pillage and move-ship were built in bash first and keep
a Lua copy checked by `check-lua.sh`. If a binding is missing, add it in that
fixture's PR. A verb that a third fixture's bash build drives through `-i` is
the signal to add one. Bindings are C engine code under the full `-Werror`
build, and the Go port may have to reproduce them, so none are added
speculatively (#120). `oly.restart()` exists only so a Lua script can
reproduce an older multi-process bash build byte for byte; a fixture authored
in Lua from the start does not call it.

Two known gaps beyond the per-verb table:
`use` dispatches every usable skill and item, so its single `ok` cell says little,
and the hook does not see the non-command turn phases (NPC/savage movement,
weather, upkeep, region spawns, month-end) listed in
[doc/turn-execution-order.md](../turn-execution-order.md).
