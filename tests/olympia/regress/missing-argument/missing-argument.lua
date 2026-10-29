-- missing-argument.lua -- build the missing-argument scenario (issue #366).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Each unit's parse vector keeps its slots from
-- one order to the next: a slot an earlier, longer order filled points into
-- that order's freed line, and one no order filled is NULL. These orders
-- used to read such a slot. Five factions start in Greyfell (start city 0):
--
--   raider     Plain [13450]     a longer order, then attack (a freed slot)
--   fumbler    Plain [13450]     use, its only order
--   dabbler    Plain [13450]     a longer order, then use
--   fogger     Forest [13550],   a longer order, then use 826: an
--              the Weather       unnamed fog, which used to take its name
--              school            from the freed slot 2
--   striker    Plain [13450]     attack, its only order, on a NULL slot 1:
--                                the turn used to crash
--
-- The longer order is a promote of an unseen unit, which fails at once
-- and fills slots 1-4.
--
-- A unit's command line is saved with the DB (the CO section's li) and
-- parsed again at load, which fills the slots too. This script's commands
-- leave each noble the last one it ran as that noble: "be <next noble>" for
-- all but the last, which keeps "save" (oly.save), a single word. So the
-- striker is made last: it is the one whose slot 1 is NULL.

local oly = require "oly"

local WEATHER = 820			-- the school
local FOG = 826				-- Summon fog
local WEATHER_SKILLS = { WEATHER, 821, 822, 823, 824, FOG }	-- 6 aura

local GREYFELL = 57081			-- start city 0, a safe haven
local PLAIN = 13450			-- not safe
local FOREST = 13550			-- not safe; fog cookies

local LONGER = "promote 9999 aaaa bbbb cccc"

oly.load("./lib")
oly.extract_startlocs()

local function noble(id, faction, handle, name, where, skills)
	local f = oly.add_player{
		id = id, faction = faction,
		noble = handle, noble_name = name,
		start = "0", full_name = "P Word Here",
		email = string.format("player%d@example.com", id),
	}
	assert(oly.loc(f.noble) == GREYFELL, name .. " must start in Greyfell")
	for _, sk in ipairs(skills) do
		oly.know(f.noble, sk)
	end
	oly.poof(f.noble, where)
	assert(oly.loc(f.noble) == where, name .. " must be moved")
	return f.noble
end

local raider = noble(300, "Raiders", "raider", "Raider One", PLAIN, {})
local fumbler = noble(301, "Fumblers", "fumbler", "Fumbler One", PLAIN, {})
local dabbler = noble(302, "Dabblers", "dabbler", "Dabbler One", PLAIN, {})
local fogger = noble(303, "Foggers", "fogger", "Fogger One", FOREST,
	WEATHER_SKILLS)
local striker = noble(304, "Strikers", "striker", "Striker One", PLAIN, {})

oly.order(raider, LONGER)
oly.order(raider, "attack")
oly.order(fumbler, "use")
oly.order(dabbler, LONGER)
oly.order(dabbler, "use")
oly.order(fogger, LONGER)
oly.order(fogger, "use " .. FOG)
oly.order(striker, "attack")

oly.save("./lib")

print(string.format("built missing-argument: raider=%d fumbler=%d "
	.. "dabbler=%d fogger=%d striker=%d",
	raider, fumbler, dabbler, fogger, striker))
