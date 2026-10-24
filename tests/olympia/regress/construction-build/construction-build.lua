-- construction-build.lua -- build the construction-build scenario (issue #147).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Three factions start in Greyfell (start city 0):
--
--   builder    knows Construction, has 100 workers and 100 stone: builds a
--              tower (2000 worker-days, 20 stone per fifth), which it
--              finishes on day 20
--   improver   stands in a castle made by oly.makeloc, has 100 workers and
--              50 stone: improves it to level 1 (1000 worker-days, ten
--              days)
--   repairer   stands in a tower made by oly.makeloc, has 10 workers: a
--              makeloc'd building has defense 0, under a tower's default
--              40, so it needs repair (2 worker-days a point, eight days)
--
-- Every start returns TRUE (ok). The builder's tower id is minted (the mint
-- stream); the other two buildings are minted here, before the turn.

local oly = require "oly"

local GREYFELL = 57081			-- start city 0

local CONSTRUCTION = 680		-- skill
local WORKER, STONE = 11, 78		-- items

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

local builders = faction(300, "Builders", "builder", "Builder One")
local improvers = faction(301, "Improvers", "improver", "Improver One")
local repairers = faction(302, "Repairers", "repairer", "Repairer One")
local builder, improver = builders.noble, improvers.noble
local repairer = repairers.noble

oly.know(builder, CONSTRUCTION)
oly.additem(builder, WORKER, 100)
oly.additem(builder, STONE, 100)

local castle = oly.makeloc(improver, "castle", "castle")
oly.poof(improver, castle)
assert(oly.loc(improver) == castle, "the improver must be in the castle")
oly.additem(improver, WORKER, 100)
oly.additem(improver, STONE, 50)

local tower = oly.makeloc(repairer, "tower", "tower")
oly.poof(repairer, tower)
assert(oly.loc(repairer) == tower, "the repairer must be in the tower")
oly.additem(repairer, WORKER, 10)

oly.order(builder, "build tower")
oly.order(improver, "improve")
oly.order(repairer, "repair")

oly.save("./lib")

print(string.format("built construction-build: builder=%d improver=%d "
	.. "repairer=%d castle=%d tower=%d", builder, improver, repairer,
	castle, tower))
