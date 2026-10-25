-- use-sorcery.lua -- build the use-sorcery scenario (issue #216).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Two factions start in Greyfell (start city 0).
-- Magic may not be used in a safe haven, so the trancer is moved to Forest
-- [13449] and the teleporter to Plain [13450], two provinces of the same
-- region. Each knows the Advanced sorcery school; each skill known adds one
-- aura. Each starts with 200 gold.
--
--   trancer     sick, knows Trance                use 921
--   teleporter  3 aura, knows Trance and          use 922 trancer 1 50
--               Teleport item
--
-- Both uses succeed (ok). The trancer is made sick so that its trance heals
-- it when it finishes on day 28. The teleporter spends all 3 of its aura
-- (gold weighs nothing) to send 50 gold to the trancer, which a character
-- always accepts.

local oly = require "oly"

local ADV = 920				-- the school
local TRANCE, TELEPORT_ITEM = 921, 922	-- skills

local GOLD = 1				-- item

local GREYFELL = 57081			-- start city 0, a safe haven
local FOREST = 13449			-- not safe, region 58762
local PLAIN = 13450			-- not safe, region 58762

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
	oly.know(f.noble, ADV)
	for _, sk in ipairs(skills) do
		oly.know(f.noble, sk)
	end
	oly.poof(f.noble, where)
	assert(oly.loc(f.noble) == where, name .. " must be moved")
	return f.noble
end

local trancer = noble(300, "Trancers", "trancer", "Trancer One", FOREST,
	{ TRANCE })
oly.sick(trancer)
local teleporter = noble(301, "Teleporters", "teleporter", "Teleporter One",
	PLAIN, { TRANCE, TELEPORT_ITEM })

oly.order(trancer, "use " .. TRANCE)
oly.order(teleporter, "use " .. TELEPORT_ITEM .. " " .. trancer .. " "
	.. GOLD .. " 50")

oly.save("./lib")

print(string.format("built use-sorcery: trancer=%d teleporter=%d",
	trancer, teleporter))
