-- phase-day0.lua -- build the phase-day0 scenario (issue #232).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Day 0 is where the turn picks up what an earlier
-- turn left: idle NPCs, NPC tokens, stop orders, running orders and pending
-- trades. The bindings below leave that state, as an earlier turn would.
-- Eight factions start in Greyfell (start city 0):
--
--   builder    Plain [13450]       raises 85 towers; savages come for the
--                                  last (init_savage_attacks)
--   deserter   Greyfell            deserts (oly.desert): an idle unsworn
--                                  independent
--   necro      graveyard [59022]   summons a demon lord, whose bond runs
--                                  out (oly.release): an idle undead
--   rallier    Forest [13449]      a mob there has guarded (oly.mob, then
--                                  oly.start): an idle mob
--
-- and three independents need no faction: a band of savages in the forest
-- whose bond has run out (oly.savage, then oly.release), a Hades bandit
-- in Hades [26000] (oly.bandit) and Catchclaw's garrison [1009], which
-- holds the NPC token that melts.
--   holder     Greyfell            holds an NPC token: its unit is added
--   waiter     Greyfell            a wait left running (oly.start), then
--                                  stop: interrupt
--   idler      Greyfell            guard 1, then stop: the turn loads
--                                  guard 1 but has not run it, so nothing
--                                  is executing: idle
--   buyer      Greyfell, 500 gold  buy 30 wood [77] at 14 (oly.start):
--                                  the city's 25 sell at once, 5 stay
--                                  pending; the market is restocked as at
--                                  month end (oly.restock): matched on day 1

local oly = require "oly"

local GOLD, WOOD = 1, 77			-- items
local SPIRIT = 26

local GREYFELL = 57081			-- start city 0
local PLAIN, FOREST = 13450, 13449
local GRAVEYARD = 59022			-- 15 corpses and an undead cookie
local HADES = 26000
local CATCHCLAW_GARRISON = 1009
local TOWERS = 85			-- the 85th tower minted draws a spawn

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
	return f.noble
end

local builder = faction(300, "Builders", "builder", "Builder One")
local deserter = faction(301, "Deserters", "deserter", "Deserter One")
local necro = faction(302, "Necromancers", "necro", "Necro One")
local rallier = faction(303, "Ralliers", "rallier", "Rallier One")
local holder = faction(304, "Holders", "holder", "Holder One")
local waiter = faction(305, "Waiters", "waiter", "Waiter One")
local buyer = faction(306, "Buyers", "buyer", "Buyer One")
local idler = faction(307, "Idlers", "idler", "Idler One")

-- day 0 NPC setup

oly.desert(deserter)

oly.poof(necro, GRAVEYARD)
local undead = oly.undead(necro)
oly.release(undead)
oly.poof(necro, GREYFELL)
assert(oly.loc(undead) == GRAVEYARD, "the demon lord must stay behind")

local savage = oly.savage(FOREST, 10)
oly.release(savage)

oly.poof(rallier, FOREST)
local mob = oly.mob(FOREST)
oly.start(mob)

local bandit = oly.bandit(HADES, SPIRIT, 10)

local token = oly.token(holder, "savage")
local melt = oly.token(CATCHCLAW_GARRISON, "orc")

-- stop orders: one interrupts a running wait, one finds nothing running
oly.order(waiter, "wait time 40")
oly.start(waiter)
oly.order(waiter, "stop")
oly.order(idler, "guard 1")
oly.order(idler, "stop")

-- day 1 trade matching: a buy that outran the city's stock of 25
oly.additem(buyer, GOLD, 300)
oly.order(buyer, "buy " .. WOOD .. " 30 14")
oly.start(buyer)
assert(oly.has_item(buyer, WOOD), "the buyer must have bought the city's wood")
oly.restock(GREYFELL)

-- the savage spawn's fort, made last
oly.poof(builder, PLAIN)
local towers = {}
for i = 1, TOWERS do
	towers[i] = oly.makeloc(builder, "tower")
	assert(oly.loc(towers[i]) == PLAIN, "the tower must be in the plain")
end

oly.save("./lib")

print(string.format("built phase-day0: builder=%d deserter=%d necro=%d "
	.. "rallier=%d holder=%d waiter=%d buyer=%d idler=%d undead=%d "
	.. "savage=%d mob=%d bandit=%d token=%d melt=%d last tower=%d",
	builder, deserter, necro, rallier, holder, waiter, buyer, idler,
	undead, savage, mob, bandit, token, melt, towers[TOWERS]))
