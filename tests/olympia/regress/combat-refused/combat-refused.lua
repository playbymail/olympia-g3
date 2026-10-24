-- combat-refused.lua -- build the combat-refused scenario (issue #128).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. One faction, 300 "Pacifists", in Greyfell (start
-- city 0, a safe haven). Its noble orders the combat verbs that can fail:
--
--   attack     fail: combat is not permitted in safe havens
--   pillage    fail: pillaging is not permitted in safe havens
--   surrender  fail: can't surrender to oneself
--   execute    fail: the noble holds no such prisoner
--   raze       fail: not in a building
--
-- behind and guard always return TRUE, so they have no fail outcome.
-- The player entity orders every combat verb (rejected: noble-only verbs).

local oly = require "oly"

local GREYFELL = 57081			-- start city 0

oly.load("./lib")
oly.extract_startlocs()

local pacifists = oly.add_player{
	id = 300, faction = "Pacifists",
	noble = "pacifist", noble_name = "Pacifist One",
	start = "0", full_name = "P Word Here", email = "player300@example.com",
}
local pacifist = pacifists.noble

assert(oly.loc(pacifist) == GREYFELL, "the pacifist must start in Greyfell")

for _, o in ipairs{
		"attack " .. pacifist, "pillage", "surrender " .. pacifist,
		"execute " .. pacifist, "raze" } do
	oly.order(pacifist, o)
end
for _, o in ipairs{
		"attack " .. pacifist, "behind 1", "guard 1", "pillage",
		"surrender " .. pacifist, "execute " .. pacifist, "raze" } do
	oly.order(pacifists.player, o)
end

oly.save("./lib")

print(string.format("built combat-refused: player=%d pacifist=%d",
	pacifists.player, pacifist))
