-- social-switched.lua -- build the social-switched scenario (issue #160).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Four factions start in Greyfell (start city 0):
--
--   former      forms a hireling (contract-500, stacked beneath it, day 7)
--   rival       knows Bribe noble, has 500 more gold: from day 10 bribes the
--               hireling with 500; its finish (day 16) runs after the
--               winner's and is refused: the hireling just switched
--   winner      the same, but its finish runs first: 500 reaches the
--               contract-500 threshold, the social-stream draw comes out
--               SWITCH, and the hireling deserts to the winners, which sets
--               its new_lord flag
--   latecomer   knows Bribe noble: bribes the hireling on day 18, after the
--               switch, and is refused at the start
--
-- Each new noble goes to the head of Greyfell's list, and finishes run in
-- list order, so the winners, added after the rivals, finish first. The
-- bribe draws are keyed on (briber, target) and the day; with these ids and
-- days the winner's draw lands SWITCH.

local oly = require "oly"

local GREYFELL = 57081			-- start city 0

local GOLD = 1				-- items
local BRIBE_NOBLE = 671			-- skills

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

local formers = faction(300, "Formers", "former", "Former One")
local rivals = faction(301, "Rivals", "rival", "Rival One")
local winners = faction(302, "Winners", "winner", "Winner One")
local latecomers = faction(303, "Latecomers", "latecomer", "Latecomer One")
local former, winner = formers.noble, winners.noble
local rival, latecomer = rivals.noble, latecomers.noble

-- the noble the former's form makes
local hireling = formers.unformed[1]
assert(hireling, "the formers need an unformed noble")

for _, who in ipairs{ winner, rival, latecomer } do
	oly.know(who, BRIBE_NOBLE)
end
oly.additem(winner, GOLD, 500)
oly.additem(rival, GOLD, 500)

oly.order(former, "form " .. hireling .. " Hireling")
oly.order(winner, "wait day 9")
oly.order(winner, "bribe " .. hireling .. " 500")
oly.order(rival, "wait day 9")
oly.order(rival, "bribe " .. hireling .. " 500")
oly.order(latecomer, "wait day 17")
oly.order(latecomer, "bribe " .. hireling .. " 100")

oly.save("./lib")

print(string.format("built social-switched: former=%d hireling=%d winner=%d "
	.. "rival=%d latecomer=%d", former, hireling, winner, rival, latecomer))
