-- governance-refused.lua -- build the governance-refused scenario (issue #150).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Five factions start in Greyfell (start city 0):
--
--   lord       stands in a castle made by oly.makeloc in the city: its
--              garrison fails below province level, and it rules no
--              garrison, so every decree fails
--   squire     stands in the forest province around the city with five
--              soldiers: each garrison and ungarrison fails a different check
--   pretender  stands in the plain west of the forest with ten soldiers: the
--              lord's castle is not in this province, and no garrison bound
--              to it adjoins
--   outlander  stands in a plain of Idar with ten soldiers: the lord's
--              castle is in Provinia, another region
--   usurper    stands in Catchclaw, whose seeded garrison is bound to no
--              castle, so nobody rules it
--
-- Catchclaw's garrison orders all three verbs, which are for nobles (c), so
-- each is rejected. The castle, the unfinished castle and the tower are
-- minted here, before the turn.

local oly = require "oly"

local SOLDIER = 12			-- item

local GREYFELL = 57081			-- start city 0
local FOREST = 13451			-- Greyfell's province
local PLAIN = 13450			-- west of the forest
local CATCHCLAW = 58706			-- a city with a seeded garrison
local IDAR_PLAIN = 10113		-- a province of Idar, not Provinia

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

local lords = faction(300, "Lords", "lord", "Lord One")
local squires = faction(301, "Squires", "squire", "Squire One")
local pretenders = faction(302, "Pretenders", "pretender", "Pretender One")
local usurpers = faction(303, "Usurpers", "usurper", "Usurper One")
local outlanders = faction(304, "Outlanders", "outlander", "Outlander One")
local lord, squire = lords.noble, squires.noble
local pretender, usurper = pretenders.noble, usurpers.noble
local outlander = outlanders.noble

local garrison = oly.garrison(CATCHCLAW)
assert(garrison, "Catchclaw must have a garrison")

local castle = oly.makeloc(lord, "castle", "castle")
local unfinished = oly.makeloc(lord, "castle-in-progress", "unfinished")
local tower = oly.makeloc(lord, "tower", "tower")
oly.poof(lord, castle)
assert(oly.loc(lord) == castle, "the lord must be in the castle")

oly.poof(squire, FOREST)
assert(oly.loc(squire) == FOREST, "the squire must be in the forest")
assert(not oly.garrison(FOREST), "the forest must have no garrison")
oly.additem(squire, SOLDIER, 5)

oly.poof(pretender, PLAIN)
assert(oly.loc(pretender) == PLAIN, "the pretender must be in the plain")
assert(not oly.garrison(PLAIN), "the plain must have no garrison")
oly.additem(pretender, SOLDIER, 10)

oly.poof(outlander, IDAR_PLAIN)
assert(oly.loc(outlander) == IDAR_PLAIN, "the outlander must be in Idar")
assert(not oly.garrison(IDAR_PLAIN), "the Idar plain must have no garrison")
oly.additem(outlander, SOLDIER, 10)

oly.poof(usurper, CATCHCLAW)
assert(oly.loc(usurper) == CATCHCLAW, "the usurper must be in Catchclaw")

for _, o in ipairs{
		"garrison " .. castle,
		"decree",
		"decree tax",
		"decree watch " .. GREYFELL,
		"decree watch " .. squire,
		"decree hostile " .. squire } do
	oly.order(lord, o)
end
for _, o in ipairs{
		"garrison",
		"garrison " .. unfinished,
		"garrison " .. tower,
		"garrison " .. castle,
		"ungarrison",
		"ungarrison " .. garrison } do
	oly.order(squire, o)
end
oly.order(pretender, "garrison " .. castle)
oly.order(outlander, "garrison " .. castle)
oly.order(usurper, "ungarrison")
for _, o in ipairs{
		"garrison " .. castle,
		"ungarrison",
		"decree watch " .. lord } do
	oly.order(garrison, o)
end

oly.save("./lib")

print(string.format("built governance-refused: lord=%d squire=%d "
	.. "pretender=%d outlander=%d usurper=%d garrison=%d castle=%d "
	.. "unfinished=%d tower=%d", lord, squire, pretender, outlander,
	usurper, garrison, castle, unfinished, tower))
