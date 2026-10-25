-- movement-refused.lua -- build the movement-refused scenario (issue #152).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Two factions, each with one noble, moved out of
-- Greyfell (start city 0) by poof. Every move order fails at once (none takes
-- a day), so the whole queue runs on day 1:
--
--   walker (Forest 13451, ocean to the north and east):
--     go (no direction), move nowhere (unknown destination),
--     north, n, east, e (open water), enter nowhere, in nowhere,
--     exit, out (a province has no way out), fly (no direction),
--     fly south (no flying capacity), board Greyfell (not a ship),
--     sail (not on a ship), ferry, unload (not a ship's captain)
--   rover (Plain 13482, ocean to the south and west):
--     s, south, west, w (open water)
--
-- Rejected: every movement verb is c or cr, so the walker's player entity
-- orders each one and check_allow() refuses it.

local oly = require "oly"

local GREYFELL = 57081			-- start city 0
local FOREST = 13451			-- Greyfell's province; N 13351, E 13452 are ocean
local PLAIN = 13482			-- S 13582, W 13481 are ocean

oly.load("./lib")
oly.extract_startlocs()

local walkers = oly.add_player{
	id = 300, faction = "Walkers",
	noble = "walker", noble_name = "Walker One",
	start = "0", full_name = "P Word Here", email = "player300@example.com",
}
local rovers = oly.add_player{
	id = 301, faction = "Rovers",
	noble = "rover", noble_name = "Rover One",
	start = "0", full_name = "P Word Here", email = "player301@example.com",
}
local walker, rover = walkers.noble, rovers.noble

oly.poof(walker, FOREST)
oly.poof(rover, PLAIN)
assert(oly.loc(walker) == FOREST, "the walker must be in the Forest")
assert(oly.loc(rover) == PLAIN, "the rover must be in the Plain")

for _, o in ipairs{
		"go", "move nowhere",
		"north", "n", "east", "e",
		"enter nowhere", "in nowhere", "exit", "out",
		"fly", "fly south",
		"board " .. GREYFELL, "sail", "ferry", "unload" } do
	oly.order(walker, o)
end
for _, o in ipairs{ "s", "south", "west", "w" } do
	oly.order(rover, o)
end

for _, o in ipairs{
		"go south", "move south", "north", "n", "east", "e",
		"s", "south", "west", "w", "enter", "in", "exit", "out",
		"fly south", "board " .. GREYFELL, "ferry", "sail south", "unload" } do
	oly.order(walkers.player, o)
end

oly.save("./lib")

print(string.format("built movement-refused: player=%d walker=%d rover=%d",
	walkers.player, walker, rover))
