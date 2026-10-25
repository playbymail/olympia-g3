-- use-persuasion-refused.lua -- build the use-persuasion-refused scenario
-- (issue #192).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Two factions start in Greyfell (start city 0).
-- 301 "Absentees" stays there with no orders. The noble of 300 "Bunglers"
-- knows every usable persuasion skill but stands in a tower it built in
-- Greyfell, where no mob may be raised and the absentee is not here, and
-- orders each use:
--
--   use 671 x 100    fail: the absentee is not here
--   use 672 x        fail: the absentee is not here
--   use 673          fail: a mob may not be raised in a tower
--   use 674 x        fail: the absentee is not here
--   use 675 x x      fail: the absentee is not here
--
-- Each start returns FALSE (fail).

local oly = require "oly"

local PERSUASION, BRIBE_NOBLE, PERSUADE_OATH = 670, 671, 672	-- skills
local RAISE_MOB, RALLY_MOB, INCITE_MOB = 673, 674, 675

local GREYFELL = 57081			-- start city 0

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

local bungler = noble(300, "Bunglers", "bungler", "Bungler One")
local absentee = noble(301, "Absentees", "absentee", "Absentee One")

for _, sk in ipairs{ PERSUASION, BRIBE_NOBLE, PERSUADE_OATH,
		RAISE_MOB, RALLY_MOB, INCITE_MOB } do
	oly.know(bungler, sk)
end
local tower = oly.makeloc(bungler, "tower", "tower")
oly.poof(bungler, tower)

assert(oly.loc(tower) == GREYFELL, "the tower must be in Greyfell")
assert(oly.loc(bungler) == tower, "the bungler must be in the tower")
assert(oly.loc(absentee) == GREYFELL, "the absentee must stay in Greyfell")

for _, o in ipairs{
	"use " .. BRIBE_NOBLE .. " " .. absentee .. " 100",
	"use " .. PERSUADE_OATH .. " " .. absentee,
	"use " .. RAISE_MOB,
	"use " .. RALLY_MOB .. " " .. absentee,
	"use " .. INCITE_MOB .. " " .. absentee .. " " .. absentee,
} do
	oly.order(bungler, o)
end

oly.save("./lib")

print(string.format("built use-persuasion-refused: bungler=%d absentee=%d "
	.. "tower=%d", bungler, absentee, tower))
