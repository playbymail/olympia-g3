-- phase-month-gold.lua -- build the phase-month-gold scenario (issue #234).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. The clock is set so that the turn run is turn 8,
-- when every faction gains a noble point. Four factions start in Greyfell
-- (start city 0):
--
--   absent     Greyfell            joined at turn 6 and sends no orders;
--                                  with auto_quit=2 it is dropped
--   lord       a castle in Greyfell  owns the castle that two garrisons
--                                  are bound to, so it rules two provinces
--                                  and ranks as a lord
--   priest     a temple in Greyfell  knows religion: the temple's offerings
--   (none)     garrisons of 12 soldiers, bound to the lord's castle, in
--              Greyfell's forest [13451] (whose city holds the castle: the
--              tax left goes to the castle) and in Plain [13450] (half of
--              what is left goes to the castle's owner)

local oly = require "oly"

local SOLDIER = 12			-- item
local RELIGION = 750			-- skill

local GREYFELL = 57081			-- start city 0
local FOREST = 13451			-- Greyfell's province
local PLAIN = 13450

oly.load("./lib")
oly.extract_startlocs()

local function faction(id, name, handle, noble_name)
	local f = oly.add_player{
		id = id, faction = name,
		noble = handle, noble_name = noble_name,
		start = "0", full_name = "P Word Here",
		email = string.format("player%d@example.com", id),
	}
	assert(oly.loc(f.noble) == GREYFELL, noble_name .. " must start in Greyfell")
	return f.noble
end

oly.auto_quit(2)
oly.clock(6)
local absent = faction(300, "Absentees", "absent", "Absent One")
oly.clock(7)
local lord = faction(301, "Lords", "lord", "Lord One")
local priest = faction(302, "Priests", "priest", "Priest One")

local castle = oly.makeloc(lord, "castle", "castle")
oly.poof(lord, castle)

local forest_garrison = oly.add_garrison(FOREST, castle, SOLDIER, 12)
local plain_garrison = oly.add_garrison(PLAIN, castle, SOLDIER, 12)

local temple = oly.makeloc(priest, "temple", "temple")
oly.poof(priest, temple)
oly.know(priest, RELIGION)

assert(oly.loc(castle) == GREYFELL, "the castle must be in Greyfell")
assert(oly.loc(lord) == castle, "the lord must own the castle")
assert(oly.loc(priest) == temple, "the priest must own the temple")

oly.save("./lib")

print(string.format("built phase-month-gold: absent=%d lord=%d priest=%d "
	.. "castle=%d temple=%d garrisons=%d,%d", absent, lord, priest, castle,
	temple, forest_garrison, plain_garrison))
