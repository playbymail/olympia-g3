-- combat-stack-flee.lua -- build the combat-stack-flee scenario (issue #212).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Three factions meet in plain province 10113 (not
-- a safe haven, so combat is allowed):
--
--   raider    200 soldiers; waits until day 7, then attacks the victim
--   victim    300 extra peasants; admits the follower to its stack
--   follower  waits until day 3 (the admit runs on day 2), then stacks
--             under the victim
--
-- The raider wins, and demote_units makes the losing stack flee. Only the
-- stack leader may flee; the follower must end the turn still stacked under
-- the victim. The victim's peasants keep the capture chance low enough that
-- neither loser is taken prisoner (see README.md). Every start returns TRUE
-- (ok).

local oly = require "oly"

local PEASANTS = 10			-- items
local SOLDIERS = 12

local PROV = 10113			-- plain province, as in combat-attack

oly.load("./lib")
oly.extract_startlocs()

local function faction(id, name, handle, noble_name)
	local f = oly.add_player{
		id = id, faction = name,
		noble = handle, noble_name = noble_name,
		start = "0", full_name = "P Word Here",
		email = string.format("player%d@example.com", id),
	}
	oly.poof(f.noble, PROV)
	assert(oly.loc(f.noble) == PROV, noble_name .. " must be in the province")
	return f
end

local raiders = faction(300, "Raiders", "raider", "Raider One")
local victims = faction(301, "Victims", "victim", "Victim One")
local followers = faction(302, "Followers", "follower", "Follower One")
local raider, victim, follower = raiders.noble, victims.noble, followers.noble

oly.additem(raider, SOLDIERS, 200)
oly.additem(victim, PEASANTS, 300)
assert(oly.has_item(raider, SOLDIERS), "the raider has no soldiers")

oly.order(raider, "wait day 7")
oly.order(raider, "attack " .. victim)
oly.order(victim, "admit " .. victim .. " " .. follower)
oly.order(follower, "wait day 3")
oly.order(follower, "stack " .. victim)

oly.save("./lib")

print(string.format("built combat-stack-flee: raider=%d victim=%d "
	.. "follower=%d", raider, victim, follower))
