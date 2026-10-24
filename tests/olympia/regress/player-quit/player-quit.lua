-- player-quit.lua -- build the player-quit scenario (issue #118).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Two factions in Greyfell (start city 0):
--
--   300 "Leavers": the player entity orders `quit`. The faction is dropped
--                  and its noble melts away, but quit's start returns FALSE
--                  ("we don't exist anymore"), so it counts as `fail`; its
--                  `ok` cell is unreachable.
--   301 "Stayers": its noble orders `quit`  (rejected: only a player may
--                  quit), and witnesses the leaver vanish.

local oly = require "oly"

local GREYFELL = 57081			-- start city 0

oly.load("./lib")
oly.extract_startlocs()

local leave = oly.add_player{
	id = 300, faction = "Leavers",
	noble = "leaver", noble_name = "Leaver One",
	start = "0", full_name = "P Word Here", email = "player300@example.com",
}
local stay = oly.add_player{
	id = 301, faction = "Stayers",
	noble = "stayer", noble_name = "Stayer One",
	start = "0", full_name = "P Word Here", email = "player301@example.com",
}

assert(oly.loc(leave.noble) == GREYFELL and oly.loc(stay.noble) == GREYFELL,
	"both nobles must start in Greyfell")

oly.order(leave.player, "quit")
oly.order(stay.noble, "quit")

oly.save("./lib")

print(string.format("built player-quit: leaver=%d stayer=%d",
	leave.noble, stay.noble))
