# load-trade-no-price — a loaded trade with no price is dropped

Pins the fix for #358. `trade_list_scan()` in `olympia/io.c` checked only a
`tl` entry's item, so it kept a positive quantity with a price below 1, such
as `1 79 1 0 0 0 0 0` (BUY 1 iron at 0). `v_buy` and `v_sell` refuse that
order (`No price given.`), so only a saved game can hold one. The traders
divide by the price: `market_report()` → `list_market_items()` →
`reduce_qty()` in `olympia/buy.c` computes `has / 0`. That is SIGFPE on amd64
(exit 136). arm64 returns 0 without trapping, but UBSan reports it (exit 134
under `asan-ubsan`). A zero-price SELL, or a city PRODUCE or CONSUME, which
the city turns into a SELL or BUY at the same price, can reach the same
divisions in `attempt_trade()` and `investigate_possible_trade()`.

Now the loader drops any entry with a positive quantity and a price below 1,
as it drops one with a bad item, and reports it on stderr:
`trade_list_scan(4126): item 79 qty 1 has no price`. An entry with quantity 0
(a cleared order) is kept as before, and `save_box()` still leaves it out.

## Scenario

No `scenario.patch` of its own. Each case unpacks the `trade-market`
scenario (Greyfell, 57081), removes its orders, and adds one `tl` line to
Buyer One [4126] (`fact/300`) or Seller One [8651] (`fact/301`). One turn
runs.

| case | unit | `tl` entry | dropped | saved `tl` |
|---|---|---|---|---|
| buy-no-price | 4126 | `1 79 1 0 0 0 0 0` | yes | none |
| sell-no-price | 8651 | `2 94 5 0 0 0 0 0` | yes | none |
| buy-priced | 4126 | `1 79 1 1 0 0 0 0` | no | `1 79 1 1 0 0 0 0` |
| buy-cleared | 4126 | `1 79 0 0 0 0 0 0` | no | none |

## Checks

For each case: exit status 0; no AddressSanitizer or UBSan report on stderr;
the `has no price` report appears once for a dropped entry and never for the
controls; and the unit's saved box holds the `tl` line in the table. Before
the fix, `buy-no-price` exits 134 under `asan-ubsan` (and 136 on amd64), and
on any build the dropped cases fail the report check. Before the fix,
`sell-no-price` sells the 5 baskets to the city for nothing.
