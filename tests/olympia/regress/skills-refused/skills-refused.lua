-- skills-refused.lua -- build the skills-refused scenario (issue #144).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Three factions start in Greyfell (start city 0):
--
--   dunce      knows Combat. study fails with no skill, on gold (not a
--              skill), on a Stealth subskill (unknown parent), on Combat
--              (already known) and on Weather magic (not taught here);
--              then studies Forestry for 14 days, and a third
--              study fails at the monthly cap. research fails with no skill,
--              on gold, on Shipcraft (not known) and on Combat outside a
--              tower. forget fails on gold and Shipcraft (not known). use
--              fails on Combat (a school) and Survive fatal wound (not known).
--   hermit     owns a tower with no gold, knows Combat and Forestry:
--              research fails on Combat (nothing to research) and Forestry
--              (cannot pay 25 gold)
--   lodger     knows Forestry, inside the hermit's tower but not first:
--              research fails
--
-- Rejected: every skills verb is for nobles (c), so the player entity's
-- study, research, forget and use are refused.

local oly = require "oly"

local GOLD = 1				-- item

local GREYFELL = 57081			-- start city 0

local SHIPCRAFT = 600			-- skills
local COMBAT = 610
local SURVIVE = 611			-- Combat's subskill
local PETTY_THIEF = 631		-- Stealth's subskill
local FORESTRY = 700
local WEATHER = 820			-- a school Greyfell does not teach

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

local dunces = faction(300, "Dunces", "dunce", "Dunce One")
local hermits = faction(301, "Hermits", "hermit", "Hermit One")
local lodgers = faction(302, "Lodgers", "lodger", "Lodger One")
local dunce, hermit, lodger = dunces.noble, hermits.noble, lodgers.noble

oly.know(dunce, COMBAT)
oly.know(hermit, COMBAT)
oly.know(hermit, FORESTRY)
oly.know(lodger, FORESTRY)

-- the first character inside a building is its owner
local tower = oly.makeloc(hermit, "tower", "tower")
oly.poof(hermit, tower)
oly.poof(lodger, tower)
assert(oly.loc(hermit) == tower and oly.loc(lodger) == tower,
	"the hermit and lodger must be in the tower")
oly.subitem(hermit, GOLD, 200)		-- all of a starting noble's gold
assert(not oly.has_item(hermit, GOLD), "the hermit must have no gold")

for _, o in ipairs{
		"study", "study " .. GOLD, "study " .. PETTY_THIEF,
		"study " .. COMBAT, "study " .. WEATHER,
		"research", "research " .. GOLD, "research " .. SHIPCRAFT,
		"research " .. COMBAT,
		"forget " .. GOLD, "forget " .. SHIPCRAFT,
		"use " .. COMBAT, "use " .. SURVIVE,
		"study " .. FORESTRY, "study " .. FORESTRY, "study " .. FORESTRY } do
	oly.order(dunce, o)
end
oly.order(hermit, "research " .. COMBAT)
oly.order(hermit, "research " .. FORESTRY)
oly.order(lodger, "research " .. FORESTRY)
for _, o in ipairs{
		"study " .. COMBAT, "research " .. COMBAT, "forget " .. COMBAT,
		"use " .. SURVIVE } do
	oly.order(dunces.player, o)
end

oly.save("./lib")

print(string.format("built skills-refused: player=%d dunce=%d hermit=%d "
	.. "lodger=%d tower=%d", dunces.player, dunce, hermit, lodger, tower))
