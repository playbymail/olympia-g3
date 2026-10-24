# Shared fixtures

| File | What it is |
|---|---|
| `lib.tgz` | The bare map: a `lib` from before world init. `./run/olympia-g3.sh`, `check-lua.sh` and every `build-scenario.sh` start here. |
| `world.tgz` | The shared base world: `lib.tgz` after world init only (`-s`, then `-a` with no players). Built by `build-world.sh`. |
| `scenario.sh` | Helpers sourced by the regress fixtures: `scenario_unpack` and `scenario_write`. |

## Fixtures as a patch over one base world (#121)

Nearly all of a one-turn fixture's pre-turn `lib` is the same post-init world.
Between two fixtures, the 3.3 MB `loc` file differs by a few lines (the occupant
list of the start province). So each one-turn fixture under
`tests/olympia/regress/` commits a plain-text **`scenario.patch`** against
`world.tgz`, a few KB, instead of a ~700 KB `scenario.tgz` of its own:

- `build-scenario.sh` builds the game from `lib.tgz` as before, then calls
  `scenario_write`. That writes the diff from `world.tgz` to the built `lib`,
  unpacks it again, and fails unless the result matches the built `lib` byte
  for byte.
- `check.sh` calls `scenario_unpack`, which extracts `world.tgz` and applies the
  patch, then runs the turn as before.

The checked input is still a frozen saved game: a fixture doesn't change when
world-generation code changes until someone regenerates it. A PR that adds or
changes a fixture shows its nobles, items and orders as a readable diff.

The patch's first line, `world-sha256: <hash>`, records which base it was taken
against (a hash over every file in `world.tgz`'s `lib`). `scenario_unpack`
checks it before applying anything, so a fixture can't silently pick up a
changed base, even where the base changed outside the patch's hunks.

**`trade-routes` keeps a full `scenario.tgz`.** Its setup turn rewrites most
of the world, so a patch would save little.

## Re-baselining the base world

After a world-init change (like the #25 worldgen/mint re-baselines):

```bash
tests/olympia/fixtures/build-world.sh                     # rewrite world.tgz
for d in tests/olympia/regress/*/; do
	[ -f "$d/scenario.patch" ] && "$d/build-scenario.sh"   # rewrite each patch
done
```

Until a fixture is rebuilt, its `check.sh` fails with "was taken against a
different world.tgz". Then re-run each `check.sh`, and use `--update` only for
a deliberate output change. This is the same work as regenerating every
`scenario.tgz` was before.
