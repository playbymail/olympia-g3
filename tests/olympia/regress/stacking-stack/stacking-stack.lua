-- stacking-stack.lua -- build the stacking-stack scenario (issue #141).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Three factions start in Greyfell (start city 0):
--
--   leader    admits both others to its stack, then (after waits) promotes
--             the joiner, which is stacked right beneath it, so the joiner
--             moves out ahead of the leader; then drops the visitor from
--             its stack with unstack <id>
--   visitor   stacks under the leader, leaves with a bare unstack, and
--             stacks again before the leader drops it
--   joiner    stacks under the leader, and again after the promote took it
--             out of the stack
--
-- The wait days put the orders in that sequence; the reports show it.
-- Every start returns TRUE (ok). The turn ends with the joiner stacked
-- under the leader and the visitor on its own.

local oly = require "oly"

local GREYFELL = 57081			-- start city 0

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

local leaders = faction(300, "Leaders", "leader", "Leader One")
local visitors = faction(301, "Visitors", "visitor", "Visitor One")
local joiners = faction(302, "Joiners", "joiner", "Joiner One")
local leader, visitor, joiner = leaders.noble, visitors.noble, joiners.noble

for _, o in ipairs{
		"admit " .. leader .. " " .. visitor .. " " .. joiner,
		"wait day 3",
		"promote " .. joiner,
		"wait day 5",
		"unstack " .. visitor } do
	oly.order(leader, o)
end
for _, o in ipairs{
		"wait day 1", "stack " .. leader,
		"wait day 2", "unstack",
		"wait day 4", "stack " .. leader } do
	oly.order(visitor, o)
end
for _, o in ipairs{
		"wait day 1", "stack " .. leader,
		"wait day 4", "stack " .. leader } do
	oly.order(joiner, o)
end

oly.save("./lib")

print(string.format("built stacking-stack: player=%d leader=%d visitor=%d "
	.. "joiner=%d", leaders.player, leader, visitor, joiner))
