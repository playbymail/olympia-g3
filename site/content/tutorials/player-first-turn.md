---
title: Your first turn as a player
weight: 1
---

In this tutorial you will write a small set of orders for one noble, submit them,
and read the turn report that comes back. By the end you will have completed a
full play cycle: **orders in → turn runs → report out.** You do not need to
understand the whole game to finish — just follow along.

{{< callout type="info" >}}
You need an active position in a running game: a **faction id** (a short code
like `aa1`), a **password**, and at least one **noble** (a number like `1234`)
that the game master set up for you. If you do not have these yet, ask your GM.
{{< /callout >}}

## What you are aiming for

A faction in Olympia is a group of nobles you command. Each turn you send the
game one text file of orders. The engine runs every faction's orders together,
then mails you a report describing what your nobles saw and did. That is the
whole loop, and you are about to run it once.

## Step 1 — Start the orders file

Open a plain-text editor and create a file. Every orders file is one block that
opens with `begin` and closes with `end`:

```text
begin aa1 "swordfish"

end
```

The `begin` line names your faction (`aa1`) and your password (`"swordfish"`).
Replace both with your own. Keep the password in double quotes.

## Step 2 — Address a noble

Inside the block, the `unit` keyword selects which noble the following orders
apply to. Add your noble's number:

```text
begin aa1 "swordfish"

unit 1234

end
```

Every order you write after `unit 1234` is carried out by noble `1234`, until
the next `unit` line or `end`.

## Step 3 — Give three orders

Add three orders for the noble. We will name the noble, move it one province
north, then have it explore where it arrives:

```text
begin aa1 "swordfish"

unit 1234
    name "Captain Reyes"
    north
    explore

end
```

What each order does:

- `name "Captain Reyes"` — renames the noble. Instant, and a safe way to confirm
  the orders parsed.
- `north` — moves the noble one province north. Movement takes time; the noble
  spends part of the month travelling.
- `explore` — once it arrives, the noble searches the new province for hidden
  features and routes.

The leading indentation is optional; it just makes the file easier to read.

## Step 4 — Submit the orders

Send the file to your game the way your GM specified (typically email to the game
address, or dropping it in the order spool). The engine reads the `begin` line to
find your faction, checks the password, and queues the orders against your
nobles.

{{< callout type="warning" >}}
If the password is wrong or the faction code is mistyped, the **whole file is
rejected**. A correct `begin` line is the one thing you must get right.
{{< /callout >}}

## Step 5 — Read the report

After the GM runs the turn you receive a report. Two things to look for first:

- A **confirmation** echoing the orders the engine accepted from you. If an order
  is missing here, it was rejected — check the spelling against the
  [order catalog](../../reference/order-catalog/).
- Your noble's **new location** and an **explore result** listing what it found.

That is a complete turn. You issued orders, the engine resolved them, and the
report told you what happened.

## Where to go next

- Do more on a turn: [How to issue movement orders](../../how-to/issue-movement-orders/)
  and [How to recruit units](../../how-to/recruit-units/).
- Look up any order: the [order catalog](../../reference/order-catalog/).
- Understand *why* a move spans part of a month:
  [The turn-resolution model](../../explanation/turn-resolution-model/).
