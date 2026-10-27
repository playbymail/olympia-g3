# save-fly-cap — fly_cap saved under its own test

Pins the fix for #314. `print_item()` (`olympia/io.c`) wrote the `fc`
(fly_cap) line under `if (p->ride_cap)`:

```c
if (p->ride_cap)
	fprintf(fp, " fc %d\n", p->fly_cap);
```

An item with a fly_cap but no ride_cap lost it on the next save, and every
item with a ride_cap got an `fc 0` line. The test is now `if (p->fly_cap)`.

The second half changed golden output: the base world's 16 items with a
ride_cap and no fly_cap no longer save an `fc 0` line. Loading gives the
same result either way, since a missing `fc` reads as 0.

## Scenario

No `scenario.patch`. The fixture extracts the base world
`tests/olympia/fixtures/world.tgz` and adds an `fc 75` line to box 13 (archer,
no `rc` and no `fc`) in `lib/item`. The engine runs with `-l ./lib -S`: no
`-r`, so it loads the DB, runs `check_db()` and saves it.

## Checks

| box | before the save | after the save |
|---|---|---|
| 13 archer | `fc 75`, no `rc` | `fc 75` (before the fix: dropped) |
| 14 knight | `rc 100`, `fc 0` | no `fc` line (before the fix: `fc 0`) |
| 54 | `rc 150`, `fc 150` | `fc 150` |

The load must exit 0, and no `fc 0` line may be saved anywhere in `lib/item`.
