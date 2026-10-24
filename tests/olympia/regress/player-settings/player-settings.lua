-- player-settings.lua -- build the player-settings scenario (issue #118).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. One faction in Greyfell (start city 0). Its noble
-- and its player entity each issue the faction and report settings verbs,
-- once to succeed and again to fail or be refused:
--
--   noble:  banner, flag, name, realname, stop  (ok)
--           banner too long, flag again, name and realname with no name,
--           split  (fail; split's start always returns 0)
--   player: format, notab, public  (ok)
--           public again  (fail: already a public turn)
--           banner, flag  (rejected: noble-only verbs)

local oly = require "oly"

local GREYFELL = 57081			-- start city 0

oly.load("./lib")
oly.extract_startlocs()

local guild = oly.add_player{
	id = 300, faction = "Settings Guild",
	noble = "herald", noble_name = "Herald One",
	start = "0", full_name = "P Word Here", email = "player300@example.com",
}
local herald = guild.noble

assert(oly.loc(herald) == GREYFELL, "the herald must start in Greyfell")

for _, o in ipairs{
		"banner Argent a chevron sable",
		"banner " .. string.rep("x", 51),	-- over 50 characters
		"flag ready",
		"flag ready",				-- once a month
		"name Herald Prime",
		"name",
		"realname Pat Q Player",
		"realname",
		"stop",
		"split 2000 20000" } do
	oly.order(herald, o)
end

for _, o in ipairs{ "format 1", "notab 1", "public", "public",
		"banner Or plain", "flag ready" } do
	oly.order(guild.player, o)
end

oly.save("./lib")

print(string.format("built player-settings: player=%d herald=%d",
	guild.player, herald))
