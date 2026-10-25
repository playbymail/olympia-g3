-- player-refused.lua -- build the player-refused scenario (issue #152).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. One faction, 300 "Strangers", in Greyfell (start
-- city 0). Its noble orders wait with no condition (fail: wait needs one).
--
-- Rejected: post is for nobles (c) and wait for nobles and the GM (crm), so
-- the player entity's post and wait are refused. The other player verbs are
-- cp or cpr, so the garrison of Catchclaw, seeded by oly.load, orders them
-- and each is refused.

local oly = require "oly"

local GREYFELL = 57081			-- start city 0
local CATCHCLAW = 58706			-- a city with a seeded garrison

oly.load("./lib")
oly.extract_startlocs()

local strangers = oly.add_player{
	id = 300, faction = "Strangers",
	noble = "stranger", noble_name = "Stranger One",
	start = "0", full_name = "P Word Here", email = "player300@example.com",
}
local stranger = strangers.noble
assert(oly.loc(stranger) == GREYFELL, "the stranger must start in Greyfell")

local garrison = oly.garrison(CATCHCLAW)
assert(garrison, "Catchclaw must have a garrison")

oly.order(stranger, "wait")
oly.order(strangers.player, "post 1")
oly.order(strangers.player, "wait time 1")
for _, o in ipairs{
		"format 0", "message 1 " .. stranger, "name Gate Watch",
		"notab 1", "press 1", "public 1", "realname Gate Watch",
		"rumor 1", "split 100 0", "stop", "times 1" } do
	oly.order(garrison, o)
end

oly.save("./lib")

print(string.format("built player-refused: player=%d stranger=%d "
	.. "garrison=%d", strangers.player, stranger, garrison))
