-- production-harvest.lua -- build the production-harvest scenario (issue #126).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Seven factions start in Greyfell (start city 0),
-- and each noble is poofed to a place that holds what it harvests, with the
-- skill and the workers or sailors its harv_tbl row needs:
--
--   quarryman   Mountain [13349]     make, train (workers), quarry, stone,
--                                    collect stone
--   woodcutter  Forest [13451]       wood
--   bowyer      Yew grove [62199]    yew
--   elf-friend  Mallorn grove [74976] mallorn
--   poppy       Swamp [13549]        opium
--   wrangler    Plain [13450]        catch
--   fisher      a roundship on Ocean [13350]   fish
--
-- Every start returns TRUE (ok).
--
-- mallorn, catch and fish have a daily yield chance. econ_harvest rolls it
-- fresh for each unit on each day (#132), so a miss one day says nothing
-- about the next.

local oly = require "oly"

local PEASANT, WORKER, SAILOR = 10, 11, 19	-- items
local STONE = 78
local FISHING, CATCH_HORSE, QUARRY_STONE = 603, 655, 682	-- skills
local HARVEST_LUMBER, HARVEST_YEW = 702, 703
local HARVEST_MALLORN, HARVEST_OPIUM = 705, 706

local GREYFELL = 57081			-- start city 0
local MOUNTAIN, FOREST, YEW_GROVE = 13349, 13451, 62199
local MALLORN_GROVE, SWAMP, PLAIN, OCEAN = 74976, 13549, 13450, 13350

oly.load("./lib")
oly.extract_startlocs()

local function noble(id, faction, handle, name)
	local f = oly.add_player{
		id = id, faction = faction,
		noble = handle, noble_name = name,
		start = "0", full_name = "P Word Here",
		email = string.format("player%d@example.com", id),
	}
	assert(oly.loc(f.noble) == GREYFELL, name .. " must start in Greyfell")
	return f.noble
end

local quarryman = noble(300, "Quarry Guild", "quarryman", "Quarryman One")
local woodcutter = noble(301, "Woodcutters", "woodcutter", "Woodcutter One")
local bowyer = noble(302, "Bowyers", "bowyer", "Bowyer One")
local elf = noble(303, "Mallorn Friends", "elf", "Elf-friend One")
local poppy = noble(304, "Poppy Growers", "poppy", "Poppy One")
local wrangler = noble(305, "Wranglers", "wrangler", "Wrangler One")
local fisher = noble(306, "Fisherfolk", "fisher", "Fisher One")

-- the quarryman makes and trains its own workers from its 25 peasants
oly.know(quarryman, QUARRY_STONE)
oly.poof(quarryman, MOUNTAIN)

oly.know(woodcutter, HARVEST_LUMBER)
oly.additem(woodcutter, WORKER, 2)
oly.poof(woodcutter, FOREST)

oly.know(bowyer, HARVEST_YEW)
oly.additem(bowyer, WORKER, 2)
oly.poof(bowyer, YEW_GROVE)

oly.know(elf, HARVEST_MALLORN)
oly.poof(elf, MALLORN_GROVE)

oly.know(poppy, HARVEST_OPIUM)
oly.poof(poppy, SWAMP)

oly.know(wrangler, CATCH_HORSE)
oly.poof(wrangler, PLAIN)

-- fish are caught from a ship: build one at sea and put the fisher aboard
oly.know(fisher, FISHING)
oly.additem(fisher, SAILOR, 2)
oly.poof(fisher, OCEAN)
local ship = oly.makeloc(fisher, "roundship", "ship")
oly.poof(fisher, ship)

assert(oly.loc(quarryman) == MOUNTAIN, "the quarryman must be on the mountain")
assert(oly.loc(bowyer) == YEW_GROVE, "the bowyer must be in the yew grove")
assert(oly.loc(elf) == MALLORN_GROVE, "the elf-friend must be in the grove")
assert(oly.loc(ship) == OCEAN, "the ship must be at sea")
assert(oly.loc(fisher) == ship, "the fisher must be aboard the ship")
assert(oly.has_item(quarryman, PEASANT), "the quarryman needs peasants")

for _, o in ipairs{ "make " .. WORKER .. " 2", "train " .. WORKER .. " 2",
		"quarry 2", "stone 2", "collect " .. STONE .. " 2" } do
	oly.order(quarryman, o)
end
oly.order(woodcutter, "wood 2")
oly.order(bowyer, "yew 2")
oly.order(elf, "mallorn 1")
oly.order(poppy, "opium 2")
oly.order(wrangler, "catch 1")
oly.order(fisher, "fish 2")

oly.save("./lib")

print(string.format("built production-harvest: quarryman=%d woodcutter=%d "
	.. "bowyer=%d elf=%d poppy=%d wrangler=%d fisher=%d ship=%d",
	quarryman, woodcutter, bowyer, elf, poppy, wrangler, fisher, ship))
