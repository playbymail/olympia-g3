-- use-crafts-refused.lua -- build the use-crafts-refused scenario (issue #190).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. One faction, 300 "Bunglers", starts in Greyfell
-- (start city 0). Its noble knows every shipcraft, construction, mining and
-- trade skill but is poofed to Plain [13450], which has no ship, mine,
-- stone, fish or city, and orders each use:
--
--   use 601 east   fail: not on a ship
--   use 602        fail: always ("Use the BUILD order to build ships.")
--   use 603 1      fail: no fish here
--   use 682 1      fail: no stone here
--   use 721..723   fail: not in a mine
--   use 732        fail: not in a city
--   use 733 <x>    fail: not in a city
--
-- Each start returns FALSE (fail). make_siege (681) has no start, so it
-- cannot fail and is not ordered.

local oly = require "oly"

local SHIPCRAFT, SAILING, SHIPBUILDING, FISHING = 600, 601, 602, 603	-- skills
local CONSTRUCTION, QUARRY_STONE = 680, 682
local MINING, MINE_IRON, MINE_GOLD, MINE_MITHRIL = 720, 721, 722, 723
local TRADE, FIND_SELL, FIND_BUY = 730, 732, 733

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

for _, sk in ipairs{ SHIPCRAFT, SAILING, SHIPBUILDING, FISHING,
		CONSTRUCTION, QUARRY_STONE,
		MINING, MINE_IRON, MINE_GOLD, MINE_MITHRIL,
		TRADE, FIND_SELL, FIND_BUY } do
	oly.know(bungler, sk)
end
oly.poof(bungler, PLAIN)

assert(oly.loc(bungler) == PLAIN, "the bungler must be on the plain")

for _, o in ipairs{
	"use " .. SAILING .. " east", "use " .. SHIPBUILDING,
	"use " .. FISHING .. " 1", "use " .. QUARRY_STONE .. " 1",
	"use " .. MINE_IRON, "use " .. MINE_GOLD, "use " .. MINE_MITHRIL,
	"use " .. FIND_SELL, "use " .. FIND_BUY .. " 1",
} do
	oly.order(bungler, o)
end

oly.save("./lib")

print(string.format("built use-crafts-refused: bungler=%d", bungler))
