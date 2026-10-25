-- use-beast-refused.lua -- build the use-beast-refused scenario (issue #194).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. One faction, 300 "Bunglers", starts in Greyfell
-- (start city 0). Its noble knows every usable beastmastery skill but has no
-- animals and no drum, is poofed to Forest [13451], where no wild horses
-- roam, and orders each use:
--
--   use 651          fail: no location to spy on
--   use 654 51 51    fail: no wild horses to breed
--   use 655 1        fail: no wild horses roam the forest
--   use 656 1        fail: no wild horse to train
--   use 657 1        fail: no wild horse to train
--   use 658          fail: no drum
--   use 659 <self>   fail: not a group of savages
--
-- Each start returns FALSE (fail). breed_hound (661) always starts, so it
-- is not ordered.

local oly = require "oly"

local WILD_HORSE = 51			-- item

local BEAST, BIRD_SPY, BREED, CATCH = 650, 651, 654, 655	-- skills
local TRAIN_WILD, TRAIN_WAR, SUMMON, KEEP = 656, 657, 658, 659

local GREYFELL = 57081			-- start city 0
local FOREST = 13451

oly.load("./lib")
oly.extract_startlocs()

local bunglers = oly.add_player{
	id = 300, faction = "Bunglers",
	noble = "bungler", noble_name = "Bungler One",
	start = "0", full_name = "P Word Here", email = "player300@example.com",
}
local bungler = bunglers.noble

assert(oly.loc(bungler) == GREYFELL, "the bungler must start in Greyfell")

for _, sk in ipairs{ BEAST, BIRD_SPY, BREED, CATCH, TRAIN_WILD, TRAIN_WAR,
		SUMMON, KEEP } do
	oly.know(bungler, sk)
end
oly.poof(bungler, FOREST)

assert(oly.loc(bungler) == FOREST, "the bungler must be in the forest")

oly.order(bungler, "use " .. BIRD_SPY)
oly.order(bungler, "use " .. BREED .. " " .. WILD_HORSE .. " " .. WILD_HORSE)
oly.order(bungler, "use " .. CATCH .. " 1")
oly.order(bungler, "use " .. TRAIN_WILD .. " 1")
oly.order(bungler, "use " .. TRAIN_WAR .. " 1")
oly.order(bungler, "use " .. SUMMON)
oly.order(bungler, "use " .. KEEP .. " " .. bungler)

oly.save("./lib")

print(string.format("built use-beast-refused: bungler=%d", bungler))
