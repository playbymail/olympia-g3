-- stop-running.lua -- build turn 1 of the stop-running scenario (issue #361).
--
-- Run first by build-scenario.sh against the bare-map fixture. It sets up
-- units whose orders are still running when turn 1 ends; build-scenario.sh
-- then runs turn 1, and stop-running-stop.lua queues a STOP for each of
-- them, so the fixture's turn interrupts them on day 0. A STOP interrupts
-- only an order an earlier turn left running, which is why the scenario
-- needs a real turn behind it. Eleven factions start in Greyfell (start
-- city 0):
--
--   quarrier    Mountain [13349], 1 worker     collect 78 0 0: stone, 1 a
--                                              day of the mountain's 50
--   fisher      a roundship on Ocean [13350],  collect 87 0 0: fish
--               2 sailors
--   trainer     Greyfell, 125 peasants         make 11 100: a worker a day
--   wrangler    Greyfell, 20 wild horses       make 52 0: a riding horse
--                                              every 3 days
--   mender      a tower, damage 10, 2 workers  repair: 1 point a day, the
--                                              damage then the defense
--   waller      a tower, 1 worker              repair: the defense only
--   patcher     a tower, damage 60, 2 workers  repair: the damage only
--   sailor      a roundship on Ocean [13350]   wait day 28, sail north: 3
--                                              days
--   pilot       a roundship on Ocean [13350]   wait day 28, use 601 north
--   idler       Forest [13451]                 nothing in turn 1
--   loafer      a tower, 1 worker              nothing in turn 1
--
-- The idler and the loafer start their orders on turn 2's day 0, in
-- stop-running-stop.lua, so the STOP finds them with no progress. This
-- script writes every id to ids.lua for that script to read.

local oly = require "oly"

local PEASANT, WORKER, SAILOR = 10, 11, 19	-- items
local WILD_HORSE, STONE, FISH = 51, 78, 87
local SHIPCRAFT, SAILING, FISHING = 600, 601, 603	-- skills
local BEAST, TRAIN_WILD = 650, 656
local HARVEST_LUMBER, QUARRY_STONE = 702, 682

local GREYFELL = 57081			-- start city 0, a port
local MOUNTAIN, FOREST, OCEAN = 13349, 13451, 13350

oly.load("./lib")
oly.extract_startlocs()

local ids = {}

local function noble(id, faction, handle, name)
	local f = oly.add_player{
		id = id, faction = faction,
		noble = handle, noble_name = name,
		start = "0", full_name = "P Word Here",
		email = string.format("player%d@example.com", id),
	}
	assert(oly.loc(f.noble) == GREYFELL, name .. " must start in Greyfell")
	ids[handle] = f.noble
	return f.noble
end

local quarrier = noble(300, "Quarriers", "quarrier", "Quarrier One")
local fisher = noble(301, "Fisherfolk", "fisher", "Fisher One")
local trainer = noble(302, "Trainers", "trainer", "Trainer One")
local wrangler = noble(303, "Wranglers", "wrangler", "Wrangler One")
local mender = noble(304, "Menders", "mender", "Mender One")
local waller = noble(305, "Wallers", "waller", "Waller One")
local patcher = noble(306, "Patchers", "patcher", "Patcher One")
local sailor = noble(307, "Sailors", "sailor", "Sailor One")
local pilot = noble(308, "Pilots", "pilot", "Pilot One")
local idler = noble(309, "Idlers", "idler", "Idler One")
local loafer = noble(310, "Loafers", "loafer", "Loafer One")

-- collect: stone with workers, and fish from a ship, where the fish are
-- the ocean's, not the ship's
oly.know(quarrier, QUARRY_STONE)
oly.additem(quarrier, WORKER, 1)
oly.poof(quarrier, MOUNTAIN)
oly.order(quarrier, "collect " .. STONE .. " 0 0")

oly.know(fisher, FISHING)
oly.additem(fisher, SAILOR, 2)
oly.poof(fisher, OCEAN)
ids.fishing_boat = oly.makeloc(fisher, "roundship")
oly.poof(fisher, ids.fishing_boat)
oly.order(fisher, "collect " .. FISH .. " 0 0")

-- make: a one-day row (workers from peasants) and a multi-day row
oly.additem(trainer, PEASANT, 100)
oly.order(trainer, "make " .. WORKER .. " 100")

oly.know(wrangler, BEAST)
oly.know(wrangler, TRAIN_WILD)
oly.additem(wrangler, WILD_HORSE, 20)
oly.order(wrangler, "make 52 0")

-- repair: a makeloc'd tower has defense 0, under a tower's 40, and two
-- worker-days repair a point
local function tower(who, damage, workers)
	local t = oly.makeloc(who, "tower")
	oly.poof(who, t)
	if damage > 0 then
		oly.damage(t, damage)
	end
	oly.additem(who, WORKER, workers)
	return t
end

ids.mended = tower(mender, 10, 2)
oly.order(mender, "repair")
ids.walled = tower(waller, 0, 1)
oly.order(waller, "repair")
ids.patched = tower(patcher, 60, 2)
oly.order(patcher, "repair")
ids.loafed = tower(loafer, 0, 1)

-- sail: leave late enough that the voyage outlasts the month
local function ship(who)
	oly.know(who, SHIPCRAFT)
	oly.know(who, SAILING)
	oly.subitem(who, PEASANT, 25)
	oly.additem(who, SAILOR, 8)
	oly.poof(who, OCEAN)
	local s = oly.makeloc(who, "roundship")
	oly.poof(who, s)
	return s
end

ids.sailed = ship(sailor)
oly.order(sailor, "wait day 28")
oly.order(sailor, "sail north")
ids.piloted = ship(pilot)
oly.order(pilot, "wait day 28")
oly.order(pilot, "use " .. SAILING .. " north")

-- the idler collects wood on turn 2
oly.know(idler, HARVEST_LUMBER)
oly.additem(idler, WORKER, 2)
oly.poof(idler, FOREST)

oly.save("./lib")

local f = assert(io.open("ids.lua", "w"))
f:write("return {\n")
local keys = {}
for k in pairs(ids) do keys[#keys + 1] = k end
table.sort(keys)
for _, k in ipairs(keys) do
	f:write(string.format("\t%s = %d,\n", k, ids[k]))
end
f:write("}\n")
f:close()

print("built stop-running turn 1")
