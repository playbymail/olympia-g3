-- raze-rebuild.lua -- build the raze-rebuild scenario (issue #246).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. One faction starts in Greyfell (start city 0):
--
--   razer      knows Construction, has 300 workers and 100 stone. It waits
--              two days, builds a tower for one day under its lower
--              unformed id (day 4), razes it (its 327 men are worth 163
--              raze points a day, capped at 100, so it falls on day 5),
--              then builds a second tower for one day under its higher
--              unformed id (day 6).
--
-- The wait keeps the three steps clear of the turn's weather days (1, 3, 9
-- and 26 under this seed): natural weather adds storms, which resets the
-- cache.
--
-- The first build makes the tower the last box added to the T_loc kind
-- chain and the sub_tower_notdone subkind chain, and the raze deletes it.
-- Before the fix, add_next_chain()/add_sub_chain() still cached the deleted
-- tower, so the second tower was linked after it, off both chains: it was
-- left out of lib/loc and written to lib/misc instead.
--
-- Both ids are the faction's unformed ids, named in the orders, so no id
-- minted in the turn is needed.

local oly = require "oly"

local GREYFELL = 57081			-- start city 0

local CONSTRUCTION = 680		-- skill
local WORKER, STONE = 11, 78		-- items

oly.load("./lib")
oly.extract_startlocs()

local razers = oly.add_player{
	id = 300, faction = "Razers",
	noble = "razer", noble_name = "Razer One",
	start = "0", full_name = "P Word Here",
	email = "player300@example.com",
}
local razer = razers.noble
assert(oly.loc(razer) == GREYFELL, "Razer One must start in Greyfell")

local first, second = razers.unformed[1], razers.unformed[2]
assert(first and second, "the razers need two unformed ids")
if first > second then
	first, second = second, first
end

oly.know(razer, CONSTRUCTION)
oly.additem(razer, WORKER, 300)
oly.additem(razer, STONE, 100)

oly.order(razer, "wait time 2")
oly.order(razer, string.format("build tower First 1 %d", first))
oly.order(razer, "raze")
oly.order(razer, string.format("build tower Second 1 %d", second))

oly.save("./lib")

print(string.format("built raze-rebuild: razer=%d first=%d second=%d",
	razer, first, second))
