-- governance-rule.lua -- build the governance-rule scenario (issue #150).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Two factions start in Greyfell (start city 0):
--
--   lord       stands in a castle made by oly.makeloc in the city, so it is
--              the castle's owner; pledges its lands to the warden
--   warden     stands in the forest province around the city with 20
--              soldiers: garrisons the province, bound to the lord's castle,
--              decrees a watch and a hostility, then ungarrisons it
--
-- The garrison rules through the castle: its owner, the lord, pledged to the
-- warden, so the warden rules there too (may_rule_here). pledge is a
-- priority-1 order, so it runs before the warden's priority-3 garrison.
-- Every start returns TRUE (ok). The garrison's id is minted (the mint
-- stream); the castle is minted here, before the turn.

local oly = require "oly"

local SOLDIER = 12			-- item

local GREYFELL = 57081			-- start city 0
local FOREST = 13451			-- Greyfell's province
local CATCHCLAW = 58706			-- a city with a seeded garrison

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

local lords = faction(300, "Lords", "lord", "Lord One")
local wardens = faction(301, "Wardens", "warden", "Warden One")
local lord, warden = lords.noble, wardens.noble

-- the hostility's target, far from the garrison
local outsider = oly.garrison(CATCHCLAW)
assert(outsider, "Catchclaw must have a garrison")

local castle = oly.makeloc(lord, "castle", "castle")
oly.poof(lord, castle)
assert(oly.loc(lord) == castle, "the lord must be in the castle")

oly.poof(warden, FOREST)
assert(oly.loc(warden) == FOREST, "the warden must be in the forest")
assert(not oly.garrison(FOREST), "the forest must have no garrison")
oly.additem(warden, SOLDIER, 20)

oly.order(lord, "pledge " .. warden)
for _, o in ipairs{
		"garrison " .. castle,
		"decree watch " .. lord,
		"decree hostile " .. outsider,
		"ungarrison" } do
	oly.order(warden, o)
end

oly.save("./lib")

print(string.format("built governance-rule: lord=%d warden=%d castle=%d "
	.. "outsider=%d", lord, warden, castle, outsider))
