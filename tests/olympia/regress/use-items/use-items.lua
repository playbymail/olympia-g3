-- use-items.lua -- build the use-items scenario (issue #218).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Five factions start in Greyfell (start city 0)
-- and are moved to Plain [13450], since magic items may not be used in a
-- safe haven. The mage and the skullbearer know Basic magic, so they are
-- magicians.
--
--   drinker      sick; a heal and a      use H, use D
--                death potion
--   thrall       a slave potion made     use S
--                by the mage
--   mage         a proj_cast potion,     use P, use Q, use O 13449,
--                a quick_cast potion,    use L 13449
--                an orb, a palantir
--   ringer       the five golden         use R1 .. use R5, use 98,
--                rings, a drum, an       use 69
--                elfstone; a savage
--                band shares the plain
--   skullbearer  the Skull of            use 403
--                Bastrestric
--
-- Every start returns TRUE (ok). The potions, orb and rings come from
-- oly.potion, oly.orb and oly.ring, the palantir from oly.palantir and the
-- skull from oly.relic: one made in the turn would have an id minted in
-- the turn, which no order can name. The drum and the elfstone are plain
-- items.

local oly = require "oly"

local BASIC = 800			-- the Basic magic school
local DRUM = 98				-- item, use key 7
local ELFSTONE = 69			-- item, use key 8
local SKULL = 403			-- the Skull of Bastrestric, use key 15

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

local drinker = noble(300, "Drinkers", "drinker", "Drinker One", false)
local thrall = noble(301, "Thralls", "thrall", "Thrall One", false)
local mage = noble(302, "Mages", "mage", "Mage One", true)
local ringer = noble(303, "Ringers", "ringer", "Ringer One", false)
local skullbearer = noble(304, "Skullbearers", "skullbearer",
	"Skullbearer One", true)

oly.sick(drinker)
local heal = oly.potion(drinker, "heal")
local death = oly.potion(drinker, "death")
local slave = oly.potion(thrall, "slave", mage)
local proj = oly.potion(mage, "proj_cast", FOREST)
local quick = oly.potion(mage, "quick_cast", 2)
local orb = oly.orb(mage, 3)
local palantir = oly.palantir(mage)
local rings = {}
for _, k in ipairs{ "barbarian", "savage", "corpse", "orc", "skeleton" } do
	rings[#rings + 1] = oly.ring(ringer, k)
end
oly.additem(ringer, DRUM, 1)
oly.additem(ringer, ELFSTONE, 1)
local savage = oly.savage(PLAIN, 5)
oly.relic(skullbearer, SKULL)

oly.order(drinker, "use " .. heal)
oly.order(drinker, "use " .. death)
oly.order(thrall, "use " .. slave)
oly.order(mage, "use " .. proj)
oly.order(mage, "use " .. quick)
oly.order(mage, "use " .. orb .. " " .. FOREST)
oly.order(mage, "use " .. palantir .. " " .. FOREST)
for _, r in ipairs(rings) do
	oly.order(ringer, "use " .. r)
end
oly.order(ringer, "use " .. DRUM)
oly.order(ringer, "use " .. ELFSTONE)
oly.order(skullbearer, "use " .. SKULL)

oly.save("./lib")

print(string.format("built use-items: drinker=%d thrall=%d mage=%d ringer=%d skullbearer=%d savage=%d",
	drinker, thrall, mage, ringer, skullbearer, savage))
