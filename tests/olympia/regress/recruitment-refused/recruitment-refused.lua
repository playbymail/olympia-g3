-- recruitment-refused.lua -- build the recruitment-refused scenario (issue #130).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. One faction, 300 "Bunglers", in Greyfell (start
-- city 0). Its noble builds a tower there and stands in it, with no
-- recruitment skill, and orders every recruitment verb:
--
--   recruit   fail: the tower has no peasants (recruit in provinces)
--   form      fail: nobles may only be formed in cities
--   raise     fail: requires Raise peasant mob
--   rally     fail: requires Rally peasant mob
--
-- The player entity orders the same verbs (rejected: noble-only verbs).

local oly = require "oly"

local PEASANT = 10			-- item

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

local tower = oly.makeloc(bungler, "tower")
oly.poof(bungler, tower)

assert(oly.loc(bungler) == tower, "the bungler must be in the tower")
assert(not oly.has_item(tower, PEASANT), "the tower must have no peasants")

local orders = { "recruit 1", "form", "raise", "rally " .. bungler }

for _, o in ipairs(orders) do
	oly.order(bungler, o)
end
for _, o in ipairs(orders) do
	oly.order(bunglers.player, o)
end

oly.save("./lib")

print(string.format("built recruitment-refused: player=%d bungler=%d tower=%d",
	bunglers.player, bungler, tower))
