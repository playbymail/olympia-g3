-- use-checks.lua -- build the use-checks scenario (issue #224).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Three factions start in Greyfell (start city 0).
-- The implicit and checker nobles are moved to Plain [13450], which is not a
-- safe haven; the havener stays in Greyfell, which is.
--
--   implicit  the 10 v_implicit skills   use each one
--             and their schools
--   checker   Combat and Survive fatal   use 99999, use 13450, use 610,
--             wound; Petty thievery      use 611, use 603, use 631,
--             without Stealth;           use 613, use 69, use 1
--             Construct catapult
--   havener   Basic magic and Meditate;  use 801, use O 13449
--             an orb
--
-- The implicit noble's uses reach each skill's start, v_implicit, which
-- always returns FALSE (fail). Every other use fails a shared check in
-- v_use or v_use_item before any start runs (checks):
--
--   99999   not a box                      (invalid)
--   13450   a location, not a skill/item   (invalid)
--   610     a skill school                 (invalid)
--   611     known, but not in use_tbl      (invalid; "Internal error.")
--   603     skill not known
--   631     school not known
--   613     no wood or workers (meets_requirements)
--   69      no elfstone held
--   1       gold has no use key            (invalid)
--   801     magic in a safe haven
--   orb     magic item in a safe haven
--
-- The orb comes from oly.orb.

local oly = require "oly"

local GREYFELL = 57081			-- start city 0, a safe haven
local PLAIN = 13450			-- west of Greyfell's forest, not safe
local FOREST = 13449			-- same region as the plain

-- school, then the v_implicit skills in it
local IMPLICIT = {
	{ 610, 617 },			-- combat: weaponsmith
	{ 630, 635 },			-- stealth: hide_lord
	{ 650, 652, 653 },		-- beast: capture_beasts, use_beasts
	{ 670, 676 },			-- persuasion: train_angry
	{ 690, 695 },			-- alchemy: collect_elem
	{ 700, 704, 706 },		-- forestry: collect_foliage, harvest_opium
	{ 900, 902, 911 },		-- necromancy: summon_ghost, transcend_death
}

oly.load("./lib")
oly.extract_startlocs()

local function noble(id, faction, handle, name, where)
	local f = oly.add_player{
		id = id, faction = faction,
		noble = handle, noble_name = name,
		start = "0", full_name = "P Word Here",
		email = string.format("player%d@example.com", id),
	}
	assert(oly.loc(f.noble) == GREYFELL, name .. " must start in Greyfell")
	if where ~= GREYFELL then
		oly.poof(f.noble, where)
	end
	assert(oly.loc(f.noble) == where, name .. " is not where it should be")
	return f.noble
end

local implicit = noble(300, "Implicits", "implicit", "Implicit One", PLAIN)
local checker = noble(301, "Checkers", "checker", "Checker One", PLAIN)
local havener = noble(302, "Haveners", "havener", "Havener One", GREYFELL)

for _, school in ipairs(IMPLICIT) do
	for _, sk in ipairs(school) do
		oly.know(implicit, sk)
	end
end
for _, school in ipairs(IMPLICIT) do
	for i = 2, #school do
		oly.order(implicit, "use " .. school[i])
	end
end

oly.know(checker, 610)			-- Combat
oly.know(checker, 611)			-- Survive fatal wound, not in use_tbl
oly.know(checker, 613)			-- Construct catapult
oly.know(checker, 631)			-- Petty thievery, without Stealth
for _, what in ipairs{ 99999, PLAIN, 610, 611, 603, 631, 613, 69, 1 } do
	oly.order(checker, "use " .. what)
end

oly.know(havener, 800)			-- Basic magic
oly.know(havener, 801)			-- Meditate
local orb = oly.orb(havener, 3)
oly.order(havener, "use 801")
oly.order(havener, "use " .. orb .. " " .. FOREST)

oly.save("./lib")

print(string.format("built use-checks: implicit=%d checker=%d havener=%d",
	implicit, checker, havener))
