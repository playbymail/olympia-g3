# load-stray-orders — a stray file in lib/orders

Pins the fix for #332. `load_orders()` in `olympia/order.c` loads
`lib/orders/<name>` for every name that starts with a digit, as the orders of
player `atoi(name)`. `load_player_orders()` asserted that the player had a
player section and no orders yet:

- A file named after a box that isn't a player, such as `orders/10101` (a
  province), made `rp_player()` NULL. The assert dereferenced it: SIGSEGV,
  exit 139.
- Two names that `atoi()` reads as the same player, such as `orders/206` and
  the backup `orders/206.bak`, failed `orders == NULL` on the second: exit
  134. Both names load the same file, `orders/206`.

Now `load_orders()` skips each one, with a report on stderr:

```
ERROR: orders/10101 but [10101] is not a player
ERROR: orders/206.bak but orders for [206] are already loaded
```

The second report names whichever file the directory listed second, so the
check counts reports without naming the file.

## Scenario

No `scenario.patch`. Each case extracts the base world
`tests/olympia/fixtures/world.tgz`, whose `lib/orders` is empty, and writes
`1009:wait 1` to each listed file:

| case | files |
|---|---|
| not-player | `10101` |
| backup | `206`, `206.bak` |
| both | `10101`, `206`, `206.bak` |

The engine runs with `-l ./lib -S`: it loads the DB and orders and saves,
with no turn.

## Checks

For each case: exit status 0; no AddressSanitizer or UBSan report on stderr;
the wanted number of each report; and the saved `lib/orders` holds only
`206`, with the one order, when 206's orders were written. Before the fix
`not-player` exits 139 and the others exit 134.
