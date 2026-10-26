-- sail-out-first.lua -- build the sail-out-first scenario (issue #266).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Three factions start in Greyfell (start city 0);
-- each captain is moved to the island [59113] in the Ocean [13198], builds
-- a roundship there, crews it with 8 sailors and boards it. The Ocean
-- [13199] lies east of [13198]. An island has no compass exits of its own,
-- only "out" to the ocean around it, so a ship docked there must sail out
-- before it can sail anywhere else:
--
--   one      captain: sail 13199          (destination id)
--   two      captain: sail east           (direction, control)
--   three    captain: sail nowhere bp99   (bad argument, then destination code)
--
-- No argument works from the island, so v_sail asks whether the last one
-- works from the Ocean [13198] and, if it does, sails out first. Before the
-- fix that check saw the argument's word but not its parsed id (cmd_shift had
-- already set c->a to 0), so a destination never passed it: one and three
-- stayed at the island. With the fix all three sail out, then east to
-- [13199].

local oly = require "oly"

local PEASANT, SAILOR = 10, 19		-- items: peasants (25 per new noble), sailors
local SAILING = 601			-- sk_pilot_ship, needed to sail
local GREYFELL = 57081			-- start city 0
local ISLAND = 59113			-- an island in the Ocean 13198

oly.load("./lib")
oly.extract_startlocs()

local function captain(id, name, handle, noble_name)
	local f = oly.add_player{
		id = id, faction = name,
		noble = handle, noble_name = noble_name,
		start = "0", full_name = "P Word Here",
		email = string.format("player%d@example.com", id),
	}
	assert(oly.loc(f.noble) == GREYFELL, noble_name .. " must start in Greyfell")
	oly.know(f.noble, SAILING)
	oly.subitem(f.noble, PEASANT, 25)
	oly.additem(f.noble, SAILOR, 8)
	oly.poof(f.noble, ISLAND)
	local ship = oly.makeloc(f.noble, "roundship", "ship")
	oly.poof(f.noble, ship)
	assert(oly.loc(ship) == ISLAND, noble_name .. "'s ship must be at the island")
	assert(oly.loc(f.noble) == ship, noble_name .. " must be aboard the ship")
	return f.noble, ship
end

local one, ship1 = captain(300, "One", "one", "One Captain")
local two, ship2 = captain(301, "Two", "two", "Two Captain")
local three, ship3 = captain(302, "Three", "three", "Three Captain")

oly.order(one, "sail 13199")
oly.order(two, "sail east")
oly.order(three, "sail nowhere bp99")

oly.save("./lib")

print(string.format("built sail-out-first: one=%d/%d two=%d/%d three=%d/%d",
	one, ship1, two, ship2, three, ship3))
