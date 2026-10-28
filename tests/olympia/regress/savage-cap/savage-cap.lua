-- savage-cap.lua -- build the savage-cap scenario (issue #354).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. One faction starts in Greyfell (start city 0):
--
--   builder    Plain [13450]       raises TOWERS towers, so that more than
--                                  one of them draws a savage spawn
--
-- and 199 bands of savages wait in the forest [13449] (oly.savage), one
-- short of MAX_SAVAGES (200). init_savage_attacks counts them on day 0,
-- then visits each fort: one that draws its keyed 1-in-100 roll calls
-- savages to attack it. Before the fix for #354 only the count before the
-- loop was checked, so every fort that drew the roll spawned a band. Now
-- each spawn counts, and the first one reaches the cap.

local oly = require "oly"

local GREYFELL = 57081			-- start city 0
local PLAIN, FOREST = 13450, 13449
local SAVAGES = 199			-- MAX_SAVAGES - 1
local TOWERS = 300			-- three of them draw a spawn on turn 1

oly.load("./lib")
oly.extract_startlocs()

local builders = oly.add_player{
	id = 300, faction = "Builders",
	noble = "builder", noble_name = "Builder One",
	start = "0", full_name = "P Word Here",
	email = "player300@example.com",
}
local builder = builders.noble
assert(oly.loc(builder) == GREYFELL, "Builder One must start in Greyfell")

for i = 1, SAVAGES do
	oly.savage(FOREST, 1)
end

oly.poof(builder, PLAIN)
local last
for i = 1, TOWERS do
	last = oly.makeloc(builder, "tower")
	assert(oly.loc(last) == PLAIN, "the tower must be in the plain")
end

oly.save("./lib")

print(string.format("built savage-cap: builders=%d builder=%d towers=%d "
	.. "last tower=%d", builders.player, builder, TOWERS, last))
