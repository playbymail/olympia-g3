-- gm-credit.lua -- build the gm-credit scenario (issue #151).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. One faction in Greyfell (start city 0), whose
-- noble knows Shipcraft and has seen its lore. The GM player (The Fates,
-- 200) has no units; it issues the gm verbs itself, and check_allow passes
-- them because player(200) is the GM player:
--
--   credit   gold (no item), soldiers, NP to the faction, and the Times'
--            25 gold (no amount)
--   emote    a message to the herald; its %s is the herald's name
--   relore   Shipcraft, whose lore sheet oly.seen marks as delivered before
--            the turn, so the turn would not send it again; only the relore
--            puts it back in the faction's report

local oly = require "oly"

local GM = 200				-- gm_player, The Fates
local SOLDIER = 12			-- item
local SHIPCRAFT = 600			-- skill

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

oly.know(herald, SHIPCRAFT)
oly.seen(herald, SHIPCRAFT)

for _, o in ipairs{
		"credit " .. herald .. " 5",
		"credit " .. herald .. " 7 " .. SOLDIER,
		"credit " .. guild.player .. " 3 np",
		"credit " .. herald,
		"emote " .. herald .. " \"The Fates smile on %s.\"",
		"relore " .. SHIPCRAFT } do
	oly.order(GM, o)
end

oly.save("./lib")

print(string.format("built gm-credit: player=%d herald=%d",
	guild.player, herald))
