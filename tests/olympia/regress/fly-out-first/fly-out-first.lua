-- fly-out-first.lua -- build the fly-out-first scenario (issue #265).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Three factions start in Greyfell (start city 0),
-- inside the Forest [13451]. The Plain [13450] lies west of the Forest;
-- Greyfell itself has no exit west. Each noble trades its 25 peasants for a
-- winged horse, so it can fly (the peasants would overload it):
--
--   one      noble: fly 13450          (destination id)
--   two      noble: fly west           (direction, control)
--   three    noble: fly nowhere bs50   (bad argument, then destination code)
--
-- No argument works from inside Greyfell, so v_fly asks whether the last one
-- works from the Forest and, if it does, flies out first. Before the fix that
-- check saw the argument's word but not its parsed id (cmd_shift had already
-- set c->a to 0), so a destination never passed it: one and three stayed in
-- Greyfell. With the fix all three fly out, then west to the Plain.

local oly = require "oly"

local GREYFELL = 57081			-- start city 0, in the Forest 13451
local PEASANT = 10			-- item_peasant
local WINGED_HORSE = 54			-- item_pegasus, "winged horse", fly 150

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
	oly.subitem(f.noble, PEASANT, 25)
	oly.additem(f.noble, WINGED_HORSE, 1)
	return f.noble
end

local one = faction(300, "One", "one", "One Noble")
local two = faction(301, "Two", "two", "Two Noble")
local three = faction(302, "Three", "three", "Three Noble")

oly.order(one, "fly 13450")
oly.order(two, "fly west")
oly.order(three, "fly nowhere bs50")

oly.save("./lib")

print(string.format("built fly-out-first: one=%d two=%d three=%d",
	one, two, three))
