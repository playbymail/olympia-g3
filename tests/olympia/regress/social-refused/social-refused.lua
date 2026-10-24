-- social-refused.lua -- build the social-refused scenario (issue #146).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Three factions start in Greyfell (start city 0);
-- two are poofed to Catchclaw [58706], which has a seeded garrison:
--
--   bungler     knows no social skill: bribe and incite fail (no skill),
--               and terrorize of the schemer fails (not our faction)
--   schemer     knows Bribe noble and Incite mob: bribe fails against the
--               garrison (an NPC), with no amount and with more gold than
--               it has; incite fails with a noble for the mob (not a
--               peasant mob) and with a target elsewhere
--   terrorizer  in Greyfell, forms a hireling and terrorizes it (ok, fear
--               loyalty from day 14); the hireling's terrorize of the
--               terrorizer fails on day 8 (not stacked beneath it) and
--               again on day 15 (fear-loyal units may not terrorize)
--
-- Rejected: all three verbs are for nobles (c, and cr for terrorize), so
-- the player entity's orders for all three are refused.
--
-- Not reached: bribing a noble that switched lords this month (only a
-- desertion -- a won bribe, persuade or prisoner terror -- sets new_lord).

local oly = require "oly"

local GREYFELL = 57081			-- start city 0
local CATCHCLAW = 58706			-- a city with a seeded garrison

local BRIBE_NOBLE, INCITE_MOB = 671, 675	-- skills

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

local bunglers = faction(300, "Bunglers", "bungler", "Bungler One")
local schemers = faction(301, "Schemers", "schemer", "Schemer One")
local terrorizers = faction(302, "Terrorizers", "terrorizer", "Terrorizer One")
local bungler, schemer = bunglers.noble, schemers.noble
local terrorizer = terrorizers.noble

local garrison = oly.garrison(CATCHCLAW)
assert(garrison, "Catchclaw must have a garrison")

-- the noble the terrorizer's form makes
local hireling = terrorizers.unformed[1]
assert(hireling, "the terrorizers need an unformed noble")

oly.know(schemer, BRIBE_NOBLE)
oly.know(schemer, INCITE_MOB)

for _, who in ipairs{ bungler, schemer } do
	oly.poof(who, CATCHCLAW)
	assert(oly.loc(who) == CATCHCLAW, "bungler and schemer must be in Catchclaw")
end

for _, o in ipairs{
		"bribe " .. schemer .. " 100", "incite " .. schemer .. " " .. schemer,
		"terrorize " .. schemer .. " 3" } do
	oly.order(bungler, o)
end
for _, o in ipairs{
		"bribe " .. garrison .. " 100", "bribe " .. bungler .. " 0",
		"bribe " .. bungler .. " 500",
		"incite " .. bungler .. " " .. bungler,
		"incite " .. bungler .. " " .. GREYFELL } do
	oly.order(schemer, o)
end
oly.order(terrorizer, "form " .. hireling .. " Hireling")
oly.order(terrorizer, "terrorize " .. hireling .. " 3")
oly.order(hireling, "terrorize " .. terrorizer .. " 3")
oly.order(hireling, "wait day 15")
oly.order(hireling, "terrorize " .. terrorizer .. " 3")
for _, o in ipairs{
		"bribe " .. bungler .. " 100", "incite " .. bungler .. " " .. bungler,
		"terrorize " .. bungler .. " 3" } do
	oly.order(bunglers.player, o)
end

oly.save("./lib")

print(string.format("built social-refused: player=%d bungler=%d schemer=%d "
	.. "terrorizer=%d hireling=%d garrison=%d", bunglers.player, bungler,
	schemer, terrorizer, hireling, garrison))
