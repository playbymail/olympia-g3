-- use-scry-refused.lua -- build the use-scry-refused scenario (issue #196).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Two factions start in Greyfell (start city 0)
-- and are moved to Plain [13450], since magic may not be used in a safe
-- haven. Each noble knows the Scrying school and the skills it uses; each
-- skill known adds one aura:
--
--   bungler   7 aura, a blank   use 841 <bungler> 1, use 842 801,
--             scroll            use 846 0 1, use 847 13450, use 849 13451,
--                               use 851
--   pauper    5 aura            use 843 99, use 845 8, use 843 5,
--                               use 844 13450, use 848
--
-- Every start but one fails. The bungler scries itself, which is not a
-- location, scribes Meditate, which it does not know, unbars the plain,
-- which has no barrier, locates the plain, which is not a character,
-- projects its next cast to Greyfell's forest, a safe haven, and saves a
-- projected cast it never made. The pauper asks for a shroud and a
-- barrier dearer than its aura, then spends all five on a shroud (that
-- one starts), and the dispel and detection after it need aura it no
-- longer has. banish_corpses always starts, so it has no fail cell.

local oly = require "oly"

local SCRY = 840					-- the school
local SCRY_REGION, WRITE, SHROUD, DISPEL = 841, 842, 843, 844	-- skills
local BAR, UNBAR, LOCATE, DETECT = 845, 846, 847, 848
local PROJECT, SAVE_PROJ = 849, 851
local MEDITATE = 801			-- a spell the bungler does not know

local BLANK_SCROLL = 84			-- item, scribing needs one

local GREYFELL = 57081			-- start city 0, a safe haven
local SAFE = 13451			-- Greyfell's forest, a safe haven
local PLAIN = 13450			-- west of Greyfell's forest, not safe

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

-- the scroll gets the scribe past meets_requirements, to its start
local bungler = noble(300, "Bunglers", "bungler", "Bungler One",
	{ SCRY_REGION, WRITE, UNBAR, LOCATE, PROJECT, SAVE_PROJ })
oly.additem(bungler, BLANK_SCROLL, 1)
local pauper = noble(301, "Paupers", "pauper", "Pauper One",
	{ SHROUD, DISPEL, BAR, DETECT })

oly.order(bungler, "use " .. SCRY_REGION .. " " .. bungler .. " 1")
oly.order(bungler, "use " .. WRITE .. " " .. MEDITATE)
oly.order(bungler, "use " .. UNBAR .. " 0 1")
oly.order(bungler, "use " .. LOCATE .. " " .. PLAIN)
oly.order(bungler, "use " .. PROJECT .. " " .. SAFE)
oly.order(bungler, "use " .. SAVE_PROJ)
oly.order(pauper, "use " .. SHROUD .. " 99")
oly.order(pauper, "use " .. BAR .. " 8")
oly.order(pauper, "use " .. SHROUD .. " 5")
oly.order(pauper, "use " .. DISPEL .. " " .. PLAIN)
oly.order(pauper, "use " .. DETECT)

oly.save("./lib")

print(string.format("built use-scry-refused: bungler=%d pauper=%d",
	bungler, pauper))
