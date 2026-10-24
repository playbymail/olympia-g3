-- move-ship.lua -- rebuild the move-ship scenario as ONE script (issue #120).
--
-- The scripted equivalent of build-scenario.sh (tar + oly -s + Join-g3 files +
-- oly -a + awk the nobles out of lib/fact + piped oly -i + awk the ship out of
-- lib/ship + a second oly -i + hand-written orders). It is run by check-lua.sh
-- against the bare-map fixture and must produce a `lib` whose post-turn output
-- matches the committed EXPECT.sha256 and EXPECT.json byte for byte.
--
-- No id is read back from a save file: the nobles come back from add_player
-- and the ship from makeloc.

local oly = require "oly"

local PEASANT, SAILOR = 10, 19		-- items: peasants (25 per new noble), sailors
local SHIPCRAFT, SAILING = 600, 601	-- skills: Shipcraft, Sailing (needed to sail)
local GREYFELL = 57081			-- start city 0, a port

oly.load("./lib")
oly.extract_startlocs()

-- two factions, both starting in Greyfell
local ferry = oly.add_player{
	id = 300, faction = "Ferry Line",
	noble = "captain", noble_name = "Captain One",
	start = "0", full_name = "P Word Here", email = "player300@example.com",
}
local trav = oly.add_player{
	id = 301, faction = "Travellers",
	noble = "passenger", noble_name = "Passenger One",
	start = "0", full_name = "P Word Here", email = "player301@example.com",
}
local cap, pas = ferry.noble, trav.noble

-- build-scenario.sh runs the next steps in a new olympia-g3 -i process, so
-- the ship's id is that process's first mint. oly.restart() reproduces the
-- process boundary (and the one below), keeping the output byte-identical.
oly.restart()

-- crew the captain and build the roundship where the captain stands
oly.know(cap, SHIPCRAFT)
oly.know(cap, SAILING)
oly.subitem(cap, PEASANT, 25)
oly.additem(cap, SAILOR, 8)
local ship = oly.makeloc(cap, "roundship", "ship")
oly.subitem(pas, PEASANT, 25)
oly.save("./lib")
oly.restart()

-- the first character inside a ship is its captain
oly.poof(cap, ship)

assert(oly.loc(ship) == GREYFELL, "the ship must be built in Greyfell")
assert(oly.loc(cap) == ship, "the captain must be aboard the ship")
assert(oly.loc(pas) == GREYFELL, "the passenger must be on the dock")
assert(oly.has_item(cap, SAILOR), "the captain has no crew")
assert(not oly.has_item(cap, PEASANT) and not oly.has_item(pas, PEASANT),
	"peasants must be removed")

for _, o in ipairs{ "fee 1", "ferry", "wait time 1", "sail east",
		"sail west", "unload" } do
	oly.order(cap, o)
end
oly.order(pas, "wait ferry " .. ship)
oly.order(pas, "board " .. ship)

oly.save("./lib")

print(string.format("built move-ship: captain=%d passenger=%d ship=%d",
	cap, pas, ship))
