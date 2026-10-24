-- player-press.lua -- build the player-press scenario (issue #118).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Two factions in Greyfell (start city 0). The
-- crier writes to the Times and to the listener, once to succeed and again
-- with text that is rejected:
--
--   crier:  press, rumor (the Times), post (in Greyfell), message (to the
--           listener)  (ok)
--           press and rumor with a line over 78 characters, post with one
--           over 60, message to Greyfell (not a character)  (fail)
--   player: times (opt out of the Times)  (ok)
--
-- The text lines after each verb are popped from the crier's queue by the
-- verb itself; `0` reads up to `end`, a number reads that many lines.

local oly = require "oly"

local GREYFELL = 57081			-- start city 0

oly.load("./lib")
oly.extract_startlocs()

local town = oly.add_player{
	id = 300, faction = "Town Crier",
	noble = "crier", noble_name = "Crier One",
	start = "0", full_name = "P Word Here", email = "player300@example.com",
}
local lsn = oly.add_player{
	id = 301, faction = "Listeners",
	noble = "listener", noble_name = "Listener One",
	start = "0", full_name = "P Word Here", email = "player301@example.com",
}
local crier, listener = town.noble, lsn.noble

assert(oly.loc(crier) == GREYFELL and oly.loc(listener) == GREYFELL,
	"both nobles must start in Greyfell")

local long79 = string.rep("p", 79)
local long61 = string.rep("q", 61)

for _, o in ipairs{
		"press 0", "Hear ye, hear ye: the Crier speaks.",
			"=-=- a line that looks like a rule", "end",
		"press 1", long79,
		"rumor 2", "They say the Listeners never sleep.",
			"Others say otherwise.",
		"rumor 1", long79,
		"post 0", "Welcome to Greyfell.", "end",
		"post 1", long61,
		"message 1 " .. listener, "Meet me at the docks.",
		"message 1 " .. GREYFELL, "Nobody will read this." } do
	oly.order(crier, o)
end
oly.order(town.player, "times 1")

oly.save("./lib")

print(string.format("built player-press: crier=%d listener=%d",
	crier, listener))
