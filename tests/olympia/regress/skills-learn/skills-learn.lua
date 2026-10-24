-- skills-learn.lua -- build the skills-learn scenario (issue #144).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Three factions start in Greyfell (start city 0),
-- which teaches Shipcraft, Combat, Construction, Forestry, Trade, Magic and
-- Gatecraft:
--
--   scholar    studies Combat, a school Greyfell teaches, for two 7-day
--              orders (it pays the 100 gold tuition once)
--   forester   knows Forestry and owns a tower: researches Forestry (25
--              gold and a skills-stream draw), then studies Construct
--              battering ram, which Forestry offers
--   forgetter  knows Magic, Meditate and Combat: forgets Magic, which
--              refunds its NP and forgets Meditate with it, then Combat
--
-- Every start returns TRUE (ok).

local oly = require "oly"

local GREYFELL = 57081			-- start city 0

local COMBAT = 610			-- skills
local FORESTRY = 700
local BATTERING_RAM = 701		-- offered by Forestry
local MAGIC = 800
local MEDITATE = 801

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

local scholars = faction(300, "Scholars", "scholar", "Scholar One")
local foresters = faction(301, "Foresters", "forester", "Forester One")
local forgetters = faction(302, "Forgetters", "forgetter", "Forgetter One")
local scholar, forester = scholars.noble, foresters.noble
local forgetter = forgetters.noble

oly.know(forester, FORESTRY)

-- the first character inside a building is its owner
local tower = oly.makeloc(forester, "tower", "tower")
oly.poof(forester, tower)
assert(oly.loc(tower) == GREYFELL, "the tower must be in Greyfell")
assert(oly.loc(forester) == tower, "the forester must own the tower")

for _, sk in ipairs{ MAGIC, MEDITATE, COMBAT } do
	oly.know(forgetter, sk)
end

oly.order(scholar, "study " .. COMBAT)
oly.order(scholar, "study " .. COMBAT)
oly.order(forester, "research " .. FORESTRY)
oly.order(forester, "study " .. BATTERING_RAM)
oly.order(forgetter, "forget " .. MAGIC)
oly.order(forgetter, "forget " .. COMBAT)

oly.save("./lib")

print(string.format("built skills-learn: scholar=%d forester=%d "
	.. "forgetter=%d tower=%d", scholar, forester, forgetter, tower))
