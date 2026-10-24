-- production-refused.lua -- build the production-refused scenario (issue #126).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. One faction, 300 "Bunglers", in Greyfell (start
-- city 0). Its noble has no production skill and no peasants, and orders
-- every production verb:
--
--   make, train      fail: no peasants to make workers from
--   the harvests     fail: the harvest skill is missing
--
-- The player entity orders the same verbs  (rejected: noble-only verbs).

local oly = require "oly"

local PEASANT, WORKER = 10, 11		-- items
local STONE = 78

local GREYFELL = 57081			-- start city 0

oly.load("./lib")
oly.extract_startlocs()

local bunglers = oly.add_player{
	id = 300, faction = "Bunglers",
	noble = "bungler", noble_name = "Bungler One",
	start = "0", full_name = "P Word Here", email = "player300@example.com",
}
local bungler = bunglers.noble

assert(oly.loc(bungler) == GREYFELL, "the bungler must start in Greyfell")

oly.subitem(bungler, PEASANT, 25)
assert(not oly.has_item(bungler, PEASANT), "peasants must be removed")

local orders = {
	"make " .. WORKER .. " 1", "train " .. WORKER .. " 1",
	"quarry 1", "stone 1", "collect " .. STONE .. " 1",
	"wood 1", "yew 1", "mallorn 1", "opium 1", "catch 1", "fish 1",
}

for _, o in ipairs(orders) do
	oly.order(bungler, o)
end
for _, o in ipairs(orders) do
	oly.order(bunglers.player, o)
end

oly.save("./lib")

print(string.format("built production-refused: player=%d bungler=%d",
	bunglers.player, bungler))
