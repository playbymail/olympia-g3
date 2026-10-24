-- inventory-give.lua -- build the inventory-give scenario (issue #127).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Three factions start in Greyfell (start city 0):
--
--   keeper   forms a porter (get/take only work on the keeper's own units),
--            then gives, takes, gets, pays, claims, discards and drops
--   trader   accepts the peasants the keeper gives it on day 8
--   leaver   reclaims (disperses) itself
--
-- Every start returns TRUE (ok). The trader's accept runs on day 1 and the
-- keeper's give after its 7-day form, so the give is never refused.

local oly = require "oly"

local GOLD, PEASANT = 1, 10		-- items

local GREYFELL = 57081			-- start city 0

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

local keepers = faction(300, "Keepers", "keeper", "Keeper One")
local traders = faction(301, "Traders", "trader", "Trader One")
local leavers = faction(302, "Leavers", "leaver", "Leaver One")
local keeper, trader, leaver = keepers.noble, traders.noble, leavers.noble

-- the noble the keeper's form makes; orders below name it as the target
local porter = keepers.unformed[1]
assert(porter, "the keepers need an unformed noble")

assert(oly.has_item(keepers.player, GOLD), "the keepers need gold to claim")

for _, o in ipairs{
		"form " .. porter .. " Porter",
		"give " .. porter .. " " .. PEASANT .. " 6",
		"take " .. porter .. " " .. PEASANT .. " 2",
		"get " .. porter .. " " .. PEASANT .. " 2",
		"give " .. trader .. " " .. PEASANT .. " 3",
		"pay " .. trader .. " 25",
		"claim " .. GOLD .. " 100",
		"discard " .. PEASANT .. " 1",
		"drop " .. PEASANT .. " 1" } do
	oly.order(keeper, o)
end
oly.order(trader, "accept " .. keeper .. " " .. PEASANT .. " 3")
oly.order(leaver, "reclaim")

oly.save("./lib")

print(string.format("built inventory-give: keeper=%d porter=%d trader=%d "
	.. "leaver=%d", keeper, porter, trader, leaver))
