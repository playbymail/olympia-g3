---
title: The turn-resolution model
weight: 2
---

Olympia is a **simultaneous-resolution** game: every faction submits its orders
for the turn without knowing what anyone else submitted, and the engine then
resolves them all together. This page explains how that resolution actually works,
because understanding it explains a lot of otherwise surprising behaviour — why a
move only goes so far, why two factions can both act "first", and why some orders
spill over into the next turn.

## A turn is a simulated month

One turn is one **month of game time: 30 days** (and a year is 8 months). The
engine does not apply your orders as a single instantaneous batch. Instead it
*simulates the month day by day*, advancing the clock one day at a time and
letting every noble in the world make progress on its current order each day.

That daily simulation is the heart of the model. Most of what feels distinctive
about Olympia falls out of it.

## Orders take time

Every order has a **duration**. Some are instantaneous (renaming a unit, setting
an attitude); others take days (movement, building, studying) or a fixed span
(many actions take 7 days; a trance takes 28). A noble works on one order at a
time, and the order occupies the noble for its duration.

Because the month is only 30 days long, **a noble can only do so much in a turn.**
If you queue more work than fits, the later orders simply do not start this month.

## Orders queue and carry over

The orders you write for a noble form a **queue**. The noble starts the first one;
when it finishes, the next loads and begins, and so on through the day-by-day
simulation until the month ends or the queue empties.

Two consequences:

- **Long orders carry over.** A journey or a construction project that needs more
  than the remaining days does not fail — it continues automatically at the start
  of the next turn, picking up where it left off.
- **Order matters.** Since orders run in the sequence you wrote them, putting a
  slow order first can starve the rest of the turn. You are scheduling a month,
  not listing independent wishes.

## Priority decides who goes first

Within the simultaneous turn, orders are not all equal. Each order type carries a
**priority**, and at the start of the turn the engine processes pending orders in
priority order rather than by faction or by submission order. This is how the
engine resolves the "who acts first" question fairly: it is decided by *what* is
being done, not *who* submitted it earliest.

This is why, for example, certain defensive or positional actions reliably take
effect relative to the actions they are meant to counter — their priority places
them at the right point in the sequence.

## Interrupts

A noble's in-progress order can be **interrupted** by events around it — most
visibly, combat. When something interrupts a unit, its current long-running order
is halted so the unit can respond, rather than the unit blindly continuing to walk
or build through a battle. Interrupted units are handled at the very start of the
turn before normal order processing begins.

## Daily events

Alongside players' orders, the engine runs **daily events** as the month advances:
weather, market trades matching up, population and economic changes, and the
scheduled happenings of the world. These are not driven by anyone's orders — they
are the world living its month while the factions act within it.

## Why this design

Simultaneous, time-based resolution is what gives Olympia its particular texture.
Because nobody sees others' orders first, play is about **anticipation** rather
than reaction. Because actions take real time and queue up, a turn is an exercise
in **scheduling under uncertainty** — committing a month of a noble's effort to a
plan you cannot adjust mid-stream. And because long actions carry over, the game
rewards **multi-turn projects** over single-turn opportunism.

## See also

- The pieces you are scheduling: [Game concepts](../game-concepts/).
- How long specific orders take: the
  [order catalog](../../reference/order-catalog/).
- The structure of a submitted turn:
  [Orders file format](../../reference/orders-file-format/).
