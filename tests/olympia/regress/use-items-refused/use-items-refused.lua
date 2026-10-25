-- use-items-refused.lua -- build the use-items-refused scenario (issue #218).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Two factions start in Greyfell (start city 0)
-- and are moved to Plain [13450], since magic items may not be used in a
-- safe haven. The seer knows Basic magic, so it is a magician; the dabbler
-- is not.
--
--   dabbler   a proj_cast and a         use P, use Q
--             quick_cast potion
--   seer      a palantir, an orb        use L <seer>, use O 13449,
--                                       use O 13449
--
-- Each start below returns FALSE (fail), except the seer's first orb use:
-- the dabbler is no magician, so both potions do nothing and are spent; the
-- seer names itself, not a location, to the palantir; an orb may be used
-- only once a month, so its second use fails. The potions, palantir and orb
-- come from oly.potion, oly.palantir and oly.orb.

local oly = require "oly"

local BASIC = 800			-- the Basic magic school

local GREYFELL = 57081			-- start city 0, a safe haven
local PLAIN = 13450			-- west of Greyfell's forest, not safe
local FOREST = 13449			-- same region as the plain

oly.load("./lib")
oly.extract_startlocs()

local function noble(id, faction, handle, name, magician)
	local f = oly.add_player{
		id = id, faction = faction,
		noble = handle, noble_name = name,
		start = "0", full_name = "P Word Here",
		email = string.format("player%d@example.com", id),
	}
	assert(oly.loc(f.noble) == GREYFELL, name .. " must start in Greyfell")
	if magician then
		oly.know(f.noble, BASIC)
	end
	oly.poof(f.noble, PLAIN)
	assert(oly.loc(f.noble) == PLAIN, name .. " must be on the plain")
	return f.noble
end

local dabbler = noble(300, "Dabblers", "dabbler", "Dabbler One", false)
local seer = noble(301, "Seers", "seer", "Seer One", true)

local proj = oly.potion(dabbler, "proj_cast", FOREST)
local quick = oly.potion(dabbler, "quick_cast", 2)
local palantir = oly.palantir(seer)
local orb = oly.orb(seer, 3)

oly.order(dabbler, "use " .. proj)
oly.order(dabbler, "use " .. quick)
oly.order(seer, "use " .. palantir .. " " .. seer)
oly.order(seer, "use " .. orb .. " " .. FOREST)
oly.order(seer, "use " .. orb .. " " .. FOREST)

oly.save("./lib")

print(string.format("built use-items-refused: dabbler=%d seer=%d",
	dabbler, seer))
