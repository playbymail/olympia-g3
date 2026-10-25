-- use-crafts.lua -- build the use-crafts scenario (issue #190).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Six factions start in Greyfell (start city 0),
-- and each noble is given a school, the skills it uses, and what each
-- skill's start needs:
--
--   captain     a roundship in Greyfell, 8 sailors     use 601 east
--   fisher      a roundship on Ocean [13350], 2 sailors use 603 2
--   wright      Greyfell, 3 wood, 3 leather, 3 workers use 681
--   quarryman   Mountain [13349], 2 workers            use 682 2
--   miner       a depth-4 mine on Mountain [13349],    use 721, use 722,
--               20 workers                             use 723
--   trader      Greyfell                               use 732
--
-- Every start returns TRUE (ok). make_siege (681) has no start: v_use hands
-- it to skill_produce, and d_use makes the siege tower 14 days on.
--
-- A mine makeloc creates has no shaft, so oly.mine_depth sinks it to depth
-- 4, the shallowest depth that yields mithril, and stocks it. A mine's
-- daily cave-in chance grows with its depth: this one kills six of the
-- miner's workers during the month, so it starts with twenty, and still has
-- the ten each use needs.

local oly = require "oly"

local PEASANT, WORKER, SAILOR = 10, 11, 19	-- items
local WOOD, LEATHER = 77, 80
local SHIPCRAFT, SAILING, FISHING = 600, 601, 603	-- skills
local CONSTRUCTION, MAKE_SIEGE, QUARRY_STONE = 680, 681, 682
local MINING, MINE_IRON, MINE_GOLD, MINE_MITHRIL = 720, 721, 722, 723
local TRADE, FIND_SELL = 730, 732

local GREYFELL = 57081			-- start city 0, a port
local MOUNTAIN, OCEAN = 13349, 13350

oly.load("./lib")
oly.extract_startlocs()

local function noble(id, faction, handle, name)
	local f = oly.add_player{
		id = id, faction = faction,
		noble = handle, noble_name = name,
		start = "0", full_name = "P Word Here",
		email = string.format("player%d@example.com", id),
	}
	assert(oly.loc(f.noble) == GREYFELL, name .. " must start in Greyfell")
	return f.noble
end

local captain = noble(300, "Ferry Line", "captain", "Captain One")
local fisher = noble(301, "Fisherfolk", "fisher", "Fisher One")
local wright = noble(302, "Siege Works", "wright", "Wright One")
local quarryman = noble(303, "Quarry Guild", "quarryman", "Quarryman One")
local miner = noble(304, "Deep Delvers", "miner", "Miner One")
local trader = noble(305, "Merchants", "trader", "Trader One")

-- the captain sails east out of Greyfell, as in move-ship
oly.know(captain, SHIPCRAFT)
oly.know(captain, SAILING)
oly.subitem(captain, PEASANT, 25)
oly.additem(captain, SAILOR, 8)
local ferry = oly.makeloc(captain, "roundship", "ferry")
oly.poof(captain, ferry)

-- fish are caught from a ship at sea
oly.know(fisher, SHIPCRAFT)
oly.know(fisher, FISHING)
oly.additem(fisher, SAILOR, 2)
oly.poof(fisher, OCEAN)
local boat = oly.makeloc(fisher, "roundship", "boat")
oly.poof(fisher, boat)

-- a siege tower takes 3 wood and 3 leather, and 3 workers to build it
oly.know(wright, CONSTRUCTION)
oly.know(wright, MAKE_SIEGE)
oly.additem(wright, WOOD, 3)
oly.additem(wright, LEATHER, 3)
oly.additem(wright, WORKER, 3)

oly.know(quarryman, CONSTRUCTION)
oly.know(quarryman, QUARRY_STONE)
oly.additem(quarryman, WORKER, 2)
oly.poof(quarryman, MOUNTAIN)

-- mining needs a mine and ten workers; cave-ins take six of these
oly.know(miner, MINING)
oly.know(miner, MINE_IRON)
oly.know(miner, MINE_GOLD)
oly.know(miner, MINE_MITHRIL)
oly.additem(miner, WORKER, 20)
oly.poof(miner, MOUNTAIN)
local mine = oly.makeloc(miner, "mine", "mine")
assert(oly.mine_depth(mine, 4) == 4, "the mine must be at depth 4")
oly.poof(miner, mine)

oly.know(trader, TRADE)
oly.know(trader, FIND_SELL)

assert(oly.loc(ferry) == GREYFELL, "the ferry must be built in Greyfell")
assert(oly.loc(captain) == ferry, "the captain must be aboard the ferry")
assert(not oly.has_item(captain, PEASANT), "the captain's peasants must go")
assert(oly.loc(boat) == OCEAN, "the boat must be at sea")
assert(oly.loc(fisher) == boat, "the fisher must be aboard the boat")
assert(oly.loc(quarryman) == MOUNTAIN, "the quarryman must be on the mountain")
assert(oly.loc(mine) == MOUNTAIN, "the mine must be on the mountain")
assert(oly.loc(miner) == mine, "the miner must be in the mine")

oly.order(captain, "use " .. SAILING .. " east")
oly.order(fisher, "use " .. FISHING .. " 2")
oly.order(wright, "use " .. MAKE_SIEGE)
oly.order(quarryman, "use " .. QUARRY_STONE .. " 2")
for _, sk in ipairs{ MINE_IRON, MINE_GOLD, MINE_MITHRIL } do
	oly.order(miner, "use " .. sk)
end
oly.order(trader, "use " .. FIND_SELL)

oly.save("./lib")

print(string.format("built use-crafts: captain=%d fisher=%d wright=%d "
	.. "quarryman=%d miner=%d trader=%d ferry=%d boat=%d mine=%d",
	captain, fisher, wright, quarryman, miner, trader, ferry, boat, mine))
