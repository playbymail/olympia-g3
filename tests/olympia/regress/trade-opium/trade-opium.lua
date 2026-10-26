-- trade-opium.lua -- build the trade-opium scenario (issue #252).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. One faction starts in Greyfell (start city 0).
-- Two cities get an opium market (oly.opium), as an earlier month end
-- leaves it:
--
--   Greyfell [57081]  level 0: it buys 15 opium at 17. The pusher sells it
--                     all 15, so at month end the city has sold out and
--                     its level rises to 1 (28 at 17).
--   Adalgar [57625]   level 3: it buys 50 opium at 18. Nobody sells, so at
--                     month end its level falls to 2 (37 at 18).
--
-- Before the fix for #252 the sold-out BUY trade (qty 0) was invisible to
-- opium_market_delta, and Greyfell stayed at level 0.

local oly = require "oly"

local GREYFELL, ADALGAR = 57081, 57625
local OPIUM = 93

oly.load("./lib")
oly.extract_startlocs()

local pushers = oly.add_player{
	id = 300, faction = "Pushers",
	noble = "pusher", noble_name = "Pusher One",
	start = "0", full_name = "P Word Here",
	email = "player300@example.com",
}
local pusher = pushers.noble
assert(oly.loc(pusher) == GREYFELL, "Pusher One must start in Greyfell")

assert(oly.opium(GREYFELL, 0) == 0)
assert(oly.opium(ADALGAR, 3) == 3)

oly.additem(pusher, OPIUM, 15)
oly.order(pusher, "sell " .. OPIUM .. " 15 17")

oly.save("./lib")

print(string.format("built trade-opium: player=%d pusher=%d",
	pushers.player, pusher))
