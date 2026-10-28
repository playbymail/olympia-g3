-- token-vanish.lua -- build the token-vanish scenario (issue #355).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. One faction starts in Greyfell (start city 0):
--
--   holder   Holder One   holds an NPC token, the Horn of the Savages
--                         (oly.token). oly.token_units adds its one unit,
--                         a band of savages, before the turn, and the band
--                         is put on deep ocean [10100] with no ship.
--
-- After 15 days in the air the band plunges into the sea and dies. The
-- token's last unit is gone, so kill_char destroys the token and tells its
-- holder that it vanishes. Before the fix for #355 the test was
-- player(who_has) == sub_pl_regular, a faction id against a subkind, which
-- faction 300 never passes, so the token vanished without a word.

local oly = require "oly"

local GREYFELL = 57081			-- start city 0
local FLIGHT_SEA = 10100		-- deep ocean

oly.load("./lib")
oly.extract_startlocs()

local holders = oly.add_player{
	id = 300, faction = "Holders",
	noble = "holder", noble_name = "Holder One",
	start = "0", full_name = "P Word Here",
	email = "player300@example.com",
}
assert(oly.loc(holders.noble) == GREYFELL, "Holder One must start in Greyfell")

local token = oly.token(holders.noble, "savage")
local band = oly.token_units(token)
oly.poof(band, FLIGHT_SEA)

oly.save("./lib")

print(string.format("built token-vanish: holders=%d holder=%d token=%d "
	.. "band=%d", holders.player, holders.noble, token, band))
