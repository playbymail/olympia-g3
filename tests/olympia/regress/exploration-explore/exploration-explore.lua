-- exploration-explore.lua -- build the exploration-explore scenario (issue #148).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Four factions start in Greyfell (start city 0):
--
--   explorer   poofed to Plain [13450], which hides a cave and a ruins:
--              explores it (the find is a draw on the explore stream, keyed
--              on explorer and province)
--   seeker     stays in Greyfell: plugh and xyzzy (developer no-ops), then
--              seeks the idler (here: contact at once), the explorer (not
--              here: a 7-day search with no draw), and anyone (a scan)
--   idler      stays in Greyfell with no orders; the seeker's first target
--   quester    poofed into the hidden ruins [74516] in Plain, which is not a
--              safe haven: quests there (a draw on the quest stream, keyed on
--              the ruins, may raise a monster to fight)
--
-- Every start returns TRUE (ok).

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

local explorers = faction(300, "Explorers", "explorer", "Explorer One")
local seekers = faction(301, "Seekers", "seeker", "Seeker One")
local idlers = faction(302, "Idlers", "idler", "Idler One")
local questers = faction(303, "Questers", "quester", "Quester One")
local explorer, seeker = explorers.noble, seekers.noble
local idler, quester = idlers.noble, questers.noble

oly.poof(explorer, PLAIN)
assert(oly.loc(explorer) == PLAIN, "the explorer must be in Plain")
oly.poof(quester, RUINS)
assert(oly.loc(quester) == RUINS, "the quester must be in the ruins")
assert(oly.loc(RUINS) == PLAIN, "the ruins must be in Plain")

oly.order(explorer, "explore")
oly.order(seeker, "plugh")
oly.order(seeker, "xyzzy")
oly.order(seeker, "seek " .. idler)
oly.order(seeker, "seek " .. explorer)
oly.order(seeker, "seek")
oly.order(quester, "quest")

oly.save("./lib")

print(string.format("built exploration-explore: explorer=%d seeker=%d "
	.. "idler=%d quester=%d", explorer, seeker, idler, quester))
