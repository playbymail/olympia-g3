-- construction-refused.lua -- build the construction-refused scenario (issue #147).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Five factions start in Greyfell (start city 0):
--
--   bungler    in the keeper's castle, no Construction and no workers:
--              build fails with nothing named, with an unknown structure
--              and for want of the skill; improve and repair fail for want
--              of workers
--   mason      in Greyfell, knows Construction but has no stone: build
--              tower fails for want of stone, build castle because Greyfell
--              is a safe haven; improve fails (not in a castle) and repair
--              fails (a city is not repairable)
--   keeper     stands in a castle made by oly.makeloc with one worker and
--              no stone: improve fails for want of the stone
--   mender     stands in a tower made by oly.makeloc (defense 0, under the
--              default 40) with 80 workers: the first repair restores all
--              40 points on its first day (ok), the second fails (not
--              damaged)
--   lord       stands in a second castle, set to level six by
--              oly.castle_level (#162), with a worker: improve fails (no
--              further improvement)
--
-- Rejected: all three verbs are for nobles (c), so the player entity's
-- orders for all three are refused.

local oly = require "oly"

local GREYFELL = 57081			-- start city 0

local CONSTRUCTION = 680		-- skill
local WORKER = 11			-- item

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
local masons = faction(301, "Masons", "mason", "Mason One")
local keepers = faction(302, "Keepers", "keeper", "Keeper One")
local menders = faction(303, "Menders", "mender", "Mender One")
local bungler, mason = bunglers.noble, masons.noble
local keeper, mender = keepers.noble, menders.noble

oly.know(mason, CONSTRUCTION)

local castle = oly.makeloc(keeper, "castle", "castle")
for _, who in ipairs{ keeper, bungler } do
	oly.poof(who, castle)
	assert(oly.loc(who) == castle, "keeper and bungler must be in the castle")
end
oly.additem(keeper, WORKER, 1)

local tower = oly.makeloc(mender, "tower", "tower")
oly.poof(mender, tower)
assert(oly.loc(mender) == tower, "the mender must be in the tower")
oly.additem(mender, WORKER, 80)

-- added after the makeloc calls above so their ids do not move
local lords = faction(304, "Lords", "lord", "Lord One")
local lord = lords.noble
local keep = oly.makeloc(lord, "castle", "keep")
oly.poof(lord, keep)
assert(oly.loc(lord) == keep, "the lord must be in its castle")
assert(oly.castle_level(keep, 6) == 6, "the keep must be at level six")
oly.additem(lord, WORKER, 1)

for _, o in ipairs{ "build", "build palace", "build tower", "improve",
		"repair" } do
	oly.order(bungler, o)
end
for _, o in ipairs{ "build tower", "build castle", "improve", "repair" } do
	oly.order(mason, o)
end
oly.order(keeper, "improve")
oly.order(lord, "improve")
oly.order(mender, "repair")
oly.order(mender, "repair")
for _, o in ipairs{ "build tower", "improve", "repair" } do
	oly.order(bunglers.player, o)
end

oly.save("./lib")

print(string.format("built construction-refused: player=%d bungler=%d "
	.. "mason=%d keeper=%d mender=%d lord=%d castle=%d tower=%d keep=%d",
	bunglers.player, bungler, mason, keeper, mender, lord, castle, tower,
	keep))
