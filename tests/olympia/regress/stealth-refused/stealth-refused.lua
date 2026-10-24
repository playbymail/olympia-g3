-- stealth-refused.lua -- build the stealth-refused scenario (issue #145).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Three factions start in Greyfell (start city 0):
--
--   bungler    knows no stealth skill: hide 1 and hide 0 fail (no Hide
--              self), torture fails (no Torture), and sneak into the
--              loner's tower fails (not alone: its 25 peasants count)
--   crowd      knows Hide self and Torture but keeps its 25 peasants:
--              hide 1 fails (not alone), and torture of the bungler fails
--              (not a prisoner)
--   loner      alone (no peasants) in Greyfell, owns a tower but stays
--              outside it: sneak with no direction fails (not in a
--              structure), and sneak north fails (a province is not a
--              building or ship)
--
-- Rejected: every stealth verb is for nobles (c), so the player entity's
-- hide, sneak and torture are refused.

local oly = require "oly"

local PEASANT = 10			-- item

local GREYFELL = 57081			-- start city 0

local TORTURE = 637			-- skills
local HIDE_SELF = 638

oly.load("./lib")
oly.extract_startlocs()

local function faction(id, name, handle, noble_name)
	local f = oly.add_player{
		id = id, faction = name,
		noble = handle, noble_name = noble_name,
		start = "0", full_name = "P Word Here",
		email = string.format("player%d@example.com", id),
	}
	assert(oly.loc(f.noble) == GREYFELL, noble_name .. " must start in Greyfell")
	return f
end

local bunglers = faction(300, "Bunglers", "bungler", "Bungler One")
local crowds = faction(301, "Crowds", "crowd", "Crowd One")
local loners = faction(302, "Loners", "loner", "Loner One")
local bungler, crowd, loner = bunglers.noble, crowds.noble, loners.noble

oly.know(crowd, HIDE_SELF)
oly.know(crowd, TORTURE)

oly.subitem(loner, PEASANT, 25)
assert(not oly.has_item(loner, PEASANT), "the loner must be alone")

local tower = oly.makeloc(loner, "tower", "tower")
assert(oly.loc(tower) == GREYFELL, "the tower must be in Greyfell")
assert(oly.loc(loner) == GREYFELL, "the loner must be outside the tower")

for _, o in ipairs{
		"hide 1", "hide 0", "torture " .. crowd,
		"sneak " .. tower } do
	oly.order(bungler, o)
end
oly.order(crowd, "hide 1")
oly.order(crowd, "torture " .. bungler)
oly.order(loner, "sneak")
oly.order(loner, "sneak north")
for _, o in ipairs{ "hide 1", "sneak " .. tower, "torture " .. bungler } do
	oly.order(bunglers.player, o)
end

oly.save("./lib")

print(string.format("built stealth-refused: player=%d bungler=%d crowd=%d "
	.. "loner=%d tower=%d", bunglers.player, bungler, crowd, loner, tower))
