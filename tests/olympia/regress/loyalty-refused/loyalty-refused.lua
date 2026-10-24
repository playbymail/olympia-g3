-- loyalty-refused.lua -- build the loyalty-refused scenario (issue #143).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Two factions start in Greyfell (start city 0):
--
--   sworn      a starting noble, so already oath-2: honor fails with no
--              amount and then (as does honour) as oath-bound, oath fails at the maximum,
--              pledge fails to itself, a location, an NPC (Catchclaw's
--              garrison) and, after a wait, the liege pledged to it; swear
--              has been removed and always fails; then forms a hireling
--   hireling   contract-500 once formed, but carries no gold: honor fails
--   liege      pledges to the sworn noble on day 1 (ok), so the sworn
--              noble's later pledge back would be circular
--
-- Rejected: every loyalty verb is for nobles (c), so the player entity's
-- orders for all four (and honour) are refused. oath's 0-NP failure is not reached: a
-- new faction has 18 NP and no binding sets it.

local oly = require "oly"

local GREYFELL = 57081			-- start city 0
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

local sworns = faction(300, "Oathbound", "sworn", "Sworn One")
local lieges = faction(301, "Lieges", "liege", "Liege One")
local sworn, liege = sworns.noble, lieges.noble

local garrison = oly.garrison(CATCHCLAW)
assert(garrison, "Catchclaw must have a garrison")

local hireling = sworns.unformed[1]
assert(hireling, "the oathbound need an unformed noble")

for _, o in ipairs{
		"honor", "honor 10", "honour 10", "oath 1",
		"pledge " .. sworn, "pledge " .. GREYFELL, "pledge " .. garrison,
		"swear " .. liege,
		"wait day 2", "pledge " .. liege,
		"form " .. hireling .. " Hireling" } do
	oly.order(sworn, o)
end
oly.order(hireling, "honor 50")
oly.order(liege, "pledge " .. sworn)
for _, o in ipairs{
		"honor 10", "honour 10", "oath 1", "pledge " .. sworn,
		"swear " .. sworn } do
	oly.order(sworns.player, o)
end

oly.save("./lib")

print(string.format("built loyalty-refused: player=%d sworn=%d hireling=%d "
	.. "liege=%d garrison=%d", sworns.player, sworn, hireling, liege,
	garrison))
