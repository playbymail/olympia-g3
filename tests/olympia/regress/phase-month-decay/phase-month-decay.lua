-- phase-month-decay.lua -- build the phase-month-decay scenario (issue #234).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Most month-end decay counts down state that
-- earlier month ends left, and the bindings below leave it. The world is
-- built at turn 0, when one noble is killed, and then the clock is set so
-- that the turn run is turn 13: its body is 13 turns dead. Six factions
-- start in Greyfell (start city 0):
--
--   deserter   Greyfell            loyalty run down to contract 0: deserts
--                                  on its keyed roll
--   mage       Plain [13450]       use 814 on the patient: hinders its
--                                  meditation (not in Greyfell, a safe
--                                  haven)
--   patient    Plain [13450]       hindered, and never meditates
--   keeper     Greyfell            a relic left 3 months (Crown of
--                                  Prosperity [402]) and one left 1 (Skull
--                                  of Bastrestric [403]), a ghost warrior,
--                                  300 riding horses and the dead body
--   doomed     Greyfell            killed at turn 0; its body rots
--   miner      Plain [13450]       two collapsed mines, 3 and 1 months
--                                  from being cleared away
--
-- and one independent: a band of savages in Forest [13449] whose bond has
-- run out (summon 0). Plain was pillaged an earlier turn (loot 4).

local oly = require "oly"

local GHOST, HORSE = 18, 52		-- items
local MAGIC, HINDER = 800, 814		-- skills
local CROWN, SKULL = 402, 403		-- relics in Nowhere

local GREYFELL = 57081			-- start city 0
local PLAIN, FOREST = 13450, 13449

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

local deserter = faction(300, "Deserters", "deserter", "Deserter One")
local mage = faction(301, "Mages", "mage", "Mage One")
local patient = faction(302, "Patients", "patient", "Patient One")
local keeper = faction(303, "Keepers", "keeper", "Keeper One")
local doomed = faction(304, "Doomed", "doomed", "Doomed One")
local miner = faction(305, "Miners", "miner", "Miner One")

-- turn 0: the death; then the game moves on to turn 12
local body = oly.kill(doomed, keeper)
oly.clock(12)

-- magic may not be used in a safe haven such as Greyfell
oly.poof(mage, PLAIN)
oly.poof(patient, PLAIN)
oly.know(mage, MAGIC)
oly.know(mage, HINDER)
oly.order(mage, "use " .. HINDER .. " " .. patient .. " 1")

oly.relic(keeper, CROWN, 3)
oly.relic(keeper, SKULL, 1)
oly.additem(keeper, GHOST, 1)
oly.additem(keeper, HORSE, 300)

-- its keyed desertion roll (1 in 2) comes up
oly.loyalty(deserter, "contract", 0)

local savage = oly.savage(FOREST, 10)
oly.loyalty(savage, "summon", 0)

oly.loot(PLAIN, 4)

oly.poof(miner, PLAIN)
local mines = {}
for i, months in ipairs{ 3, 1 } do
	mines[i] = oly.makeloc(miner, "mine")
	assert(oly.loc(mines[i]) == PLAIN, "the mine must be in the plain")
	oly.collapse(mines[i], months)
end

oly.save("./lib")

print(string.format("built phase-month-decay: deserter=%d mage=%d patient=%d "
	.. "keeper=%d doomed=%d miner=%d body=%d savage=%d mines=%d,%d",
	deserter, mage, patient, keeper, doomed, miner, body, savage,
	mines[1], mines[2]))
