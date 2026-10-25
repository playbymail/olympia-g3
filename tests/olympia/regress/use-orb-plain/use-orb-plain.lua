-- use-orb-plain.lua -- build the use-orb-plain scenario (issue #221).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. One faction starts in Greyfell (start city 0)
-- and is moved to Plain [13450], since magic items may not be used in a
-- safe haven.
--
--   seer      two plain crystal orbs    wait time 2, use 290 13449
--             (item 290)
--
-- Item 290 is not unique, so it has no use count. The orb shows the forest,
-- shatters, and one of the two is spent. Before #221 the shatter called
-- destroy_unique_item, which asserted. The wait moves the use to day 2,
-- past the 1-in-3 murky roll that returns before the shatter.

local oly = require "oly"

local GREYFELL = 57081			-- start city 0, a safe haven
local PLAIN = 13450			-- west of Greyfell's forest, not safe
local FOREST = 13449			-- same region as the plain
local ORB = 290				-- the plain crystal orb

oly.load("./lib")
oly.extract_startlocs()

local f = oly.add_player{
	id = 300, faction = "Seers",
	noble = "seer", noble_name = "Seer One",
	start = "0", full_name = "P Word Here",
	email = "player300@example.com",
}
local seer = f.noble
assert(oly.loc(seer) == GREYFELL, "Seer One must start in Greyfell")
oly.poof(seer, PLAIN)
assert(oly.loc(seer) == PLAIN, "Seer One must be on the plain")

oly.additem(seer, ORB, 2)

oly.order(seer, "wait time 2")
oly.order(seer, "use " .. ORB .. " " .. FOREST)

oly.save("./lib")

print(string.format("built use-orb-plain: seer=%d", seer))
