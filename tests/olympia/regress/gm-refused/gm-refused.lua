-- gm-refused.lua -- build the gm-refused scenario (issue #151).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. One faction in Greyfell (start city 0). Its
-- noble issues the three gm verbs, which only the GM player's units may
-- issue, so each is rejected. The GM player (The Fates, 200) issues each
-- verb so that it fails:
--
--   credit   gold to a city (not a character or player), NP to a noble
--            (not a player), the Times' pay to a city (not a character),
--            and the Times' pay twice (already paid; the first is ok),
--            and no target
--   emote    no message
--   relore   a city, which is not a skill, and no skill
--
-- The bare credit and relore follow orders with a target, so the GM's parse
-- vector still holds a stale pointer in the target's slot (#364).

local oly = require "oly"

local GM = 200				-- gm_player, The Fates

local GREYFELL = 57081			-- start city 0

oly.load("./lib")
oly.extract_startlocs()

local guild = oly.add_player{
	id = 300, faction = "Guild",
	noble = "herald", noble_name = "Herald One",
	start = "0", full_name = "P Word Here", email = "player300@example.com",
}
local herald = guild.noble

assert(oly.loc(herald) == GREYFELL, "the herald must start in Greyfell")

for _, o in ipairs{
		"credit " .. herald .. " 5",
		"emote " .. herald .. " \"Hello, %s.\"",
		"relore 600" } do
	oly.order(herald, o)
end

for _, o in ipairs{
		"credit " .. GREYFELL .. " 5",
		"credit " .. herald .. " 2 np",
		"credit " .. GREYFELL,
		"credit " .. herald,
		"credit " .. herald,
		"credit",
		"emote " .. herald,
		"relore " .. GREYFELL,
		"relore" } do
	oly.order(GM, o)
end

oly.save("./lib")

print(string.format("built gm-refused: player=%d herald=%d",
	guild.player, herald))
