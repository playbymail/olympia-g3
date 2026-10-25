-- use-stealth-refused.lua -- build the use-stealth-refused scenario
-- (issue #192).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Two factions start in Greyfell (start city 0).
-- 301 "Absentees" stays there with no orders. The noble of 300 "Bunglers"
-- knows every usable stealth skill but is poofed to Plain [13450], which
-- has no city or inn, still leading its 25 peasants, and orders each use:
--
--   use 631          fail: not in a city
--   use 632..634 x   fail: the absentee is not here
--   use 636          fail: not in an inn
--   use 637 x        fail: the absentee is not a prisoner
--   use 638 1        fail: not alone (the peasants count)
--   use 639          fail: not alone
--
-- Each start returns FALSE (fail).

local oly = require "oly"

local STEALTH, PETTY_THIEF = 630, 631	-- skills
local SPY_INV, SPY_SKILLS, SPY_LORD = 632, 633, 634
local FIND_RICH, TORTURE, HIDE_SELF, SNEAK_BUILD = 636, 637, 638, 639

local GREYFELL = 57081			-- start city 0
local PLAIN = 13450

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

for _, sk in ipairs{ STEALTH, PETTY_THIEF, SPY_INV, SPY_SKILLS, SPY_LORD,
		FIND_RICH, TORTURE, HIDE_SELF, SNEAK_BUILD } do
	oly.know(bungler, sk)
end
oly.poof(bungler, PLAIN)

assert(oly.loc(bungler) == PLAIN, "the bungler must be on the plain")
assert(oly.loc(absentee) == GREYFELL, "the absentee must stay in Greyfell")

oly.order(bungler, "use " .. PETTY_THIEF)
for _, sk in ipairs{ SPY_INV, SPY_SKILLS, SPY_LORD } do
	oly.order(bungler, "use " .. sk .. " " .. absentee)
end
for _, o in ipairs{
	"use " .. FIND_RICH, "use " .. TORTURE .. " " .. absentee,
	"use " .. HIDE_SELF .. " 1", "use " .. SNEAK_BUILD,
} do
	oly.order(bungler, o)
end

oly.save("./lib")

print(string.format("built use-stealth-refused: bungler=%d absentee=%d",
	bungler, absentee))
