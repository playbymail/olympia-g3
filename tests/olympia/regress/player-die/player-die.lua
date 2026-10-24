-- player-die.lua -- build the player-die scenario (issue #118).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. One faction, 300 "Doomed", in Greyfell (start
-- city 0): its noble orders `die`  (ok), and the player entity orders `die`
-- too  (rejected: only a noble may die).
--
-- die's start always returns TRUE, so its `fail` cell is unreachable.

local oly = require "oly"

local GREYFELL = 57081			-- start city 0

oly.load("./lib")
oly.extract_startlocs()

local doomed = oly.add_player{
	id = 300, faction = "Doomed",
	noble = "doomed", noble_name = "Doomed One",
	start = "0", full_name = "P Word Here", email = "player300@example.com",
}

assert(oly.loc(doomed.noble) == GREYFELL, "the noble must start in Greyfell")

oly.order(doomed.player, "die")
oly.order(doomed.noble, "die")

oly.save("./lib")

print(string.format("built player-die: doomed=%d", doomed.noble))
