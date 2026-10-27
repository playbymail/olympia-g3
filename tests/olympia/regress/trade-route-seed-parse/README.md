# trade-route-seed-parse — reading the trade-route seed

Pins the fix for #338. `init_trade_routes()` in `olympia/buy.c` reads the
per-game trade-route seed (#46) from `lib/trade_routes`, or for a new game
from `lib/trade-route-seed`. It used `fscanf(fp, "%llu", &seed)`. How much of
a long token that reads is up to the C library: for 512 or more zeros
followed by `13`, macOS read `1` or `0` where glibc read `13`. The parsed
seed sets the buyer secret and is saved back, so the two platforms built
different games from the same file.

Now `read_trade_route_seed()` reads the token itself, the same way on every
platform. These are the rules of `strtoull(s, NULL, 10)`:

- skip leading space, `\t`, `\n`, `\v`, `\f` and `\r`;
- take an optional `+` or `-`;
- read decimal digits up to the first non-digit;
- no digits: no seed, as when `fscanf` matched nothing;
- a value past 2^64 − 1 is 2^64 − 1 (18446744073709551615), with or without
  a `-`;
- otherwise `-n` is 2^64 − n.

## Scenario

No `scenario.patch`. Each case extracts the base world
`tests/olympia/fixtures/world.tgz`, which has neither file, writes one seed
file, and runs `-l ./lib -S`: load and save, no turn. `save_trade_routes()`
writes the seed in effect back to `lib/trade_routes` as a decimal number.

| case | file | contents | saved seed |
|---|---|---|---|
| plain | `trade_routes` | `13` | 13 |
| zeros-511 | `trade_routes` | 511 zeros, `13` | 13 |
| zeros-512 | `trade_routes` | 512 zeros, `13` | 13 |
| zeros-600 | `trade_routes` | 600 zeros, `13` | 13 |
| plus-zeros | `trade_routes` | `+`, 511 zeros, `13` | 13 |
| whitespace | `trade_routes` | ` \n\t 42 trailing` | 42 |
| max | `trade_routes` | `18446744073709551615` | 18446744073709551615 |
| overflow | `trade_routes` | `18446744073709551616` | 18446744073709551615 |
| overflow-long | `trade_routes` | 600 nines | 18446744073709551615 |
| negative | `trade_routes` | `-1` | 18446744073709551615 |
| negative-overflow | `trade_routes` | `-18446744073709551616` | 18446744073709551615 |
| hex | `trade_routes` | `0x1f` | 0 |
| no-digits | `trade_routes` | `seed` | none: file left as it was |
| input-zeros | `trade-route-seed` | 600 zeros, `13` | 13 |

## Checks

For each case: exit status 0, no AddressSanitizer or UBSan report, and the
saved seed. Before the fix, on macOS, `zeros-511` saved `1`, and
`zeros-512`, `zeros-600`, `plus-zeros` and `input-zeros` saved `0`. glibc
already gave every result in the table.
