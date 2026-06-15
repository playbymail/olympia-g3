---
title: Orders file format
weight: 1
---

A player submits a turn as one plain-text **orders file**. This page describes its
structure exactly. For a walkthrough of writing one, see
[Your first turn as a player](../../tutorials/player-first-turn/).

## Overall structure

An orders file is a single block that opens with `begin` and closes with `end`.
Inside, `unit` lines switch which noble the following orders apply to:

```text
begin <faction> ["<password>"]

unit <noble>
    <order>
    <order>

unit <noble>
    <order>

end
```

Indentation and blank lines are optional and ignored.

## Block keywords

These keywords structure the file; they are not game actions.

| Keyword | Form | Meaning |
|---|---|---|
| `begin` | `begin <faction> ["<password>"]` | Opens the block. Names your faction and, if the faction has one, its password. |
| `unit` | `unit <noble>` | Directs all following orders to noble `<noble>`, until the next `unit` or `end`. |
| `end` | `end` | Closes the block. Anything after it is ignored. |

### `begin`

- `<faction>` is your faction code (a short code such as `aa1`). It must be the
  first argument.
- `<password>` is required **only if your faction has a password set**. Wrap it in
  double quotes. If the password is missing or wrong, the **entire file is
  rejected**.

### `unit`

- `<noble>` must be a character (or unformed unit) your faction controls.
- A `unit` line addressed to a noble that is not yours produces a warning and its
  orders are skipped.
- `begin` must appear before any `unit` line.

## Comments

Text from a `#` to the end of the line is ignored:

```text
unit 1234
    north        # head toward the coast
    explore
```

## Order lines

Each order line is one command keyword followed by its arguments — see the
[order catalog](../order-catalog/) for the full list. Two prefixes modify an order
based on the previous one's outcome:

| Prefix | Meaning |
|---|---|
| `&` | Run this order only if the **previous order succeeded**. |
| `?` | Run this order only if the **previous order failed**. |

```text
unit 1234
    move bz12
    & explore        # only if the move succeeded
    ? north          # only if the move failed
```

## Identifiers

Arguments that name something in the game use its entity code:

- **Nobles / characters** are shown as numbers (for example `1234`).
- **Factions / players** are short codes (for example `aa1`).
- **Provinces and sublocations** are letter-and-digit codes (for example `bz12`,
  `5601`).

Use the codes exactly as they appear in your turn report.
