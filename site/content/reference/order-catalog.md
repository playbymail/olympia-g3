---
title: Order catalog
weight: 2
---

The orders a player can issue, grouped by purpose. Each order is the first
keyword on a line inside a [`unit` block](../orders-file-format/); arguments
follow it. Many orders take time and run over part of a turn; some complete
instantly.

{{< callout type="info" >}}
This catalog covers the **player-usable** orders. The authoritative list is the
engine's command table (`cmd_tbl[]` in `olympia/glob.c`); immediate-mode and
game-master-only commands are omitted here. A few legacy orders have been
disabled — see [Removed orders](#removed-orders).
{{< /callout >}}

## Movement

| Order | Arguments | Effect |
|---|---|---|
| `move`, `go` | direction \| destination | Move toward a compass direction or an adjacent location code. |
| `north`/`n`, `south`/`s`, `east`/`e`, `west`/`w` | — | Move one province in that direction. |
| `enter`, `in` | location | Enter a sublocation (city, ship, building). |
| `exit`, `out` | — | Leave to the surrounding location. |
| `board` | vessel | Board a ship or other vessel. |
| `sail` | destination | Sail a vessel you control toward a destination. |
| `fly` | destination | Fly to a destination (requires the means to fly). |
| `ferry` | — | Operate a ferry to carry stacks across a connection. |
| `unload` | — | Unload cargo or passengers from a vessel. |

See also: [How to issue movement orders](../../how-to/issue-movement-orders/).

## Production & gathering

| Order | Arguments | Effect |
|---|---|---|
| `make`, `train` | item \[qty\] | Manufacture an item or train units. |
| `recruit` | qty \[days\] | Hire peasants (up to `qty`, gold and population permitting). |
| `collect` | item qty \[days\] | Gather a quantity of a basic item from the location. |
| `fish` | \[qty\] | Catch fish. |
| `wood` | \[qty\] | Harvest lumber. |
| `yew` | \[qty\] | Harvest yew. |
| `mallorn` | \[qty\] | Harvest mallorn wood. |
| `opium` | \[qty\] | Harvest opium. |
| `quarry`, `stone` | \[qty\] | Quarry stone. |
| `catch` | \[qty\] | Catch wild horses. |
| `breed` | — | Breed animals you hold. |
| `explore` | — | Search the current location for hidden features and routes. |

See also: [How to recruit units](../../how-to/recruit-units/).

## Construction

| Order | Arguments | Effect |
|---|---|---|
| `build` | — | Construct or extend a structure. |
| `repair` | — | Repair a damaged structure. |
| `improve` | — | Improve a structure or its defenses. |
| `raze` | — | Tear down a structure. |

## Items, money & trade

| Order | Arguments | Effect |
|---|---|---|
| `give` | target item qty | Give items to another unit. |
| `get`, `take` | target item qty | Take items from another unit. |
| `pay` | target amount | Pay gold to another unit. |
| `buy` | item qty price | Place a buy order in the local market. |
| `sell` | item qty price | Place a sell order in the local market. |
| `discard`, `drop` | item qty | Discard items. |
| `claim` | item \[qty\] | Claim items from your faction's common pool. |
| `use` | skill/item \[args\] | Use a learned skill or an item. |

## Skills & study

| Order | Arguments | Effect |
|---|---|---|
| `study` | skill | Study a skill to learn or advance it. |
| `research` | skill | Conduct advanced research into a skill. |

## Unit & stack management

| Order | Arguments | Effect |
|---|---|---|
| `form` | new-unit \[args\] | Form a new noble or unit (in a city). |
| `stack` | target | Stack this unit under another. |
| `unstack` | — | Leave the current stack. |
| `promote` | unit | Move a unit up in stack order. |
| `name` | "name" | Set the unit's name. |
| `realname` | "name" | Set the unit's full/real name. |
| `banner` | "text" | Set the unit's banner. |
| `behind` | level | Set combat position (front line vs. behind). |
| `wait` | condition | Pause order execution until a condition is met. |
| `stop` | — | Stop the current in-progress order. |

## Combat & defense

| Order | Arguments | Effect |
|---|---|---|
| `attack` | target | Attack another unit or stack. |
| `guard` | on/off | Guard the province against intruders. |
| `defend` | — | Take a defensive posture. |
| `hostile` | target | Mark a faction/unit as hostile. |
| `neutral` | target | Mark a faction/unit as neutral. |
| `default` | — | Clear attitude settings. |
| `surrender` | target | Surrender to an attacker. |
| `pillage` | — | Pillage the province for plunder. |
| `terrorize` | — | Terrorize the local population. |
| `execute` | — | Execute prisoners. |
| `garrison` | — | Install a garrison (at a controlled tower/structure). |
| `ungarrison` | — | Remove a garrison. |

## Diplomacy & faction

| Order | Arguments | Effect |
|---|---|---|
| `oath` | target | Swear/raise loyalty toward a superior noble. |
| `honor`, `honour` | target | Bestow honor on another noble. |
| `pledge` | target | Pledge a unit to a garrison/region authority. |
| `accept` | args | Accept an offer (items, control, etc.). |
| `admit` | who | Set who may stack with or enter you. |
| `contact` | target | Make contact with another character or faction. |
| `seek` | target | Search for a character or thing. |
| `bribe` | target amount | Bribe a unit. |
| `decree` | type args | Issue a region decree (with sufficient authority). |
| `reclaim` | — | Reclaim a controlled holding. |

## Communication

| Order | Arguments | Effect |
|---|---|---|
| `message` | target "text" | Send a private message. |
| `post` | "text" | Post a notice readable in the location. |
| `rumor` | "text" | Start a rumor. |
| `times` | "text" | Submit copy to the *Olympia Times*. |
| `press` | "text" | Submit a press item. |
| `public` | flag | Make information about you public. |
| `flag` | signal | Raise a one-per-month signal flag. |

## Magic & advanced

| Order | Arguments | Effect |
|---|---|---|
| `bind` | — | Bind a storm (weather magic). |
| `trance` | — | Enter a trance for lore work. |
| `quest` | args | Undertake a quest. |
| `hide` | — | Hide the unit from view. |
| `sneak` | destination | Move stealthily. |
| `incite` | target | Incite a peasant mob. |
| `rally` | mob | Rally a peasant mob. |
| `raise` | — | Raise the dead (necromancy). |
| `torture` | prisoner | Torture a prisoner for information. |

## Faction settings

| Order | Arguments | Effect |
|---|---|---|
| `format` | args | Set your report format. |
| `notab` | flag | Toggle a report-formatting option. |
| `quit` | — | Resign your position from the game. |

## Removed orders

A few orders from earlier Olympia versions are present in the engine but
disabled, and will be rejected if used:

- `swear` — removed from the game (use `oath`).
- `split` — no longer supported.
