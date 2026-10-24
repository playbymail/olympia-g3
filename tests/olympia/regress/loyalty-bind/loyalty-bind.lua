-- loyalty-bind.lua -- build the loyalty-bind scenario (issue #143).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Two factions start in Greyfell (start city 0):
--
--   vassal     pledges its lands to the lord, forms a hireling, gives it
--              gold, and clears the pledge with pledge 0
--   hireling   contract-500 once formed (starting nobles are already
--              oath-2, so honor and oath would fail on them): honors itself
--              with 50 gold, then honours itself with 25 more, to
--              contract-575, then takes oath 1 (oath-1) and oath 2, which
--              from oath-1 costs one NP for oath-2
--   lord       the pledge target; no orders
--
-- Every start returns TRUE (ok). The hireling's orders are queued before
-- it exists; they run once the vassal's 7-day form makes it, on day 8,
-- after the vassal's give.

local oly = require "oly"

local GOLD = 1				-- item

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
	return f
end

local vassals = faction(300, "Vassals", "vassal", "Vassal One")
local lords = faction(301, "Lords", "lord", "Lord One")
local vassal, lord = vassals.noble, lords.noble

-- the noble the vassal's form makes; its orders are queued here
local hireling = vassals.unformed[1]
assert(hireling, "the vassals need an unformed noble")

for _, o in ipairs{
		"pledge " .. lord,
		"form " .. hireling .. " Hireling",
		"give " .. hireling .. " " .. GOLD .. " 100",
		"pledge 0" } do
	oly.order(vassal, o)
end
for _, o in ipairs{ "honor 50", "honour 25", "oath 1", "oath 2" } do
	oly.order(hireling, o)
end

oly.save("./lib")

print(string.format("built loyalty-bind: player=%d vassal=%d hireling=%d "
	.. "lord=%d", vassals.player, vassal, hireling, lord))
