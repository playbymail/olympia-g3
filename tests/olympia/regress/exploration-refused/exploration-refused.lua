-- exploration-refused.lua -- build the exploration-refused scenario (issue #148).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Five factions start in Greyfell (start city 0):
--
--   bungler    stays in Greyfell, a safe haven: seek of Greyfell fails (not
--              a character), and quest fails (no questing in a safe haven)
--   leader     poofed to Plain [13450], a province with no quest monsters:
--              admits the follower, then quest fails (no quests here)
--   follower   poofed to Plain, stacks under the leader: quest fails (only
--              the stack leader may quest)
--   quester    poofed into the hidden ruins [74516] in Plain: quests there,
--              which raises a monster and marks the ruins as quested
--   latecomer  poofed into the same ruins: waits out the quester's quest,
--              then quest fails (quested recently)
--
-- Rejected: every exploration verb is for nobles (c or cr), so the player
-- entity's explore, seek, quest, plugh and xyzzy are refused. explore,
-- plugh and xyzzy always start, so they have no fail cell.

local oly = require "oly"

local GREYFELL = 57081			-- start city 0
local PLAIN = 13450			-- province next to Greyfell's forest
local RUINS = 74516			-- hidden ruins in PLAIN

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

local bunglers = faction(300, "Bunglers", "bungler", "Bungler One")
local leaders = faction(301, "Leaders", "leader", "Leader One")
local followers = faction(302, "Followers", "follower", "Follower One")
local questers = faction(303, "Questers", "quester", "Quester One")
local latecomers = faction(304, "Latecomers", "latecomer", "Latecomer One")
local bungler, leader, follower = bunglers.noble, leaders.noble, followers.noble
local quester, latecomer = questers.noble, latecomers.noble

for _, who in ipairs{ leader, follower } do
	oly.poof(who, PLAIN)
	assert(oly.loc(who) == PLAIN, "leader and follower must be in Plain")
end
for _, who in ipairs{ quester, latecomer } do
	oly.poof(who, RUINS)
	assert(oly.loc(who) == RUINS, "quester and latecomer must be in the ruins")
end
assert(oly.loc(RUINS) == PLAIN, "the ruins must be in Plain")

oly.order(bungler, "seek " .. GREYFELL)
oly.order(bungler, "quest")
oly.order(leader, "admit " .. leader .. " " .. follower)
oly.order(leader, "quest")
oly.order(follower, "wait day 1")
oly.order(follower, "stack " .. leader)
oly.order(follower, "quest")
oly.order(quester, "quest")
oly.order(latecomer, "wait day 10")
oly.order(latecomer, "quest")
for _, o in ipairs{ "explore", "seek", "quest", "plugh", "xyzzy" } do
	oly.order(bunglers.player, o)
end

oly.save("./lib")

print(string.format("built exploration-refused: player=%d bungler=%d "
	.. "leader=%d follower=%d quester=%d latecomer=%d", bunglers.player,
	bungler, leader, follower, quester, latecomer))
