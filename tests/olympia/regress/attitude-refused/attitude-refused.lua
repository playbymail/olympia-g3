-- attitude-refused.lua -- build the attitude-refused scenario (issue #129).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. One faction, 300 "Strangers", in Greyfell (start
-- city 0). Its noble orders admit with no target (fail: admit needs an
-- entity). The other attitude verbs always return TRUE, so they have no fail
-- outcome.
--
-- Rejected: contact is for nobles (cr), so the player entity's contact is
-- refused. The other five verbs are cpr, so the garrison of Catchclaw, seeded
-- by oly.load, orders them and each is refused.

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

oly.order(stranger, "admit")
oly.order(strangers.player, "contact " .. stranger)
for _, o in ipairs{
		"admit " .. garrison .. " " .. stranger,
		"default " .. stranger,
		"defend " .. stranger,
		"hostile " .. stranger,
		"neutral " .. stranger } do
	oly.order(garrison, o)
end

oly.save("./lib")

print(string.format("built attitude-refused: player=%d stranger=%d "
	.. "garrison=%d", strangers.player, stranger, garrison))
