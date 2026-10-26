-- token-swear.lua -- build the token-swear scenario (issue #251).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Two factions start in Greyfell (start city 0):
--
--   holder   Holder One   holds an NPC token, the Horn of the Savages
--                         (oly.token). Day 0 adds its unit, a band of
--                         savages sworn to the Holders. Then Holder One
--                         gives the token to Taker One.
--   taker    Taker One    gets the token, and with it the band.
--
-- When the token changes hands, move_token swears its units to the new
-- holder's faction (swear_token_units). Before the fix for #251 that
-- function tested subkind(unit) == T_char, which no character passes, so
-- the band stayed with the Holders until the month-end check_token_units
-- repaired it.

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

local holders = faction(300, "Holders", "holder", "Holder One")
local takers = faction(301, "Takers", "taker", "Taker One")

local token = oly.token(holders.noble, "savage")

-- The taker's accept runs on day 1, the holder's give after a 7-day wait,
-- so the give is never refused.
oly.order(takers.noble, "accept " .. holders.noble .. " " .. token .. " 1")
oly.order(holders.noble, "wait time 7")
oly.order(holders.noble, "give " .. takers.noble .. " " .. token .. " 1")

oly.save("./lib")

print(string.format("built token-swear: holders=%d holder=%d takers=%d "
	.. "taker=%d token=%d", holders.player, holders.noble,
	takers.player, takers.noble, token))
