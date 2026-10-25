-- use-forestry.lua -- build the use-forestry scenario (issue #192).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Three factions start in Greyfell (start city 0)
-- and are poofed to where their skills work; each noble knows the forestry
-- school and the skills it uses:
--
--   woodcutter  Forest [13451], 3 wood, 1 iron,   use 701, then use 702 2
--               3 workers
--   bowyer      Yew grove [62199], 2 workers      use 703 2
--   farmer      Poppy field [59084]               use 707
--
-- Every start returns TRUE (ok). make_ram (701) has no start, so v_use
-- hands it to skill_produce, and 14 days on d_use makes a battering ram;
-- the woodcutter then cuts lumber. improve_opium needs Forestry's
-- subskill 705 as well, the skill it is listed under.

local oly = require "oly"

local WORKER, WOOD, IRON = 11, 77, 79	-- items

local FORESTRY, MAKE_RAM, HARVEST_LUMBER = 700, 701, 702	-- skills
local HARVEST_YEW, IMPROVE_OPIUM = 703, 707
local SK_705 = 705			-- improve_opium's parent

local GREYFELL = 57081			-- start city 0
local FOREST, YEW_GROVE, POPPY_FIELD = 13451, 62199, 59084

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

local woodcutter = noble(300, "Woodcutters", "woodcutter", "Woodcutter One")
local bowyer = noble(301, "Bowyers", "bowyer", "Bowyer One")
local farmer = noble(302, "Poppy Growers", "farmer", "Farmer One")

-- a battering ram takes 3 wood and 1 iron, and 3 workers to build it
for _, sk in ipairs{ FORESTRY, MAKE_RAM, HARVEST_LUMBER } do
	oly.know(woodcutter, sk)
end
oly.additem(woodcutter, WOOD, 3)
oly.additem(woodcutter, IRON, 1)
oly.additem(woodcutter, WORKER, 3)
oly.poof(woodcutter, FOREST)

oly.know(bowyer, FORESTRY)
oly.know(bowyer, HARVEST_YEW)
oly.additem(bowyer, WORKER, 2)
oly.poof(bowyer, YEW_GROVE)

for _, sk in ipairs{ FORESTRY, SK_705, IMPROVE_OPIUM } do
	oly.know(farmer, sk)
end
oly.poof(farmer, POPPY_FIELD)

assert(oly.loc(woodcutter) == FOREST, "the woodcutter must be in the forest")
assert(oly.loc(bowyer) == YEW_GROVE, "the bowyer must be in the yew grove")
assert(oly.loc(farmer) == POPPY_FIELD, "the farmer must be in the poppy field")

oly.order(woodcutter, "use " .. MAKE_RAM)
oly.order(woodcutter, "use " .. HARVEST_LUMBER .. " 2")
oly.order(bowyer, "use " .. HARVEST_YEW .. " 2")
oly.order(farmer, "use " .. IMPROVE_OPIUM)

oly.save("./lib")

print(string.format("built use-forestry: woodcutter=%d bowyer=%d farmer=%d",
	woodcutter, bowyer, farmer))
