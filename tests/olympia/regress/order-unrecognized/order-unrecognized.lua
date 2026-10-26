-- order-unrecognized.lua -- build the order-unrecognized scenario (issue #248).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Four factions start in Greyfell (start city 0):
--
--   one      noble: frobnicate the widgets / wait time 3
--   two      noble: frobnicate / glorp 5 / wait time 2
--   three    player: frobnicate / realname Third Player Renamed
--   four     noble: wait time 3 (control, no bad order)
--
-- An order that fails to parse sets STATE_ERROR, which no queue holds. Before
-- the fix nothing reported it ("Unrecognized command.") and the orders after
-- it did not run that turn. With it, each bad order is reported and the next
-- order runs.

local oly = require "oly"

local GREYFELL = 57081			-- start city 0

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

local one = faction(300, "One", "one", "One Noble")
local two = faction(301, "Two", "two", "Two Noble")
local three = faction(302, "Three", "three", "Three Noble")
local four = faction(303, "Four", "four", "Four Noble")

oly.order(one, "frobnicate the widgets")
oly.order(one, "wait time 3")

oly.order(two, "frobnicate")
oly.order(two, "glorp 5")
oly.order(two, "wait time 2")

oly.order(302, "frobnicate")
oly.order(302, "realname Third Player Renamed")

oly.order(four, "wait time 3")

oly.save("./lib")

print(string.format("built order-unrecognized: one=%d two=%d three=%d four=%d",
	one, two, three, four))
