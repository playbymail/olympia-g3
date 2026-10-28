-- use-art.lua -- build the use-art scenario (issue #204).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Five factions start in Greyfell (start city 0)
-- and are moved to Plain [13450], since magic may not be used in a safe
-- haven. Each noble knows the Artifact construction school and all its
-- skills; each skill known adds one aura, so each has 14. Each starts with
-- 200 gold; the forger and the auramaker keep 25 for upkeep.
--
--   forger      1525 gold, 3 mithril,   use 883 1, use 884 1, use 885 1,
--               mallorn wood, a gate    use 894
--               crystal
--   auramaker   525 gold, a mithril,    use 881 1, use 882 887
--               a blank scroll
--   curator     a palantir, 5 mithril   use 887 P, use 888 P, use 891 P,
--                                       use 892 P
--   curser      a palantir, a blank     use 886 Q, use 889 Q
--               scroll
--   dispeller   a palantir, 5 mithril   use 891 D, use 892 D, use 893 D
--
-- Every start returns TRUE (ok). The forger forges a sword, armor and a
-- bow at one aura each, then a palantir. The auramaker forges an auraculum
-- of one aura and scribes Reveal creator of artifact. The curator learns
-- who made its palantir and where, then cloaks both. The curser is refused
-- a noncreator curse on its palantir (#356) and destroys it. The dispeller cloaks
-- its palantir's creator and region, then dispels both cloaks. The
-- palantirs come from oly.palantir: one forged in the turn has an id minted
-- in the turn.

local oly = require "oly"

local ART = 880						-- the school
local FORGE_AURA, WRITE_ART = 881, 882			-- skills
local FORGE_WEAPON, FORGE_ARMOR, FORGE_BOW = 883, 884, 885
local CURSE, SHOW_CREAT, SHOW_REG, DESTROY = 886, 887, 888, 889
local CLOAK_CREAT, CLOAK_REG, REM_CLOAK = 891, 892, 893
local FORGE_PALANTIR = 894

local GOLD = 1
local MALLORN_WOOD = 70			-- item, forging a bow spends one
local MITHRIL = 82			-- item, forging spends one
local GATE_CRYSTAL = 83			-- item, a palantir needs one
local BLANK_SCROLL = 84			-- item, scribing and destroying need one

local GREYFELL = 57081			-- start city 0, a safe haven
local PLAIN = 13450			-- west of Greyfell's forest, not safe

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
	oly.know(f.noble, ART)
	for sk = FORGE_AURA, FORGE_PALANTIR do
		if sk % 10 ~= 0 then
			oly.know(f.noble, sk)
		end
	end
	oly.poof(f.noble, PLAIN)
	assert(oly.loc(f.noble) == PLAIN, name .. " must be on the plain")
	return f.noble
end

-- forging costs 500 gold each, a sword or armor a mithril and a bow a
-- mallorn wood; the palantir needs a mithril and a gate crystal
local forger = noble(300, "Forgers", "forger", "Forger One")
oly.additem(forger, GOLD, 1325)
oly.additem(forger, MITHRIL, 3)
oly.additem(forger, MALLORN_WOOD, 1)
oly.additem(forger, GATE_CRYSTAL, 1)
-- an auraculum costs 500 gold and a mithril
local auramaker = noble(301, "Auramakers", "auramaker", "Auramaker One")
oly.additem(auramaker, GOLD, 325)
oly.additem(auramaker, MITHRIL, 1)
oly.additem(auramaker, BLANK_SCROLL, 1)
-- cloaking the creator needs 100 gold and 5 mithril in hand
local curator = noble(302, "Curators", "curator", "Curator One")
oly.additem(curator, MITHRIL, 5)
local curated = oly.palantir(curator, "curated")
local curser = noble(303, "Cursers", "curser", "Curser One")
oly.additem(curser, BLANK_SCROLL, 1)
local cursed = oly.palantir(curser, "cursed")
-- cloaking the creator needs 100 gold and 5 mithril in hand
local dispeller = noble(304, "Dispellers", "dispeller", "Dispeller One")
oly.additem(dispeller, MITHRIL, 5)
local dispelled = oly.palantir(dispeller, "dispelled")

oly.order(forger, "use " .. FORGE_WEAPON .. " 1")
oly.order(forger, "use " .. FORGE_ARMOR .. " 1")
oly.order(forger, "use " .. FORGE_BOW .. " 1")
oly.order(forger, "use " .. FORGE_PALANTIR)
oly.order(auramaker, "use " .. FORGE_AURA .. " 1")
oly.order(auramaker, "use " .. WRITE_ART .. " " .. SHOW_CREAT)
oly.order(curator, "use " .. SHOW_CREAT .. " " .. curated)
oly.order(curator, "use " .. SHOW_REG .. " " .. curated)
oly.order(curator, "use " .. CLOAK_CREAT .. " " .. curated)
oly.order(curator, "use " .. CLOAK_REG .. " " .. curated)
oly.order(curser, "use " .. CURSE .. " " .. cursed)
oly.order(curser, "use " .. DESTROY .. " " .. cursed)
oly.order(dispeller, "use " .. CLOAK_CREAT .. " " .. dispelled)
oly.order(dispeller, "use " .. CLOAK_REG .. " " .. dispelled)
oly.order(dispeller, "use " .. REM_CLOAK .. " " .. dispelled)

oly.save("./lib")

print(string.format("built use-art: forger=%d auramaker=%d curator=%d curser=%d dispeller=%d curated=%d cursed=%d dispelled=%d",
	forger, auramaker, curator, curser, dispeller, curated, cursed, dispelled))
