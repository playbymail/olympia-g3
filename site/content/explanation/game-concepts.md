---
title: Game concepts
weight: 1
---

This page explains the core building blocks of Olympia G3 and how they fit
together. It is for both players and game masters: the same handful of concepts
underlies everything you do, whether you are issuing orders or running the world.

## Factions and nobles

You do not control a single avatar. You control a **faction** — a player position
identified by a short code such as `aa1` — and a faction is a collection of
**nobles** (also called characters or units), each identified by a number such as
`1234`.

The distinction matters because almost every order is addressed to a *noble*, not
to the faction. Your faction is the account and the shared treasury; your nobles
are the hands that actually move, fight, build, and study. When you write an
orders file you open it with your faction (`begin aa1 …`) and then dispatch
orders noble by noble (`unit 1234 …`).

## Stacks

Nobles in the same place can **stack** together: one noble leads, others stack
beneath it. A stack moves as a unit and fights as a unit, which makes stacking the
basic tool of both logistics and war — you concentrate force by stacking nobles,
and you move an army by giving one movement order to the stack leader.

This is why orders like `stack`, `unstack`, and `promote` exist: they arrange the
tree of who-follows-whom, which in turn decides who travels with whom and who
leads in combat.

## Locations

The world is a hierarchy of **locations**. At the top are **provinces** — the
grid squares of the map, coded like `bz12` — each with a terrain type that governs
movement and what can be produced there. Inside provinces are **sublocations**:
cities, ships, towers, and other structures, coded like `5601`.

Movement is navigation through this hierarchy. Compass moves (`north`, `east`, …)
step between adjacent provinces; `enter`/`exit` move in and out of sublocations.
What you can *do* in a location depends on where you are: you recruit where there
is population, you sail from a coast, you quarry where there is stone.

## Items, gold, and the economy

Everything a noble carries is an **item**: gold, peasants and soldiers, raw
materials, trade goods, tools, and artifacts. Even your fighting strength is items
— a noble with twenty peasants and ten soldiers literally holds those as
quantities.

Gold is the universal medium. You recruit men, pay for construction, buy and sell
in markets, and bribe with it. Because population and resources are tied to
specific locations, the economy is fundamentally about *moving the right items to
the right place* — gathering raw materials where they occur, carrying them to
where they can be made into something useful, and selling where there is demand.

## Skills

Nobles improve by learning **skills**. `study` advances a skill over time;
`research` pursues advanced knowledge; `use` invokes what has been learned. Skills
gate capability: many actions — especially magic and specialist production —
require a noble to have studied the relevant skill first.

Skills take real in-game time to learn, so a faction's expertise is an investment
built up over many turns, not something bought instantly.

## How it fits together

A turn, then, is you arranging these pieces: deciding which **nobles** (organized
into **stacks**) go to which **locations** to convert **items** and **skills**
into progress for your **faction**. Every order in the
[catalog](../../reference/order-catalog/) is an operation on one of these
concepts.

To see how those orders actually play out in time, read
[The turn-resolution model](../turn-resolution-model/).
