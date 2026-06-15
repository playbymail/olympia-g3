---
title: Recruit units
weight: 2
---

This guide shows how to grow a noble's fighting strength by recruiting peasants —
the basic soldiery you build a stack from. It assumes you can already write and
submit an orders file (see
[Your first turn as a player](../../tutorials/player-first-turn/)).

## Before you start

Recruiting only works where there are people to hire and money to pay them:

- the noble must be in a **province or city with available population** (cities
  and settled provinces have men to recruit; empty wilderness does not), and
- the noble (or its stack) must be carrying enough **gold** — each recruit costs
  gold, paid from your holdings.

## Recruit peasants

`recruit` takes the number of men you want to hire:

```text
unit 1234
    recruit 20
```

The noble hires *up to* 20 peasants, limited by the population on hand and the
gold available. Recruiting takes time, so it runs over part of the turn rather
than completing instantly.

## Recruit as many as you can afford

If you just want to take everyone available, ask for a large number — you are
capped by population and gold, never charged for men you did not get:

```text
unit 1234
    recruit 100
```

## Confirm the recruits arrived

In next turn's report, check the noble's **inventory**: the peasant count should
have risen by the number actually hired, and your **gold** should have dropped to
match. If nothing changed, the location had no population to recruit, or the
noble had no gold — move to a city or transfer gold first.

## Related

- Move the noble to a city before recruiting:
  [How to issue movement orders](../../how-to/issue-movement-orders/).
- What `recruit` is shorthand for, and related gathering orders:
  the [order catalog](../../reference/order-catalog/#production--gathering).
