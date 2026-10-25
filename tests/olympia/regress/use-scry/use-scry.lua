-- use-scry.lua -- build the use-scry scenario (issue #196).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Three factions start in Greyfell (start city 0)
-- and are moved to Plain [13450], since magic may not be used in a safe
-- haven. Each noble knows the Scrying school and the skills it uses; each
-- skill known adds one aura:
--
--   barrier     5 aura, a blank   use 845 1, use 846 0 1,
--               scroll            use 841 13550 1, use 842 841
--   shrouder    7 aura            use 843 1, use 844 13450,
--                                 use 847 <barrier> 1, use 848
--   projector   6 aura            use 849 13550, use 851, use 852
--
-- Every start returns TRUE (ok). The barrier mage bars the plain and then
-- tries to unbar it, scries Forest [13550], to the south, and scribes Scry
-- location. The shrouder shrouds the plain, dispels the shroud, locates the
-- barrier mage and practices location scry detection. The projector
-- projects its next cast to the forest, saves that state in a potion and
-- banishes the undead here (there are none).

local oly = require "oly"

local SCRY = 840					-- the school
local SCRY_REGION, WRITE, SHROUD, DISPEL = 841, 842, 843, 844	-- skills
local BAR, UNBAR, LOCATE, DETECT = 845, 846, 847, 848
local PROJECT, SAVE_PROJ, BANISH = 849, 851, 852

local BLANK_SCROLL = 84			-- item, scribing needs one

local GREYFELL = 57081			-- start city 0, a safe haven
local PLAIN = 13450			-- west of Greyfell's forest, not safe
local FOREST = 13550			-- south of the plain, not safe

oly.load("./lib")
oly.extract_startlocs()

local function noble(id, faction, handle, name, skills)
	local f = oly.add_player{
		id = id, faction = faction,
		noble = handle, noble_name = name,
		start = "0", full_name = "P Word Here",
		email = string.format("player%d@example.com", id),
	}
	assert(oly.loc(f.noble) == GREYFELL, name .. " must start in Greyfell")
	oly.know(f.noble, SCRY)
	for _, sk in ipairs(skills) do
		oly.know(f.noble, sk)
	end
	oly.poof(f.noble, PLAIN)
	assert(oly.loc(f.noble) == PLAIN, name .. " must be on the plain")
	return f.noble
end

-- the barrier mage scribes Scry location onto a blank scroll
local barrier = noble(300, "Barriers", "barrier", "Barrier One",
	{ SCRY_REGION, WRITE, BAR, UNBAR })
oly.additem(barrier, BLANK_SCROLL, 1)
-- dispelling costs three aura; the extra skills pay for the rest
local shrouder = noble(301, "Shrouders", "shrouder", "Shrouder One",
	{ SHROUD, DISPEL, LOCATE, DETECT, SCRY_REGION, WRITE })
-- projecting to the next province costs two, saving the state three
local projector = noble(302, "Projectors", "projector", "Projector One",
	{ PROJECT, SAVE_PROJ, BANISH, SCRY_REGION, BAR })

oly.order(barrier, "use " .. BAR .. " 1")
oly.order(barrier, "use " .. UNBAR .. " 0 1")
oly.order(barrier, "use " .. SCRY_REGION .. " " .. FOREST .. " 1")
oly.order(barrier, "use " .. WRITE .. " " .. SCRY_REGION)
oly.order(shrouder, "use " .. SHROUD .. " 1")
oly.order(shrouder, "use " .. DISPEL .. " " .. PLAIN)
oly.order(shrouder, "use " .. LOCATE .. " " .. barrier .. " 1")
oly.order(shrouder, "use " .. DETECT)
oly.order(projector, "use " .. PROJECT .. " " .. FOREST)
oly.order(projector, "use " .. SAVE_PROJ)
oly.order(projector, "use " .. BANISH)

oly.save("./lib")

print(string.format("built use-scry: barrier=%d shrouder=%d projector=%d",
	barrier, shrouder, projector))
