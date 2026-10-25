-- use-forestry-refused.lua -- build the use-forestry-refused scenario
-- (issue #192).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. One faction, 300 "Bunglers", starts in Greyfell
-- (start city 0). Its noble knows every usable forestry skill but is poofed
-- to Plain [13450], which has no lumber, yew or poppy field, and orders
-- each use:
--
--   use 702 1    fail: no lumber here
--   use 703 1    fail: no yew here
--   use 707      fail: not in a poppy field
--
-- Each start returns FALSE (fail). make_ram (701) has no start, so it
-- cannot fail and is not ordered.

local oly = require "oly"

local FORESTRY, HARVEST_LUMBER, HARVEST_YEW = 700, 702, 703	-- skills
local SK_705, IMPROVE_OPIUM = 705, 707

local GREYFELL = 57081			-- start city 0
local PLAIN = 13450

oly.load("./lib")
oly.extract_startlocs()

local bunglers = oly.add_player{
	id = 300, faction = "Bunglers",
	noble = "bungler", noble_name = "Bungler One",
	start = "0", full_name = "P Word Here", email = "player300@example.com",
}
local bungler = bunglers.noble

assert(oly.loc(bungler) == GREYFELL, "the bungler must start in Greyfell")

for _, sk in ipairs{ FORESTRY, HARVEST_LUMBER, HARVEST_YEW,
		SK_705, IMPROVE_OPIUM } do
	oly.know(bungler, sk)
end
oly.poof(bungler, PLAIN)

assert(oly.loc(bungler) == PLAIN, "the bungler must be on the plain")

oly.order(bungler, "use " .. HARVEST_LUMBER .. " 1")
oly.order(bungler, "use " .. HARVEST_YEW .. " 1")
oly.order(bungler, "use " .. IMPROVE_OPIUM)

oly.save("./lib")

print(string.format("built use-forestry-refused: bungler=%d", bungler))
