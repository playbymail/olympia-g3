-- attitude-set.lua -- build the attitude-set scenario (issue #129).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Two factions start in Greyfell (start city 0, a
-- safe haven, so no hostile attitude can start a fight).
--
--   diplomat  admits the visitor to its stack, then turns hostile to the
--             visitor, defends the visitor's faction, clears its stance to
--             the visitor (default), turns neutral to it, and contacts it
--   visitor   waits a day, then stacks under the diplomat, which the admit
--             allows
--
-- Every start returns TRUE (ok). The final stance is neutral to the visitor
-- and defend to its faction; both print in the diplomats' report.

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
	return f
end

local diplomats = faction(300, "Diplomats", "diplomat", "Diplomat One")
local visitors = faction(301, "Visitors", "visitor", "Visitor One")
local diplomat, visitor = diplomats.noble, visitors.noble

for _, o in ipairs{
		"admit " .. diplomat .. " " .. visitor,
		"hostile " .. visitor,
		"defend " .. visitors.player,
		"default " .. visitor,
		"neutral " .. visitor,
		"contact " .. visitor } do
	oly.order(diplomat, o)
end
oly.order(visitor, "wait time 1")
oly.order(visitor, "stack " .. diplomat)

oly.save("./lib")

print(string.format("built attitude-set: player=%d diplomat=%d visitor=%d",
	diplomats.player, diplomat, visitor))
