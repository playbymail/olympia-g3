-- stealth-hide.lua -- build the stealth-hide scenario (issue #145).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Four factions start in Greyfell (start city 0):
--
--   hider      knows Hide self, alone: hides (hide 1), then unhides (hide 0)
--   sneaker    alone and owns a tower: sneaks out of it, then back in
--   yielder    forms a hireling, which surrenders to the captor once it
--              exists (contract-500, so it talks on a 50% draw; starting
--              nobles are oath-2 and never talk)
--   captor     knows Torture: waits out the surrender, then tortures its
--              prisoner, who talks (the draw is keyed on captor, prisoner
--              and the finish day; with the yielders first and the torture
--              finishing on day 17 it succeeds)
--
-- Every start returns TRUE (ok). The hireling's orders are queued before
-- it exists; they run once the yielder's 7-day form makes it, on day 8.

local oly = require "oly"

local GREYFELL = 57081			-- start city 0

local PEASANT = 10			-- item

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

local hiders = faction(300, "Hiders", "hider", "Hider One")
local sneakers = faction(301, "Sneakers", "sneaker", "Sneaker One")
local yielders = faction(302, "Yielders", "yielder", "Yielder One")
local captors = faction(303, "Captors", "captor", "Captor One")
local hider, sneaker = hiders.noble, sneakers.noble
local captor, yielder = captors.noble, yielders.noble

-- the noble the yielder's form makes; its orders are queued here
local hireling = yielders.unformed[1]
assert(hireling, "the yielders need an unformed noble")

-- alone means no men either: a starting noble's 25 peasants count
for _, who in ipairs{ hider, sneaker } do
	oly.subitem(who, PEASANT, 25)
	assert(not oly.has_item(who, PEASANT), "hider and sneaker must be alone")
end

oly.know(hider, HIDE_SELF)
oly.know(captor, TORTURE)

-- the first character inside a building is its owner
local tower = oly.makeloc(sneaker, "tower", "tower")
oly.poof(sneaker, tower)
assert(oly.loc(tower) == GREYFELL, "the tower must be in Greyfell")
assert(oly.loc(sneaker) == tower, "the sneaker must own the tower")

oly.order(hider, "hide 1")
oly.order(hider, "hide 0")
oly.order(sneaker, "sneak")
oly.order(sneaker, "sneak " .. tower)
oly.order(yielder, "form " .. hireling .. " Hireling")
oly.order(hireling, "surrender " .. captor)
oly.order(captor, "wait time 10")
oly.order(captor, "torture " .. hireling)

oly.save("./lib")

print(string.format("built stealth-hide: hider=%d sneaker=%d captor=%d "
	.. "yielder=%d hireling=%d tower=%d", hider, sneaker, captor, yielder,
	hireling, tower))
