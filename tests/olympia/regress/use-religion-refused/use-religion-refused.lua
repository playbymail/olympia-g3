-- use-religion-refused.lua -- build the use-religion-refused scenario
-- (issue #192).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Two factions start in Greyfell (start city 0).
-- 301 "Absentees" stays there with no orders. The noble of 300 "Bunglers"
-- knows every religion skill whose start can fail but is poofed to Plain
-- [13450], which has no graveyard, holds no dead body, and orders each use:
--
--   use 751 1      fail: gold is not a unique item
--   use 752 x      fail: not in a graveyard
--   use 753        ok: the ritual is prepared (3 days)
--   use 753        fail: the ritual is already prepared
--   use 754 x      fail: no body x
--   use 755 x      fail: the absentee is not here
--
-- vision_protect (756) starts with v_vision_protect, which always returns
-- TRUE, so it cannot fail and is not ordered.

local oly = require "oly"

local GOLD = 1				-- item
local RELIGION, REVEAL_VISION, LAST_RITES = 750, 751, 752	-- skills
local PRAY, RESURRECT, REMOVE_BLESS = 753, 754, 755

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

for _, sk in ipairs{ RELIGION, REVEAL_VISION, LAST_RITES, PRAY,
		RESURRECT, REMOVE_BLESS } do
	oly.know(bungler, sk)
end
oly.poof(bungler, PLAIN)

assert(oly.loc(bungler) == PLAIN, "the bungler must be on the plain")
assert(oly.loc(absentee) == GREYFELL, "the absentee must stay in Greyfell")
assert(not oly.has_item(bungler, absentee), "the bungler must hold no body")

for _, o in ipairs{
	"use " .. REVEAL_VISION .. " " .. GOLD,
	"use " .. LAST_RITES .. " " .. absentee,
	"use " .. PRAY, "use " .. PRAY,
	"use " .. RESURRECT .. " " .. absentee,
	"use " .. REMOVE_BLESS .. " " .. absentee,
} do
	oly.order(bungler, o)
end

oly.save("./lib")

print(string.format("built use-religion-refused: bungler=%d absentee=%d",
	bungler, absentee))
