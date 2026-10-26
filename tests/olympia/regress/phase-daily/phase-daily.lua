-- phase-daily.lua -- build the phase-daily scenario (issue #233).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Four factions start in Greyfell (start city 0)
-- and each noble is moved to where one daily event acts on it:
--
--   payee      Catchclaw [58706]     stacks under its default garrison
--                                    [1009], which pays it each day
--   flier      deep ocean [10100]    no ship: on day 15 its flight can no
--                                    longer be maintained
--   sailor     a ship on deep ocean  no coast in sight: on day 21 hungry
--                                    birds circle overhead
--   shadow     Greyfell, alone       starts the turn hidden, so the dogs
--                                    bark on dog_bark_day (day 2 of turn 1)
--   kennel     Greyfell, 3 hounds    the dogs that bark
--
-- The deep ocean provinces have ocean on all four sides, so
-- near_rocky_coast() is 3 for a ship on them, and each day a ship there
-- draws a keyed omen roll (1-3 of 200) on its id. The sailor makes 12
-- ships and boards the last, the first minted id whose roll hits; the
-- other 11 sail empty. The shadow is hidden by oly.hide, as an earlier
-- turn's hide leaves it: a hide in the turn takes 3 days.

local oly = require "oly"

local PEASANT, HOUND = 10, 295		-- items

local GREYFELL = 57081			-- start city 0
local CATCHCLAW = 58706			-- a city with a default garrison
local CATCHCLAW_GARRISON = 1009
local FLIGHT_SEA = 10100		-- deep ocean
local SHIP_SEA = 10102			-- deep ocean
local SHIPS = 12			-- the 12th ship minted rolls an omen

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
	return f.noble
end

local payee = faction(300, "Payees", "payee", "Payee One")
local flier = faction(301, "Fliers", "flier", "Flier One")
local sailor = faction(302, "Sailors", "sailor", "Sailor One")
local shadow = faction(303, "Shadows", "shadow", "Shadow One")
local kennel = faction(304, "Kennels", "kennel", "Kennel One")

oly.poof(payee, CATCHCLAW)
assert(oly.loc(CATCHCLAW_GARRISON) == CATCHCLAW,
	"Catchclaw's default garrison must be in Catchclaw")
oly.order(payee, "stack " .. CATCHCLAW_GARRISON)

oly.poof(flier, FLIGHT_SEA)

local ships = {}
oly.poof(sailor, SHIP_SEA)
for i = 1, SHIPS do
	ships[i] = oly.makeloc(sailor, "roundship")
	assert(oly.loc(ships[i]) == SHIP_SEA, "the ship must be on the sea")
end
oly.poof(sailor, ships[SHIPS])

-- alone means no men either: a starting noble's 25 peasants count
oly.subitem(shadow, PEASANT, 25)
oly.hide(shadow)
assert(not oly.has_item(shadow, PEASANT), "the shadow must be alone")

oly.additem(kennel, HOUND, 3)

oly.save("./lib")

print(string.format("built phase-daily: payee=%d flier=%d sailor=%d "
	.. "shadow=%d kennel=%d ships=%s", payee, flier, sailor, shadow, kennel,
	table.concat(ships, ",")))
