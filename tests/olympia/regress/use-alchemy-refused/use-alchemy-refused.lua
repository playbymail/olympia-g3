-- use-alchemy-refused.lua -- build the use-alchemy-refused scenario
-- (issue #192).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. One faction, 300 "Bunglers", starts in Greyfell
-- (start city 0). Its noble knows record_skill and lead_to_gold, and has
-- the blank scroll record_skill requires, but no farrenstone or lead:
--
--   use 692 600   fail: the bungler does not know Shipcraft
--   use 697       fail: no farrenstone
--
-- Each start returns FALSE (fail). The brews' start, v_brew, always
-- returns TRUE, and extract_venom has no start, so they cannot fail and
-- are not ordered.

local oly = require "oly"

local BLANK_SCROLL = 84			-- item
local SHIPCRAFT = 600			-- skills
local ALCHEMY, RECORD_SKILL, LEAD_TO_GOLD = 690, 692, 697

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

for _, sk in ipairs{ ALCHEMY, RECORD_SKILL, LEAD_TO_GOLD } do
	oly.know(bungler, sk)
end
oly.additem(bungler, BLANK_SCROLL, 1)

oly.order(bungler, "use " .. RECORD_SKILL .. " " .. SHIPCRAFT)
oly.order(bungler, "use " .. LEAD_TO_GOLD)

oly.save("./lib")

print(string.format("built use-alchemy-refused: bungler=%d", bungler))
