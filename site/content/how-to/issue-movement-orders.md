---
title: Issue movement orders
weight: 1
---

This guide shows how to move a noble around the map: between provinces, in and out
of structures, and across water. It assumes you can already write and submit an
orders file (see [Your first turn as a player](../../tutorials/player-first-turn/)).

All orders below go inside a `unit` block for the noble that is moving.

## Move one province in a compass direction

Use a compass direction to step into the neighbouring province. You can write the
direction in full or abbreviated:

```text
unit 1234
    north
```

`north`/`n`, `south`/`s`, `east`/`e`, and `west`/`w` all work. Each step moves the
noble one province and consumes travel time within the turn.

## Move toward a named destination

`move` (and its synonym `go`) accepts either a direction or a destination, so you
can aim at a specific adjacent location by its code:

```text
unit 1234
    move bz12
```

If you give a direction the noble does not border, the move fails for that turn —
check the exits listed for your province in the turn report.

## Chain several moves in one turn

Write moves on consecutive lines. The noble performs them in order, as far as the
turn's time allows:

```text
unit 1234
    north
    north
    east
```

If the noble runs out of time mid-journey, the remaining moves carry over and
continue automatically next turn.

## Enter and leave a structure

Provinces contain sublocations — cities, ships, buildings. Use `enter` (synonym
`in`) with the sublocation's code to go inside, and `exit` (synonym `out`) to
return to the surrounding province:

```text
unit 1234
    enter 5601
    exit
```

## Travel across water

Moving over ocean needs a vessel. Board a ship in your location, then sail it
toward a destination:

```text
unit 1234
    board 7012
    sail bz30
```

Sailing is a stack-level action — the ship and everyone aboard travel together,
and the voyage may span more than one turn for long crossings.

## Verify the move worked

In next turn's report, confirm:

- the noble's **new location** matches where you sent it, and
- the orders appear in the **confirmation** echo (a missing order was rejected —
  check spelling against the [order catalog](../../reference/order-catalog/)).

## Related

- Why a move spans part of a month:
  [The turn-resolution model](../../explanation/turn-resolution-model/).
- Full list of movement orders and synonyms:
  the [order catalog](../../reference/order-catalog/#movement).
