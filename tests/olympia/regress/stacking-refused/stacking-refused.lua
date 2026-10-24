-- stacking-refused.lua -- build the stacking-refused scenario (issue #141).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Two factions start in Greyfell (start city 0).
-- The loner orders each stacking verb so that it fails:
--
--   stack      fail: can't stack beneath oneself; the stranger, who has not
--              admitted the loner, refuses
--   unstack    fail: not stacked under anyone; the stranger is not stacked
--              beneath the loner
--   promote    fail: no argument; can't promote oneself
--
-- Rejected: all three verbs are for nobles (cr), so the player entity's
-- stack, unstack and promote are refused.

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

local loners = faction(300, "Loners", "loner", "Loner One")
local strangers = faction(301, "Strangers", "stranger", "Stranger One")
local loner, stranger = loners.noble, strangers.noble

for _, o in ipairs{
		"stack " .. loner, "stack " .. stranger,
		"unstack", "unstack " .. stranger,
		"promote", "promote " .. loner } do
	oly.order(loner, o)
end
for _, o in ipairs{
		"stack " .. loner, "unstack", "promote " .. loner } do
	oly.order(loners.player, o)
end

oly.save("./lib")

print(string.format("built stacking-refused: player=%d loner=%d "
	.. "stranger=%d", loners.player, loner, stranger))
