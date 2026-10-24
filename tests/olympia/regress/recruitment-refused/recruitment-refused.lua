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
--
-- A second faction's noble, which knows both mob skills, stands in Forest
-- [13449] after oly.mob (#139) has raised a mob there, so its orders fail
-- past the skill check:
--
--   raise     fail: the forest's mob cookie is spent
--   rally     fail: it names the noble itself, not a peasant mob

local oly = require "oly"

local PEASANT = 10			-- item
local RAISE_MOB, RALLY_MOB = 673, 674	-- skills

local GREYFELL = 57081			-- start city 0
local FOREST = 13449

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

local latecomers = oly.add_player{
	id = 301, faction = "Latecomers",
	noble = "latecomer", noble_name = "Latecomer One",
	start = "0", full_name = "P Word Here", email = "player301@example.com",
}
local latecomer = latecomers.noble

oly.know(latecomer, RAISE_MOB)
oly.know(latecomer, RALLY_MOB)
oly.poof(latecomer, FOREST)
oly.mob(FOREST)

assert(oly.loc(latecomer) == FOREST, "the latecomer must be in the forest")

oly.order(latecomer, "raise")
oly.order(latecomer, "rally " .. latecomer)

oly.save("./lib")

print(string.format("built recruitment-refused: player=%d bungler=%d "
	.. "tower=%d latecomer=%d", bunglers.player, bungler, tower, latecomer))
